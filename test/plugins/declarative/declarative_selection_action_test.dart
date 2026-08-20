import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_selection_action.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';

void main() {
  group('validateTemplate', () {
    test('תבנית storage.set עם הפניות סימון תקינה עוברת', () {
      DeclarativeSelectionAction.validateTemplate(
        _storageTemplate(),
        declaredPermissions: {'plugin.storage.write'},
      );
    });

    test('פקודת חישוב נדחית — רק פעולות מותרות', () {
      expect(
        () => DeclarativeSelectionAction.validateTemplate({
          'type': 'storage.get',
          'args': {'key': 'k'},
        }),
        _throwsProgramError('declarative.invalid_phase'),
      );
    });

    test('הרשאה שלא הוצהרה נדחית כשההרשאות מסופקות', () {
      expect(
        () => DeclarativeSelectionAction.validateTemplate(
          _storageTemplate(),
          declaredPermissions: {'reader.open'},
        ),
        _throwsProgramError('declarative.permission_not_declared'),
      );
    });

    test('בלי הרשאות (רישום בגשר) הבדיקה המבנית עדיין רצה', () {
      DeclarativeSelectionAction.validateTemplate(_storageTemplate());
      expect(
        () => DeclarativeSelectionAction.validateTemplate({
          'type': 'storage.set',
          'args': {'key': 'k', 'value': 1, 'extra': true},
        }),
        _throwsProgramError('declarative.unknown_field'),
      );
    });

    test('נתיב סימון שאינו ברשימה המותרת נדחה', () {
      expect(
        () => DeclarativeSelectionAction.validateTemplate({
          'type': 'storage.set',
          'args': {
            'key': 'k',
            'value': {r'$selection': 'selection'},
          },
        }),
        _throwsProgramError('declarative.invalid_reference'),
      );
    });

    test(r'הפניות $output ו-$result אינן זמינות בתפריט הקשר', () {
      for (final ref in const [r'$output', r'$result', r'$context', r'$row']) {
        expect(
          () => DeclarativeSelectionAction.validateTemplate({
            'type': 'storage.set',
            'args': {
              'key': 'k',
              'value': {ref: 'anything'},
            },
          }),
          _throwsProgramError('declarative.invalid_reference'),
        );
      }
    });

    test('תבנית עמוקה או גדולה מדי נדחית', () {
      Object deep = 1;
      for (var i = 0; i < 12; i++) {
        deep = {'nested': deep};
      }
      expect(
        () => DeclarativeSelectionAction.validateTemplate({
          'type': 'storage.set',
          'args': {'key': 'k', 'value': deep},
        }),
        _throwsProgramError('declarative.value_too_large'),
      );
    });
  });

  group('resolve', () {
    test('מציב ערכי סימון, ליטרלים ו-concat', () {
      final resolved = DeclarativeSelectionAction.resolve(_storageTemplate(), {
        'id': 42,
        'currentBook': 'ברכות',
        'currentIndex': 7,
      });

      expect(resolved['type'], 'storage.set');
      expect(resolved['args'], {
        'key': 'savedBooks',
        'value': {
          'id': 42,
          'title': 'ברכות',
          'label': 'ברכות (7)',
          'pinned': true,
        },
      });
    });

    test('נתיב שחסר ב-payload נפתר ל-null', () {
      final resolved = DeclarativeSelectionAction.resolve(
        {
          'type': 'storage.set',
          'args': {
            'key': 'k',
            'value': {r'$selection': 'currentRef'},
          },
        },
        const {'currentBook': 'ברכות'},
      );

      expect((resolved['args'] as Map)['value'], isNull);
    });
  });
}

Map<String, dynamic> _storageTemplate() => {
  'type': 'storage.set',
  'args': {
    'key': 'savedBooks',
    'value': {
      'id': {r'$selection': 'id'},
      'title': {r'$selection': 'currentBook'},
      'label': {
        r'$concat': [
          {r'$selection': 'currentBook'},
          ' (',
          {r'$selection': 'currentIndex'},
          ')',
        ],
      },
      'pinned': {r'$literal': true},
    },
  },
};

Matcher _throwsProgramError(String code) => throwsA(
  isA<DeclarativeProgramException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
