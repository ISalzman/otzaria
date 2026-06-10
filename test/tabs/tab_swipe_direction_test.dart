import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/tabs/utils/tab_swipe_direction.dart';

void main() {
  group('tabSwipeDirection', () {
    test('RTL: גרירה ימינה (dx חיובי) עוברת לטאב הבא', () {
      expect(
        tabSwipeDirection(
          accumulatedDx: 120,
          textDirection: TextDirection.rtl,
        ),
        1,
      );
    });

    test('RTL: גרירה שמאלה (dx שלילי) עוברת לטאב הקודם', () {
      expect(
        tabSwipeDirection(
          accumulatedDx: -120,
          textDirection: TextDirection.rtl,
        ),
        -1,
      );
    });

    test('LTR: גרירה ימינה (dx חיובי) עוברת לטאב הקודם', () {
      expect(
        tabSwipeDirection(
          accumulatedDx: 120,
          textDirection: TextDirection.ltr,
        ),
        -1,
      );
    });

    test('LTR: גרירה שמאלה (dx שלילי) עוברת לטאב הבא', () {
      expect(
        tabSwipeDirection(
          accumulatedDx: -120,
          textDirection: TextDirection.ltr,
        ),
        1,
      );
    });
  });
}
