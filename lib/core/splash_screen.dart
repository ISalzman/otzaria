import 'package:flutter/material.dart';

/// מסך פתיחה מוצג בזמן האתחול לפני שה-App נטען
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: Image(
            image: AssetImage('assets/icon/iconnew.png'),
            width: 128,
            height: 128,
          ),
        ),
      ),
    );
  }
}
