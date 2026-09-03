#!/bin/bash
# המקבילה של download_bundled_plugins.ps1 לבניות לינוקס ומק (בקונטיינר של
# לינוקס אין pwsh): מוריד את התוספים שברשימת ההיתר אל installer/bundled_plugins,
# כדי שה-workflow יארוז אותם ליד ה-executable ואוצריא תרשום אותם בעלייה
# הראשונה (docs/bundled_plugins.md). דורש curl, unzip ו-jq.
#
# רשימת ההיתר היא lib/plugins/services/bundled_plugin_ids.dart — אותו קובץ
# שנקמפל אל תוך האפליקציה, כדי שלא תיווצר רשימה שנייה שיוצאת מסינכרון.
# כל רשומה היא זוג 'מזהה-חנות': 'מזהה-מניפסט[@פלטפורמות]' — ההורדה לפי מזהה
# החנות, והקובץ נשמר בשם מזהה המניפסט, שמולו האפליקציה מאמתת את הארכיון.
# רשימה ריקה = לא נוצרת תיקייה, וההעתקה ליד ה-executable מדולגת.
#
# ארגומנט אופציונלי: שם הפלטפורמה הנבנית (linux/macos/android/...) — רשומה
# עם סיומת @פלטפורמות שאינה כוללת אותו מדולגת. בלי ארגומנט אין סינון.

set -euo pipefail

platform="${1:-}"
script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(dirname "$script_dir")"
allowlist_file="$repo_root/lib/plugins/services/bundled_plugin_ids.dart"
output_dir="$script_dir/bundled_plugins"
store_base_url='https://otzaria.org'

[ -f "$allowlist_file" ] || { echo "Bundled plugin allowlist not found: $allowlist_file" >&2; exit 1; }

# זוג יחיד במרכאות בשורה שאינה הערה — הפורמט שהקובץ מתחייב לו.
pair_re="^'([^']+)': *'([^']+)',?$"
store_ids=()
manifest_ids=()
while IFS= read -r line; do
  trimmed="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  case "$trimmed" in //*) continue ;; esac
  if [[ "$trimmed" =~ $pair_re ]]; then
    value="${BASH_REMATCH[2]}"
    manifest_id="${value%%@*}"
    if [ "$value" != "$manifest_id" ] && [ -n "$platform" ]; then
      platforms="${value#*@}"
      case ",$platforms," in
        *",$platform,"*) ;;
        *) echo "Skipping $manifest_id - not for $platform ($platforms)"; continue ;;
      esac
    fi
    store_ids+=("${BASH_REMATCH[1]}")
    manifest_ids+=("$manifest_id")
  fi
done < "$allowlist_file"

if [ "${#store_ids[@]}" -eq 0 ]; then
  echo 'No bundled plugins configured - skipping.'
  rm -rf "$output_dir"
  exit 0
fi

# גרסת האוצריא נשלחת לחנות כדי לקבל את גרסת התוסף התואמת ולא את האחרונה.
app_version="$(sed -n 's/^version:[[:space:]]*//p' "$repo_root/pubspec.yaml" | head -n 1 | tr -d '[:space:]')"
app_version="${app_version%%+*}"
[ -n "$app_version" ] || { echo 'Could not read version from pubspec.yaml' >&2; exit 1; }
echo "Downloading ${#store_ids[@]} bundled plugin(s) for Otzaria $app_version"

rm -rf "$output_dir"
mkdir -p "$output_dir"

id_re='^[A-Za-z0-9._-]+$'
for i in "${!store_ids[@]}"; do
  store_id="${store_ids[$i]}"
  manifest_id="${manifest_ids[$i]}"
  [[ "$store_id" =~ $id_re ]] || { echo "Invalid store id in allowlist: '$store_id'" >&2; exit 1; }
  [[ "$manifest_id" =~ $id_re ]] || { echo "Invalid manifest id in allowlist: '$manifest_id'" >&2; exit 1; }

  target="$output_dir/$manifest_id.otzplugin"
  url="$store_base_url/api/plugins/$store_id/download?appVersion=$app_version"
  echo "  $manifest_id <- $url"
  curl -L --fail --silent --show-error "$url" -o "$target"

  # תשובת שגיאה שהוגשה כ-200 (דף HTML) נשמרת כארכיון תקין למראה ונכשלת רק
  # אצל המשתמש — בודקים את חתימת ה-ZIP כאן.
  [ "$(head -c 2 "$target")" = 'PK' ] || { echo "Downloaded file for '$manifest_id' is not a zip archive" >&2; exit 1; }

  # אימות מוקדם של החוזה מול האפליקציה: מזהה המניפסט שבארכיון חייב להתאים
  # לרשומה — אחרת ה-seeder ידחה את הארכיון בשקט אצל המשתמש.
  manifest_json="$(unzip -p "$target" manifest.json)" \
    || { echo "No manifest.json in archive for '$manifest_id'" >&2; exit 1; }
  declared_id="$(printf '%s' "$manifest_json" | jq -r '.id')"
  if [ "$declared_id" != "$manifest_id" ]; then
    echo "Manifest id mismatch for store id '$store_id': allowlist says '$manifest_id' but archive declares '$declared_id'" >&2
    exit 1
  fi

  size_kb=$(( ($(wc -c < "$target") + 512) / 1024 ))
  echo "    ok ($size_kb KB, v$(printf '%s' "$manifest_json" | jq -r '.version'))"
done
