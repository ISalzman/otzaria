import 'package:flutter/material.dart';

/// סמל מסך הפתיחה: ממורכז במרכז המסך, עם אטימות קבועה של 70%. החלון בשלב ה-splash
/// הוא 240x240 ממורכז, כך שמרכזו = מרכז המסך; הסמל יציב וקבוע לכל אורך הטעינה
/// (אין עוד יישור מחושב — ההגדלה לגבולות הסופיים מתבצעת רק בחשיפה, בעוד החלון מוסתר).
class SplashIcon extends StatelessWidget {
  const SplashIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Opacity(
        opacity: 0.70,
        child: Image(
          image: AssetImage('assets/icon/iconnew.png'),
          width: 128,
          height: 128,
        ),
      ),
    );
  }
}

/// מסך פתיחה מוצג בזמן האתחול לפני שה-App נטען
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    // רקע שקוף לחלוטין כדי שחלון ה-splash השקוף יציג רק את הסמל הצף (ללא קופסה).
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Color(0x00000000),
      home: Scaffold(
        backgroundColor: Color(0x00000000),
        body: SplashIcon(),
      ),
    );
  }
}
