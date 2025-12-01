import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:otzaria/core/scaffold_messenger.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:otzaria/settings/settings_bloc.dart';
import 'package:otzaria/settings/settings_state.dart';
import 'package:otzaria/navigation/main_window_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final state = settingsState;
        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: const [
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale("he", "IL"),
          ],
          locale: const Locale("he", "IL"),
          title: 'אוצריא',
          theme: state.isDarkMode
              ? ThemeData.dark(useMaterial3: true).copyWith(
                  scaffoldBackgroundColor: const Color(0xFF242424),
                  canvasColor: const Color(0xFF242424),
                  cardColor: const Color(0xFF333333),
                  colorScheme: ColorScheme.dark(
                    surface: const Color(0xFF242424),
                    surfaceContainer: const Color(0xFF333333),
                    onSurface: const Color(0xFFE0E0E0),
                    primary: state.darkSeedColor,
                    onPrimary: Colors.white,
                    secondary: state.darkSeedColor.withValues(alpha: 0.7),
                    onSecondary: Colors.white,
                    outline: const Color(0xFF4A4A4A),
                  ),
                  textTheme: ThemeData.dark().textTheme.apply(
                        fontFamily: 'Roboto',
                        bodyColor: const Color(0xFFE0E0E0),
                        displayColor: const Color(0xFFE0E0E0),
                      ).copyWith(
                        bodyMedium: const TextStyle(
                          fontSize: 18.0,
                          fontFamily: 'candara',
                          color: Color(0xFFE0E0E0),
                        ),
                      ),
                  cardTheme: CardThemeData(
                    color: const Color(0xFF333333),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: Color(0xFF4A4A4A),
                        width: 1,
                      ),
                    ),
                  ),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF2A2A2A),
                    foregroundColor: Color(0xFFE0E0E0),
                  ),
                  dialogTheme: const DialogThemeData(
                    barrierColor: Color(0x22000000),
                    backgroundColor: Color(0xFF2A2A2A),
                  ),
                )
              : ThemeData(
                  visualDensity: VisualDensity.adaptivePlatformDensity,
                  fontFamily: 'Roboto',
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: state.seedColor,
                  ),
                  textTheme: const TextTheme(
                    bodyMedium:
                        TextStyle(fontSize: 18.0, fontFamily: 'candara'),
                  ),
                ).copyWith(
                  dialogTheme: DialogThemeData(
                    barrierColor: const Color(0x22000000),
                    backgroundColor: ThemeData(
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: state.seedColor,
                      ),
                    ).scaffoldBackgroundColor,
                  ),
                ),
          home: const MainWindowScreen(),
        );
      },
    );
  }
}
