import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:otzaria/core/ui_snack.dart';
import 'package:otzaria/plugins/services/webview2_compat_check.dart';

/// קישור רשמי של Microsoft להורדת WebView2 Evergreen Bootstrapper.
const String _webView2DownloadUrl =
    'https://developer.microsoft.com/en-us/microsoft-edge/webview2/';

/// תצוגה שמופיעה במקום WebView כשגרסת WebView2 המותקנת במכשיר
/// אינה תומכת בתוספים (לדוגמה v143 שגורם לקריסת התוכנה).
class WebView2UnsupportedView extends StatelessWidget {
  final WebView2CompatResult result;
  final String? pluginName;

  const WebView2UnsupportedView({
    super.key,
    required this.result,
    this.pluginName,
  });

  Future<void> _openDownloadPage() async {
    final uri = Uri.parse(_webView2DownloadUrl);
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        UiSnack.showError('לא ניתן לפתוח את דף ההורדה');
      }
    } catch (_) {
      UiSnack.showError('לא ניתן לפתוח את דף ההורדה');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                FluentIcons.warning_24_regular,
                size: 56,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                pluginName != null
                    ? 'לא ניתן לטעון את התוסף "$pluginName"'
                    : 'לא ניתן לטעון את התוסף',
                style: tt.titleLarge,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text(
                result.reasonForUser,
                style: tt.bodyMedium,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'כיצד לפתור:',
                      style: tt.titleSmall,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. ניתן להתקין את הגרסה החדשה של WebView2 Runtime '
                      'מהאתר הרשמי של Microsoft.\n'
                      '2. אם יש מגבלות אדמין במכשיר — פנה למנהל המערכת '
                      'ובקש לעדכן את Microsoft Edge WebView2 Runtime.\n'
                      '3. שאר תכונות אוצריא ימשיכו לעבוד כרגיל גם בלי תוספים.',
                      style: tt.bodySmall,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: _openDownloadPage,
                        icon: const Icon(FluentIcons.open_24_regular, size: 18),
                        label: const Text(
                          'פתח את דף ההורדה הרשמי',
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (result.version != null) ...[
                const SizedBox(height: 12),
                Text(
                  'גרסה מותקנת: ${result.version}',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
