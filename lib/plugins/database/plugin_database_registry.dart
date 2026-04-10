import 'plugin_database_source.dart';

/// Registry מרכזי של מקורות נתונים SQLite הזמינים לתוספים.
///
/// **רישום מקורות (אחריות האפליקציה):**
/// רישום מקורות הוא wire-up ברמת האפליקציה — לא חלק מה-API עצמו.
/// יש לקרוא ל-[register] בזמן אתחול האפליקציה, לדוגמה ב-`main.dart`:
///
/// ```dart
/// PluginDatabaseRegistry.instance.register(PluginDatabaseSource(
///   sourceId: 'talmud_synopsis',
///   label: 'עדי נוסח בבלי',
///   databasePath: '/path/to/talmud_synopsis.db',
///   policy: PluginDatabasePolicy(
///     tables: {'tractates', 'pages', 'witnesses', 'line_alignments',
///              'line_readings', 'word_alignments', 'readings'},
///     columnsByTable: {
///       'tractates':      {'id', 'name'},
///       'pages':          {'id', 'tractate_id', 'name'},
///       'witnesses':      {'id', 'name'},
///       'line_alignments': {'id', 'page_id', 'sequence_number', 'reference'},
///       'line_readings':  {'id', 'alignment_id', 'witness_id', 'text'},
///       'word_alignments': {'id', 'page_id', 'sequence_number', 'reference'},
///       'readings':       {'id', 'alignment_id', 'witness_id', 'text'},
///     },
///     allowedJoins: [
///       PluginJoinRule(tableA: 'pages',           columnA: 'tractate_id',
///                      tableB: 'tractates',        columnB: 'id'),
///       PluginJoinRule(tableA: 'line_alignments', columnA: 'page_id',
///                      tableB: 'pages',            columnB: 'id'),
///       PluginJoinRule(tableA: 'line_readings',   columnA: 'alignment_id',
///                      tableB: 'line_alignments', columnB: 'id'),
///       PluginJoinRule(tableA: 'line_readings',   columnA: 'witness_id',
///                      tableB: 'witnesses',        columnB: 'id'),
///       PluginJoinRule(tableA: 'word_alignments', columnA: 'page_id',
///                      tableB: 'pages',            columnB: 'id'),
///       PluginJoinRule(tableA: 'readings',        columnA: 'alignment_id',
///                      tableB: 'word_alignments', columnB: 'id'),
///       PluginJoinRule(tableA: 'readings',        columnA: 'witness_id',
///                      tableB: 'witnesses',        columnB: 'id'),
///     ],
///   ),
/// ));
/// ```
///
/// תוספים לא יכולים לגשת ישירות ל-registry — גישתם מתווכת דרך ה-service.
class PluginDatabaseRegistry {
  static final PluginDatabaseRegistry instance = PluginDatabaseRegistry._();
  PluginDatabaseRegistry._();

  final Map<String, PluginDatabaseSource> _sources = {};

  /// רישום מקור נתונים חדש
  void register(PluginDatabaseSource source) {
    _sources[source.sourceId] = source;
  }

  /// קבלת מקור לפי ID, או null אם לא קיים
  PluginDatabaseSource? getSource(String sourceId) => _sources[sourceId];

  /// רשימת כל המקורות הרשומים
  List<PluginDatabaseSource> getAllSources() => _sources.values.toList();

  /// בדיקה אם מקור רשום
  bool hasSource(String sourceId) => _sources.containsKey(sourceId);
}
