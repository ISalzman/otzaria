import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/models/links.dart';
import 'package:otzaria/text_book/view/selection/selection_sync_controller.dart';

void main() {
  group('SelectionSyncController', () {
    test('מעביר בעלות בחירה לאזור האחרון שהופעל', () {
      final controller = SelectionSyncController();
      final firstOwner = Object();
      final secondOwner = Object();
      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      controller.activate(firstOwner);

      expect(controller.activeOwner, same(firstOwner));
      expect(notifications, 1);

      controller.activate(secondOwner);

      expect(controller.activeOwner, same(secondOwner));
      expect(notifications, 2);
    });

    test('לא שולח notify נוסף כשאותו אזור מופעל שוב', () {
      final controller = SelectionSyncController();
      final owner = Object();
      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      controller.activate(owner);
      controller.activate(owner);

      expect(controller.activeOwner, same(owner));
      expect(notifications, 1);
    });

    test('שומר את הטקסט והקישור של הבחירה הפעילה', () {
      final controller = SelectionSyncController();
      final owner = Object();
      final link = Link(
        heRef: 'בראשית א א',
        index1: 1,
        path2: 'רש"י.txt',
        index2: 1,
        connectionType: 'COMMENTARY',
      );

      controller.activate(
        owner,
        selectionText: 'טקסט מפרש נבחר',
        selectionLink: link,
      );

      expect(controller.activeOwner, same(owner));
      expect(controller.activeSelectionText, 'טקסט מפרש נבחר');
      expect(controller.activeSelectionLink, same(link));
    });

    test('מעדכן את הטקסט של אותו בעלים בלי notify נוסף', () {
      final controller = SelectionSyncController();
      final owner = Object();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.activate(owner, selectionText: 'בחירה ראשונה');
      controller.activate(owner, selectionText: 'בחירה מעודכנת');

      expect(controller.activeSelectionText, 'בחירה מעודכנת');
      expect(notifications, 1);
    });

    test('מעבר לבעלים ללא טקסט אינו משאיר בחירה ישנה', () {
      final controller = SelectionSyncController();
      final commentaryOwner = Object();
      final mainTextOwner = Object();

      controller.activate(
        commentaryOwner,
        selectionText: 'בחירת מפרש ישנה',
      );
      controller.activate(mainTextOwner);

      expect(controller.activeOwner, same(mainTextOwner));
      expect(controller.activeSelectionText, isNull);
      expect(controller.activeSelectionLink, isNull);
    });

    test('מתעלם מניקוי של אזור שכבר איבד בעלות', () {
      final controller = SelectionSyncController();
      final firstOwner = Object();
      final secondOwner = Object();
      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      controller.activate(firstOwner);
      controller.activate(secondOwner);
      controller.clear(firstOwner);

      expect(controller.activeOwner, same(secondOwner));
      expect(notifications, 2);
    });

    test('מאפשר רק לאזור הפעיל לנקות את הבחירה', () {
      final controller = SelectionSyncController();
      final owner = Object();
      var notifications = 0;

      controller.addListener(() {
        notifications++;
      });

      controller.activate(owner);
      controller.clear(owner);

      expect(controller.activeOwner, isNull);
      expect(notifications, 2);
    });

    test('ניקוי הבעלים הפעיל מנקה גם את נתוני הבחירה', () {
      final controller = SelectionSyncController();
      final owner = Object();

      controller.activate(owner, selectionText: 'טקסט שנבחר');
      controller.clear(owner);

      expect(controller.activeOwner, isNull);
      expect(controller.activeSelectionText, isNull);
      expect(controller.activeSelectionLink, isNull);
    });

    test('אחרי ניקוי בעלות, activeOwner הוא null במופע ההודעה', () {
      // ההודעה שמתקבלת אחרי clear מגיעה עם activeOwner=null.
      // צרכנים חייבים להבחין בין "מישהו אחר נעשה פעיל" לבין "אין אף אזור פעיל"
      // — אחרת ניקוי בחירה גורם לבנייה מחדש מיותרת ולקפיצה בגלילה.
      final controller = SelectionSyncController();
      final owner = Object();
      Object? activeOwnerAtNotification;

      controller.addListener(() {
        activeOwnerAtNotification = controller.activeOwner;
      });

      controller.activate(owner);
      expect(activeOwnerAtNotification, same(owner));

      controller.clear(owner);
      expect(
        activeOwnerAtNotification,
        isNull,
        reason: 'אחרי clear, ההודעה חייבת לזרום עם activeOwner=null',
      );
    });
  });
}
