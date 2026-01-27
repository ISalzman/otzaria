import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/navigation/about_screen.dart';
import 'package:otzaria/widgets/ad_popup_dialog.dart';

class AboutDialogWidget extends StatelessWidget {
  const AboutDialogWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'אודות התוכנה',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'מידע על התוכנה',
                        icon: const Icon(FluentIcons.info_24_regular),
                        onPressed: () =>
                            openLocalHtmlFile(context, 'index.html'),
                      ),
                      IconButton(
                        tooltip: 'אוצריא מתגייסת לעזרת לומדי התורה',
                        icon: const Icon(FluentIcons.shield_task_24_filled),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => const AdPopupDialog(
                              title: 'אוצריא מתגייסת לעזרת לומדי התורה',
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.dismiss_24_regular),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Expanded(child: AboutScreen()),
            ],
          ),
        ),
      ),
    );
  }
}
