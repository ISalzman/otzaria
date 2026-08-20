import 'dart:convert';

import 'package:otzaria/core/messages/report_messages.dart';

/// מערכת ההפעלה של המחשב המחובר שאליו מיועד סקריפט השליחה האופליין.
enum OfflineSendScriptTarget { windows, unix }

/// תוצר בניית סקריפט השליחה: תוכן הקובץ ושם הקובץ המתאים.
class OfflineSendScript {
  final String content;
  final String fileName;

  const OfflineSendScript({required this.content, required this.fileName});
}

const String _psBodyMarker = 'OTZARIA_REPORTS_PS_BODY';

/// בונה סקריפט שליחה של דיווחים שמורים, מותאם למערכת ההפעלה של המחשב
/// המחובר שבו יופעל. משותף לדיווחי טעויות בספרים ולדיווחי תוספים.
///
/// [payloads] - גופי ה-JSON לשליחה, [ids] - מזהה קריא לכל דיווח (מיושר
/// ל-payloads), [idField] - שם שדה המזהה בתוך ה-payload (להצגה ב-PowerShell).
OfflineSendScript buildOfflineReportScript({
  required OfflineSendScriptTarget target,
  required String endpoint,
  required List<Map<String, dynamic>> payloads,
  required List<String> ids,
  required String idField,
  required String baseFileName,
}) {
  switch (target) {
    case OfflineSendScriptTarget.windows:
      return OfflineSendScript(
        content: _buildWindowsBatchScript(endpoint, payloads, idField),
        fileName: '$baseFileName.bat',
      );
    case OfflineSendScriptTarget.unix:
      return OfflineSendScript(
        content: _buildUnixShellScript(endpoint, payloads, ids),
        fileName: '$baseFileName.sh',
      );
  }
}

/// בונה קובץ .bat קריא: שורת הפעלה קצרה שקוראת את הקובץ עצמו, מחלצת את גוף
/// ה-PowerShell שאחרי הסמן ומריצה אותו. הסמן נבנה ב-PowerShell מ-[char]35
/// כדי שלא יופיע כפי שהוא בשורת הפקודה ויתנגש עם החיפוש.
String _buildWindowsBatchScript(
  String endpoint,
  List<Map<String, dynamic>> payloads,
  String idField,
) {
  final payloadJson = jsonEncode(payloads);
  final powerShellBody = _buildWindowsPowerShellBody(
    endpoint,
    payloadJson,
    idField,
  );
  final script =
      '''@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "\$f=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); \$m=[char]35+'$_psBodyMarker'; iex \$f.Substring(\$f.IndexOf(\$m)+\$m.Length)"
exit /b %ERRORLEVEL%
#$_psBodyMarker
$powerShellBody''';
  // cmd.exe דורש CRLF; מנרמלים קודם ל-LF כדי שמקור CRLF לא ייצור \r\r\n.
  return script.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
}

String _buildWindowsPowerShellBody(
  String endpoint,
  String payloadJson,
  String idField,
) {
  return '''Add-Type -AssemblyName System.Windows.Forms | Out-Null
\$ErrorActionPreference = 'Stop'
\$endpoint = '$endpoint'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

\$payloadsJson = @'
$payloadJson
'@

\$payloads = \$payloadsJson | ConvertFrom-Json
\$sent = 0
\$failed = 0
\$lines = @()
foreach (\$payload in @(\$payloads)) {
  try {
    \$body = \$payload | ConvertTo-Json -Depth 10 -Compress
    \$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(\$body)
    \$response = Invoke-WebRequest -Uri \$endpoint -Method Post -ContentType 'application/json; charset=utf-8' -Body \$bodyBytes -UseBasicParsing
    if (\$response.StatusCode -eq 200) {
      \$sent++
      \$lines += ('נשלח: ' + \$payload.$idField)
    } else {
      \$failed++
      \$lines += ('נכשל: ' + \$payload.$idField + ' (סטטוס ' + \$response.StatusCode + ')')
    }
  } catch {
    \$failed++
    \$lines += ('נכשל: ' + \$payload.$idField + ' (' + \$_.Exception.Message + ')')
  }
}

\$summary = "נשלחו בהצלחה: \$sent`r`nנכשלו: \$failed`r`n`r`n" + (\$lines -join "`r`n")
[System.Windows.Forms.MessageBox]::Show(\$summary, '${ReportMessages.offlineScriptWindowTitle}') | Out-Null''';
}

/// בונה קובץ .sh ל-Linux/macOS: שולח כל דיווח ב-curl ומציג את הסיכום בחלון
/// גרפי (zenity/kdialog/osascript) עם נפילה חזרה לפלט במסוף אם אין כלי גרפי.
String _buildUnixShellScript(
  String endpoint,
  List<Map<String, dynamic>> payloads,
  List<String> ids,
) {
  final buffer = StringBuffer()
    ..writeln('#!/usr/bin/env bash')
    ..writeln("endpoint='$endpoint'")
    ..writeln('sent=0')
    ..writeln('failed=0')
    ..writeln('results=""')
    ..writeln('')
    ..writeln('send_one() {')
    ..writeln('  local body="\$1"')
    ..writeln('  local id="\$2"')
    ..writeln('  local code')
    ..writeln(
      "  code=\$(printf '%s' \"\$body\" | curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json; charset=utf-8' --data-binary @- \"\$endpoint\")",
    )
    ..writeln('  if [ "\$code" = "200" ]; then')
    ..writeln('    sent=\$((sent + 1))')
    ..writeln('    results="\${results}\\nנשלח: \${id}"')
    ..writeln('  else')
    ..writeln('    failed=\$((failed + 1))')
    ..writeln('    results="\${results}\\nנכשל: \${id} (סטטוס \${code})"')
    ..writeln('  fi')
    ..writeln('}')
    ..writeln('');

  for (var index = 0; index < payloads.length; index++) {
    final payloadJson = jsonEncode(payloads[index]);
    final delimiter = 'OTZARIA_PAYLOAD_$index';
    buffer
      ..writeln('send_one "\$(cat <<\'$delimiter\'')
      ..writeln(payloadJson)
      ..writeln(delimiter)
      ..writeln(')" ${_shellSingleQuote(ids[index])}');
  }

  buffer
    ..writeln('')
    ..writeln(
      'summary="נשלחו בהצלחה: \${sent}\\nנכשלו: \${failed}\\n\${results}"',
    )
    ..writeln('tmp="\$(mktemp)"')
    ..writeln("printf '%b\\n' \"\$summary\" > \"\$tmp\"")
    ..writeln('if command -v zenity >/dev/null 2>&1; then')
    ..writeln(
      "  zenity --text-info --filename=\"\$tmp\" --title='${ReportMessages.offlineScriptWindowTitle}'",
    )
    ..writeln('elif command -v kdialog >/dev/null 2>&1; then')
    ..writeln(
      "  kdialog --title '${ReportMessages.offlineScriptWindowTitle}' --textbox \"\$tmp\"",
    )
    ..writeln('elif command -v osascript >/dev/null 2>&1; then')
    ..writeln(
      "  osascript -e \"display dialog (do shell script \\\"cat \\\" & quoted form of \\\"\$tmp\\\") buttons {\\\"סגור\\\"} with title \\\"${ReportMessages.offlineScriptWindowTitle}\\\"\" >/dev/null 2>&1",
    )
    ..writeln('else')
    ..writeln("  cat \"\$tmp\"")
    ..writeln('fi')
    ..writeln('rm -f "\$tmp"');

  return buffer.toString();
}

String _shellSingleQuote(String value) {
  return "'${value.replaceAll("'", r"'\''")}'";
}
