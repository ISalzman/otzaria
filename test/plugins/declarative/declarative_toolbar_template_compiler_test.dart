import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/declarative/compiler/declarative_toolbar_template_compiler.dart';
import 'package:otzaria/plugins/declarative/models/declarative_program.dart';

void main() {
  test('מקמפל כפתור ברירת מחדל ותפריט מהדורות בלבד', () {
    final templates = _compiler().compileAll('test.plugin', _templates());

    expect(templates, hasLength(2));
    expect(templates.first.baseItem.type, 'button');
    expect(templates.first.actionTemplate, isNotNull);
    expect(templates.last.baseItem.type, 'menu');
    expect(templates.last.childrenBinding!.maxItems, 10);
  });

  test('פלט שאינו מוכר נדחה בזמן קומפילציה', () {
    final templates = _templates();
    (templates.first['binding'] as Map<String, dynamic>)['visibleOutput'] =
        'missing';

    expect(
      () => _compiler().compileAll('test.plugin', templates),
      _throwsProgramError('declarative.output_not_found'),
    );
  });

  test('פעולת פתיחת ספר דורשת הרשאה מוצהרת', () {
    expect(
      () => DeclarativeToolbarTemplateCompiler(
        declaredPermissions: const {'reader.toolbar'},
        programs: {'book-links': _program()},
      ).compileAll('test.plugin', _templates()),
      _throwsProgramError('declarative.permission_not_declared'),
    );
  });

  test('ילד תפריט אינו יכול לקרוא פלט גלובלי במקום את הפריט שלו', () {
    final templates = _templates();
    final children = templates.last['childrenBinding'] as Map<String, dynamic>;
    final itemTemplate = children['itemTemplate'] as Map<String, dynamic>;
    itemTemplate['title'] = {r'$output': 'defaultEdition.title'};

    expect(
      () => _compiler().compileAll('test.plugin', templates),
      _throwsProgramError('declarative.invalid_reference'),
    );
  });

  test('שדה toolbar דקלרטיבי לא מוכר נדחה', () {
    final templates = _templates();
    templates.first['script'] = 'run()';

    expect(
      () => _compiler().compileAll('test.plugin', templates),
      _throwsProgramError('declarative.unknown_field'),
    );
  });
}

DeclarativeToolbarTemplateCompiler _compiler() =>
    DeclarativeToolbarTemplateCompiler(
      declaredPermissions: const {'reader.toolbar', 'reader.open'},
      programs: {'book-links': _program()},
    );

CompiledDeclarativeProgram _program() => const CompiledDeclarativeProgram(
  id: 'book-links',
  version: 1,
  triggers: ['reader.activeBookChanged'],
  when: null,
  commands: [],
  outputs: {'defaultEdition': null, 'editions': null},
  requiredPermissions: {},
);

List<Map<String, dynamic>> _templates() => [
  {
    'id': 'open-default',
    'type': 'button',
    'title': 'פתח במהדורת ברירת המחדל',
    'icon': 'book_24_regular',
    'contexts': ['reader-text', 'reader-pdf'],
    'binding': {
      'program': 'book-links',
      'visibleOutput': 'defaultEdition',
    },
    'action': {
      'type': 'reader.openBook',
      'args': {
        'identity': {r'$output': 'defaultEdition.identity'},
      },
    },
  },
  {
    'id': 'open-edition',
    'type': 'menu',
    'title': 'פתח מהדורה אחרת',
    'icon': 'book_24_regular',
    'binding': {
      'program': 'book-links',
      'visibleOutput': 'editions',
    },
    'childrenBinding': {
      'itemsOutput': 'editions',
      'maxItems': 10,
      'itemTemplate': {
        'id': {
          r'$concat': [
            'edition-',
            {r'$item': 'identity.id'},
          ],
        },
        'title': {r'$item': 'title'},
        'action': {
          'type': 'reader.openBook',
          'args': {
            'identity': {r'$item': 'identity'},
          },
        },
      },
    },
  },
];

Matcher _throwsProgramError(String code) => throwsA(
  isA<DeclarativeProgramException>().having(
    (error) => error.code,
    'code',
    code,
  ),
);
