final _disallowed = RegExp(r'[^\p{L}\p{N}\p{M}_\s-]', unicode: true);
final _whitespace = RegExp(r'\s');

/// מזהה עוגן לכותרת לפי האלגוריתם של GitHub (`github-slugger`).
///
/// מקפים עוקבים אינם מאוחדים ומקפים בקצוות אינם נחתכים — בכוונה, כדי
/// שכותרת כמו `## ערכי JSON ← מיפוי` תניב `ערכי-json--מיפוי` בדיוק כמו ב-GitHub.
String headingSlug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(_disallowed, '')
    .replaceAll(_whitespace, '-');
