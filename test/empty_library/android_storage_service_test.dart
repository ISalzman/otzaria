import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/empty_library/services/android_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('listStorageOptions מחזיר ריק בפלטפורמה שאינה Android', () async {
    // הבדיקה רצה על מארח שאינו Android — אין ברירת מיקום ולכן הרשימה ריקה.
    if (Platform.isAndroid) return;
    final options = await AndroidStorageService.listStorageOptions();
    expect(options, isEmpty);
  });
}
