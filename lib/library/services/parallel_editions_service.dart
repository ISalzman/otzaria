import 'package:flutter/foundation.dart';
import 'package:otzaria/data/repository/data_repository.dart';
import 'package:otzaria/models/books.dart';
import 'package:otzaria/plugins/database/plugin_database_service.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_book_identity.dart';
import 'package:otzaria/plugins/services/plugin_external_book_loader.dart';
import 'package:otzaria/plugins/services/plugin_external_editions_registry.dart';

/// מהדורה מקבילה של הספר הפתוח, לשימוש הלחצן המובנה בסרגל העיון.
class ParallelEdition {
  final Book book;

  /// המהדורה המובנית (עמית באותה ספרייה, למשל PDF של הש"ס) — היא הפעולה
  /// הראשית של הלחצן כל עוד קיימת; מהדורות של ספקים חיצוניים באות אחריה.
  final bool isCompanion;

  const ParallelEdition({required this.book, required this.isCompanion});
}

/// איתור מהדורות מקבילות לספר הפתוח — מובנות ומקומיות בלבד.
///
/// שני מקורות, ללא שום תקשורת עם שירות חיצוני (קטלוג + דיסק בלבד):
/// 1. ספר עמית בספריית אוצריא (טקסט↔PDF של אותו ספר, כמו הלחצן הישן).
/// 2. מהדורות של ספקים חיצוניים שתוספים הצהירו עליהם דרך
///    `contributes.startup.externalEditions`: טבלת מיפוי במקור נתונים של
///    התוסף מקשרת מזהה ספק ↔ מזהה ספר אוצריא, והתוצאות מסוננות לספרים
///    שנפתחים מקומית. לאוצריא עצמה אין ידע על אף ספק ספציפי.
class ParallelEditionsService {
  ParallelEditionsService._();

  /// תקרת המהדורות לכל קונפיגורציה — כמו מכסת הילדים של לחצן מפוצל.
  static const int _maxEditionsPerConfig = 20;

  /// נקודות הזרקה לבדיקות: הרצת שאילתת ה-DB וטעינת הספרים החיצוניים.
  @visibleForTesting
  static Future<Map<String, dynamic>> Function(
    InstalledPlugin plugin,
    Map<String, dynamic> spec,
  )
  queryRunner = (plugin, spec) => PluginDatabaseService().query(plugin, spec);

  @visibleForTesting
  static Future<List<Book>> Function(String provider, Set<Object> externalIds)
  externalBooksLoader = loadExternalBooksByProvider;

  /// מחזיר את המהדורות בסדר תצוגה: המובנית ראשונה (כשקיימת), ואז מהדורות
  /// הספקים החיצוניים לפי איכות ההתאמה. רשימה ריקה = אין לחצן.
  static Future<List<ParallelEdition>> find(Book current) async {
    final editions = <ParallelEdition>[];

    final companionType = current is PdfBook ? TextBook : PdfBook;
    final library = await DataRepository.instance.library;
    final companion = library.getCompanionBook(current, companionType);
    if (companion != null) {
      editions.add(ParallelEdition(book: companion, isCompanion: true));
    }

    for (final config in PluginExternalEditionsRegistry.instance.configs) {
      try {
        for (final book in await _externalEditions(current, config)) {
          editions.add(ParallelEdition(book: book, isCompanion: false));
        }
      } catch (e) {
        // קונפיגורציה שנכשלת (DB חסר, policy) לא מפילה את הלחצן כולו.
        debugPrint(
          'ParallelEditionsService: ${config.provider} editions failed: $e',
        );
      }
    }
    return editions;
  }

  /// המנוע הגנרי לקונפיגורציה בודדת — חשוף לבדיקות דרך נקודות ההזרקה.
  @visibleForTesting
  static Future<List<Book>> externalEditionsFor(
    Book current,
    PluginExternalEditionsConfig config,
  ) => _externalEditions(current, config);

  static Future<List<Book>> _externalEditions(
    Book current,
    PluginExternalEditionsConfig config,
  ) async {
    final external = PluginBookIdentity.externalOf(current);
    final currentExternalId = external?.provider == config.provider
        ? PluginBookIdentity.parseId(external?.id)
        : null;

    List<int> externalIds;
    if (currentExternalId != null) {
      // ספר של הספק פתוח: מהדורות מקבילות הן ספרי הספק האחרים הממופים
      // לאותם ספרי אוצריא (שני צעדים בטבלת המיפוי).
      final otzariaIds = await _selectIds(
        config,
        select: config.otzariaIdColumn,
        whereColumn: config.externalIdColumn,
        values: [currentExternalId],
      );
      if (otzariaIds.isEmpty) return const [];
      externalIds = await _selectIds(
        config,
        select: config.externalIdColumn,
        whereColumn: config.otzariaIdColumn,
        values: otzariaIds.toSet().toList(),
      );
      externalIds.removeWhere((id) => id == currentExternalId);
    } else {
      final otzariaId = current.id;
      if (otzariaId == null) return const [];
      externalIds = await _selectIds(
        config,
        select: config.externalIdColumn,
        whereColumn: config.otzariaIdColumn,
        values: [otzariaId],
      );
    }
    // הסרת כפילויות תוך שימור סדר איכות ההתאמה של המיפוי.
    final orderedIds = <int>[];
    final seen = <int>{};
    for (final id in externalIds) {
      if (seen.add(id)) orderedIds.add(id);
    }
    if (orderedIds.isEmpty) return const [];

    // רק מהדורות שנפתחות מקומית — ספר שקיים בקטלוג החיצוני בלבד (נפתח
    // באתר הספק) אינו "מהדורה מקבילה" בקורא.
    final books = await externalBooksLoader(
      config.provider,
      orderedIds.toSet(),
    );
    final byId = <int, Book>{};
    for (final book in books) {
      if (book is ExternalLibraryBook) continue;
      final bookExternal = PluginBookIdentity.externalOf(book);
      final id = bookExternal?.provider == config.provider
          ? PluginBookIdentity.parseId(bookExternal?.id)
          : null;
      if (id != null) byId.putIfAbsent(id, () => book);
    }
    return [for (final id in orderedIds) ?byId[id]];
  }

  /// שאילתת עמודה בודדת בטבלת המיפוי, דרך שירות ה-DB לתוספים — כך שה-policy
  /// של המקור (טבלאות, עמודות, מכסות) נאכף גם על המנוע הזה.
  static Future<List<int>> _selectIds(
    PluginExternalEditionsConfig config, {
    required String select,
    required String whereColumn,
    required List<int> values,
  }) async {
    final result = await queryRunner(config.plugin, {
      'sourceId': config.sourceId,
      'from': {'table': config.table, 'alias': 'm'},
      'select': [
        {'expr': 'm.$select', 'as': 'value'},
      ],
      'where': {'op': 'in', 'left': 'm.$whereColumn', 'value': values},
      if (config.orderBy.isNotEmpty)
        'orderBy': [
          for (final order in config.orderBy)
            {
              'expr': 'm.${order.column}',
              'direction': order.descending ? 'desc' : 'asc',
            },
        ],
      'limit': _maxEditionsPerConfig,
      'rowFormat': 'object',
    });
    final rows = result['rows'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map && row['value'] is int) row['value'] as int,
    ];
  }
}
