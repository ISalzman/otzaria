import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/settings/tabs/text_settings_tab.dart';
import 'package:otzaria/tabs/bloc/tabs_bloc.dart';
import 'package:otzaria/tabs/bloc/tabs_state.dart';
import 'package:otzaria/tabs/models/text_tab.dart';
import 'package:otzaria/text_book/bloc/text_book_bloc.dart';
import 'package:otzaria/text_book/bloc/text_book_state.dart';

/// פאנל הגדרות תצוגת הספרים (לשימוש כ-overlay צף)
class ReadingSettingsPanel extends StatelessWidget {
  const ReadingSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: ReadingSettingsBody(),
    );
  }
}

/// גוף הגדרות תצוגת הספרים, משותף לפאנל הצף ולדיאלוג.
///
/// מזהה אם הטאב הפעיל מוצג במצב "צורת הדף" — ובמקרה זה מסתיר את סליידר
/// "גודל גופן מפרשים", שכן בצורת הדף גודל גופן המפרשים נשלט בהגדרה ייעודית
/// נפרדת (בדיאלוג צורת הדף) ולא בהגדרה הכללית.
class ReadingSettingsBody extends StatelessWidget {
  const ReadingSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TabsBloc, TabsState>(
      builder: (context, tabsState) {
        final currentTab = tabsState.currentTab;
        if (currentTab is TextBookTab) {
          return BlocBuilder<TextBookBloc, TextBookState>(
            bloc: currentTab.bloc,
            builder: (context, textState) {
              final isPageShape =
                  textState is TextBookLoaded && textState.showPageShapeView;
              return TextSettingsTab(
                isDialog: true,
                hideCommentaryFontSize: isPageShape,
              );
            },
          );
        }
        return const TextSettingsTab(isDialog: true);
      },
    );
  }
}
