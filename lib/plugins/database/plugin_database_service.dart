import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'package:otzaria/data/sqlite/sqlite3_api.dart' as sqlite3_pkg;
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'plugin_database_source.dart';
import 'plugin_database_registry.dart';

/// שגיאה מובנית בשירות מסד הנתונים לתוספים
class PluginDatabaseException implements Exception {
  final String code;
  final String message;

  const PluginDatabaseException(this.code, this.message);

  @override
  String toString() => 'PluginDatabaseException($code): $message';
}

/// שירות מרכזי לגישת תוספים למסדי נתונים SQLite.
///
/// מנהל:
/// - רזולוציה של מקורות
/// - ולידציה של בקשות מול policy
/// - קומפילציה ל-SQL פרמטרי
/// - ביצוע ב-read-only
class PluginDatabaseService {
  final PluginDatabaseRegistry _registry;

  PluginDatabaseService({PluginDatabaseRegistry? registry})
    : _registry = registry ?? PluginDatabaseRegistry.instance;

  // ----------------------------------------------------------------
  // Public API
  // ----------------------------------------------------------------

  /// מחזיר רשימת מקורות שהוצהרו במניפסט וזמינים ב-registry
  List<Map<String, dynamic>> listSourcesForPlugin(InstalledPlugin plugin) {
    final result = <Map<String, dynamic>>[];
    for (final declared in plugin.manifest.databaseSources) {
      final sourceId = declared['id'];
      if (sourceId is! String || sourceId.isEmpty) continue;
      final source = _registry.getSource(sourceId);
      result.add({
        'id': sourceId,
        'label': source?.label ?? sourceId,
        'available': source != null && File(source.databasePath).existsSync(),
      });
    }
    return result;
  }

  /// מחזיר schema חשוף לתוסף (לפי policy בלבד)
  Map<String, dynamic> describeSource(InstalledPlugin plugin, String sourceId) {
    _ensureSourceDeclared(plugin, sourceId);
    final source = _resolveSource(sourceId);
    final policy = source.policy;

    final tables =
        policy.tables.map((tableName) {
          final cols = (policy.columnsByTable[tableName] ?? <String>{}).toList()
            ..sort();
          return {'name': tableName, 'columns': cols};
        }).toList()..sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );

    return {
      'source': {'id': source.sourceId, 'label': source.label},
      'schema': {'tables': tables},
      'limits': {
        'maxLimit': policy.maxLimit,
        'maxBatchQueries': policy.maxBatchQueries,
      },
    };
  }

  /// ביצוע שאילתה דקלרטיבית
  Map<String, dynamic> query(
    InstalledPlugin plugin,
    Map<String, dynamic> spec,
  ) {
    final sourceId = spec['sourceId'];
    if (sourceId is! String || sourceId.isEmpty) {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'sourceId must be a non-empty string',
      );
    }

    _ensureSourceDeclared(plugin, sourceId);
    final source = _resolveSource(sourceId);
    final policy = source.policy;

    // Validate (throws on any violation)
    _validateSpec(spec, policy);

    // Apply effective limits
    final rawLimit = spec['limit'] as int?;
    final effectiveLimit = rawLimit != null
        ? min(rawLimit, policy.maxLimit)
        : policy.maxLimit;
    final offset = spec['offset'] as int? ?? 0;

    // Execute (sqlite3 is synchronous — fetch limit+1 to detect hasMore)
    final db = _openConnection(source);
    final fetchLimit = effectiveLimit + 1;
    final compiledWithProbe = _compileSpec(spec, fetchLimit, offset);
    final sw = Stopwatch()..start();
    try {
      final resultSet = db.select(
        compiledWithProbe.sql,
        compiledWithProbe.params,
      );
      sw.stop();

      final rowFormat = spec['rowFormat'] as String? ?? 'array';
      final columns = resultSet.columnNames;
      final hasMore = resultSet.length > effectiveLimit;
      final rawRows = hasMore
          ? resultSet.take(effectiveLimit).toList()
          : resultSet.toList();
      var resultBytes = 0;

      Object? checkedValue(Object? value) {
        resultBytes += _estimateValueBytes(value);
        if (resultBytes > policy.maxResultBytes) {
          throw PluginDatabaseException(
            'database.query_too_large',
            'Query result exceeds maxResultBytes (${policy.maxResultBytes})',
          );
        }
        return value;
      }

      final List<dynamic> rows;
      if (rowFormat == 'object') {
        final seen = <String>{};
        for (final col in columns) {
          if (!seen.add(col)) {
            throw PluginDatabaseException(
              'database.invalid_spec',
              'Duplicate column name "$col" in result set — add "as" aliases to disambiguate',
            );
          }
        }
        rows = rawRows.map((row) {
          final obj = <String, dynamic>{};
          for (var i = 0; i < columns.length; i++) {
            obj[columns[i]] = checkedValue(row.columnAt(i));
          }
          return obj;
        }).toList();
      } else {
        rows = rawRows
            .map((row) => row.values.map(checkedValue).toList())
            .toList();
      }

      return {
        'meta': {
          'sourceId': sourceId,
          'rowCount': rows.length,
          'limit': effectiveLimit,
          'offset': offset,
          'hasMore': hasMore,
          'elapsedMs': sw.elapsedMilliseconds,
        },
        'columns': columns.map((c) => {'name': c}).toList(),
        'rows': rows,
      };
    } finally {
      db.close();
    }
  }

  /// ביצוע batch של שאילתות
  List<Map<String, dynamic>> batchQuery(
    InstalledPlugin plugin,
    List<Map<String, dynamic>> queries,
  ) {
    if (queries.isEmpty) return [];

    for (final querySpec in queries) {
      final sourceId = querySpec['sourceId'];
      if (sourceId is! String || sourceId.isEmpty) continue;
      final source = _registry.getSource(sourceId);
      if (source != null && queries.length > source.policy.maxBatchQueries) {
        throw PluginDatabaseException(
          'database.query_too_large',
          'Batch exceeds maxBatchQueries (${source.policy.maxBatchQueries})',
        );
      }
    }

    return queries.map((q) => query(plugin, q)).toList();
  }

  // ----------------------------------------------------------------
  // Private: source resolution
  // ----------------------------------------------------------------

  void _ensureSourceDeclared(InstalledPlugin plugin, String sourceId) {
    final declared = plugin.manifest.databaseSources;
    if (!declared.any((s) => s['id'] == sourceId)) {
      throw PluginDatabaseException(
        'database.source_not_found',
        'Source "$sourceId" is not declared in plugin manifest',
      );
    }
  }

  PluginDatabaseSource _resolveSource(String sourceId) {
    final source = _registry.getSource(sourceId);
    if (source == null) {
      throw PluginDatabaseException(
        'database.source_unavailable',
        'Source "$sourceId" is not registered',
      );
    }
    if (!File(source.databasePath).existsSync()) {
      throw PluginDatabaseException(
        'database.source_unavailable',
        'Database file not found for source "$sourceId"',
      );
    }
    if (!source.readOnly) {
      throw PluginDatabaseException(
        'database.source_not_read_only',
        'Source "$sourceId" is not registered as read-only',
      );
    }
    return source;
  }

  sqlite3_pkg.Database _openConnection(PluginDatabaseSource source) {
    final database = sqlite3_pkg.sqlite3.open(
      source.databasePath,
      mode: sqlite3_pkg.OpenMode.readOnly,
    );
    database.execute('PRAGMA query_only = ON');
    return database;
  }

  // ----------------------------------------------------------------
  // Private: validation
  // ----------------------------------------------------------------

  /// מוודא את spec מול policy ומחזיר alias→table map
  Map<String, String> _validateSpec(
    Map<String, dynamic> spec,
    PluginDatabasePolicy policy,
  ) {
    _assertOnlyKeys(spec, const {
      'sourceId',
      'from',
      'select',
      'joins',
      'where',
      'orderBy',
      'limit',
      'offset',
      'rowFormat',
    }, 'query');
    final aliasMap = <String, String>{};

    final from = _requireMap(spec['from'], 'from');
    _assertOnlyKeys(from, const {'table', 'alias'}, 'from');
    final fromTable = _requiredString(from['table'], 'from.table');
    if (!policy.isTableAllowed(fromTable)) {
      throw PluginDatabaseException(
        'database.table_not_allowed',
        'Table "$fromTable" is not allowed',
      );
    }
    final fromAlias = _optionalString(from['alias'], 'from.alias') ?? fromTable;
    _assertValidIdentifier(fromAlias, 'from.alias');
    aliasMap[fromAlias] = fromTable;

    final joins = _optionalList(spec['joins'], 'joins');
    if (joins.length > policy.maxJoins) {
      throw PluginDatabaseException(
        'database.query_too_large',
        'Too many joins (max: ${policy.maxJoins})',
      );
    }
    for (var joinIndex = 0; joinIndex < joins.length; joinIndex++) {
      final jm = _requireMap(joins[joinIndex], 'joins[$joinIndex]');
      _assertOnlyKeys(
        jm,
        const {'type', 'table', 'alias', 'on'},
        'joins[$joinIndex]',
      );
      final joinTable = _requiredString(
        jm['table'],
        'joins[$joinIndex].table',
      );
      if (!policy.isTableAllowed(joinTable)) {
        throw PluginDatabaseException(
          'database.table_not_allowed',
          'Table "$joinTable" is not allowed',
        );
      }
      final joinAlias =
          _optionalString(jm['alias'], 'joins[$joinIndex].alias') ?? joinTable;
      _assertValidIdentifier(joinAlias, 'join.alias');
      if (aliasMap.containsKey(joinAlias)) {
        throw PluginDatabaseException(
          'database.invalid_spec',
          'Duplicate table alias: "$joinAlias"',
        );
      }

      final joinType =
          (_optionalString(jm['type'], 'joins[$joinIndex].type') ?? 'inner')
              .toLowerCase();
      if (joinType != 'inner' && joinType != 'left') {
        throw PluginDatabaseException(
          'database.invalid_spec',
          'Unsupported join type: "$joinType" (allowed: inner, left)',
        );
      }

      final onConditions = _optionalList(
        jm['on'],
        'joins[$joinIndex].on',
      );
      if (onConditions.isEmpty) {
        throw PluginDatabaseException(
          'database.invalid_spec',
          'Join on "$joinTable" must have at least one ON condition',
        );
      }
      final aliasesWithJoin = {...aliasMap, joinAlias: joinTable};
      for (var onIndex = 0; onIndex < onConditions.length; onIndex++) {
        final cm = _requireMap(
          onConditions[onIndex],
          'joins[$joinIndex].on[$onIndex]',
        );
        _assertOnlyKeys(
          cm,
          const {'left', 'op', 'right'},
          'joins[$joinIndex].on[$onIndex]',
        );
        final operator = _optionalString(
          cm['op'],
          'joins[$joinIndex].on[$onIndex].op',
        );
        final leftRef = _requiredString(
          cm['left'],
          'joins[$joinIndex].on[$onIndex].left',
        );
        final rightRef = _requiredString(
          cm['right'],
          'joins[$joinIndex].on[$onIndex].right',
        );
        if (operator != '=') {
          throw PluginDatabaseException(
            'database.invalid_spec',
            'Join operator must be "=" (found: "${operator ?? ""}")',
          );
        }
        final leftAlias = _referenceAlias(leftRef);
        final rightAlias = _referenceAlias(rightRef);
        final joinsNewTable =
            (leftAlias == joinAlias) != (rightAlias == joinAlias);
        if (!joinsNewTable) {
          throw PluginDatabaseException(
            'database.invalid_spec',
            'Join ON must connect "$joinAlias" to an earlier table alias',
          );
        }
        final earlierAlias = leftAlias == joinAlias ? rightAlias : leftAlias;
        if (!aliasMap.containsKey(earlierAlias)) {
          throw PluginDatabaseException(
            'database.invalid_spec',
            'Join references unavailable alias "$earlierAlias"',
          );
        }
        final left = _resolveRef(leftRef, aliasesWithJoin, policy);
        final right = _resolveRef(rightRef, aliasesWithJoin, policy);
        if (!policy.isJoinAllowed(left.$1, left.$2, right.$1, right.$2)) {
          throw PluginDatabaseException(
            'database.join_not_allowed',
            'Join "$leftRef = $rightRef" is not allowed by policy',
          );
        }
      }
      aliasMap[joinAlias] = joinTable;
    }

    final select = _optionalList(spec['select'], 'select');
    if (select.isEmpty) {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'Select list must not be empty',
      );
    }
    if (select.length > policy.maxColumns) {
      throw PluginDatabaseException(
        'database.query_too_large',
        'Too many select columns (max: ${policy.maxColumns})',
      );
    }
    final outputNames = <String>{};
    for (var index = 0; index < select.length; index++) {
      final sm = _requireMap(select[index], 'select[$index]');
      _assertOnlyKeys(sm, const {'expr', 'as'}, 'select[$index]');
      final expr = _requiredString(sm['expr'], 'select[$index].expr');
      _resolveRef(expr, aliasMap, policy);
      final alias = _optionalString(sm['as'], 'select[$index].as');
      if (alias != null) {
        _assertValidIdentifier(alias, 'select.as');
      }
      final outputName = alias ?? expr;
      if (!outputNames.add(outputName)) {
        throw PluginDatabaseException(
          'database.invalid_spec',
          'Duplicate output column name: "$outputName" — use distinct "as" aliases',
        );
      }
    }

    if (spec['where'] != null) {
      final where = _requireMap(spec['where'], 'where');
      final conditionCount = _validateWhere(where, aliasMap, policy, 0);
      if (conditionCount > policy.maxWhereConditions) {
        throw PluginDatabaseException(
          'database.query_too_large',
          'Too many WHERE conditions (max: ${policy.maxWhereConditions})',
        );
      }
    }

    final orderBy = _optionalList(spec['orderBy'], 'orderBy');
    if (orderBy.length > policy.maxColumns) {
      throw PluginDatabaseException(
        'database.query_too_large',
        'Too many orderBy columns (max: ${policy.maxColumns})',
      );
    }
    for (var index = 0; index < orderBy.length; index++) {
      final om = _requireMap(orderBy[index], 'orderBy[$index]');
      _assertOnlyKeys(om, const {'expr', 'direction'}, 'orderBy[$index]');
      final expr = _requiredString(om['expr'], 'orderBy[$index].expr');
      _resolveRef(expr, aliasMap, policy);
      final direction =
          (_optionalString(om['direction'], 'orderBy[$index].direction') ??
                  'asc')
              .toLowerCase();
      if (direction != 'asc' && direction != 'desc') {
        throw PluginDatabaseException(
          'database.invalid_spec',
          'Invalid ORDER BY direction: "$direction"',
        );
      }
    }

    final limit = _optionalInteger(spec['limit'], 'limit');
    if (limit != null && limit > policy.maxLimit) {
      throw PluginDatabaseException(
        'database.query_too_large',
        'limit $limit exceeds maxLimit ${policy.maxLimit}',
      );
    }
    if (limit != null && limit < 0) {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'limit must be non-negative',
      );
    }
    final offset = _optionalInteger(spec['offset'], 'offset');
    if (offset != null && offset < 0) {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'offset must be non-negative',
      );
    }
    if (offset != null && offset > policy.maxOffset) {
      throw PluginDatabaseException(
        'database.query_too_large',
        'offset $offset exceeds maxOffset ${policy.maxOffset}',
      );
    }
    final rowFormat = _optionalString(spec['rowFormat'], 'rowFormat');
    if (rowFormat != null && rowFormat != 'array' && rowFormat != 'object') {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'rowFormat must be "array" or "object"',
      );
    }

    return aliasMap;
  }

  int _validateWhere(
    Map<String, dynamic> where,
    Map<String, String> aliasMap,
    PluginDatabasePolicy policy,
    int depth,
  ) {
    if (depth > 5) {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'WHERE clause is too deeply nested',
      );
    }
    final op = _requiredString(where['op'], 'where.op');

    if (op == 'and' || op == 'or') {
      _assertOnlyKeys(where, const {'op', 'conditions'}, 'where');
      final conditions = _optionalList(where['conditions'], 'where.conditions');
      if (conditions.isEmpty) {
        throw PluginDatabaseException(
          'database.invalid_spec',
          'WHERE "$op" requires a non-empty "conditions" list',
        );
      }
      if (conditions.length >= policy.maxWhereConditions) {
        throw PluginDatabaseException(
          'database.query_too_large',
          'Too many WHERE conditions (max: ${policy.maxWhereConditions})',
        );
      }
      var count = 1;
      for (var index = 0; index < conditions.length; index++) {
        count += _validateWhere(
          _requireMap(conditions[index], 'where.conditions[$index]'),
          aliasMap,
          policy,
          depth + 1,
        );
        if (count > policy.maxWhereConditions) {
          throw PluginDatabaseException(
            'database.query_too_large',
            'Too many WHERE conditions (max: ${policy.maxWhereConditions})',
          );
        }
      }
      return count;
    }

    _assertOnlyKeys(where, const {'op', 'left', 'value'}, 'where');
    final left = _requiredString(where['left'], 'where.left');
    _resolveRef(left, aliasMap, policy);

    const validOps = {
      '=',
      '!=',
      '>',
      '>=',
      '<',
      '<=',
      'in',
      'between',
      'like',
      'isNull',
      'isNotNull',
    };
    if (!validOps.contains(op)) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        'Unsupported WHERE operator: "$op"',
      );
    }

    if (op == 'in') {
      final values = where['value'];
      if (values is! List || values.isEmpty) {
        throw const PluginDatabaseException(
          'database.invalid_spec',
          '"in" operator requires a non-empty list value',
        );
      }
      if (values.length > policy.maxInValues) {
        throw PluginDatabaseException(
          'database.query_too_large',
          'IN contains too many values (max: ${policy.maxInValues})',
        );
      }
      for (final value in values) {
        _validateParameter(value, policy);
      }
    }
    if (op == 'between') {
      final v = where['value'];
      if (v is! List || v.length != 2) {
        throw const PluginDatabaseException(
          'database.invalid_spec',
          '"between" operator requires a 2-element list value',
        );
      }
      _validateParameter(v[0], policy);
      _validateParameter(v[1], policy);
    }
    if (op == 'isNull' || op == 'isNotNull') {
      if (where.containsKey('value')) {
        throw PluginDatabaseException(
          'database.invalid_spec',
          '"$op" must not include a value',
        );
      }
    } else if (op != 'in' && op != 'between') {
      if (!where.containsKey('value')) {
        throw PluginDatabaseException(
          'database.invalid_spec',
          '"$op" requires a value',
        );
      }
      _validateParameter(where['value'], policy);
    }
    return 1;
  }

  Map<String, dynamic> _requireMap(Object? value, String context) {
    if (value is! Map) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context must be an object',
      );
    }
    try {
      return Map<String, dynamic>.from(value);
    } on TypeError {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context keys must be strings',
      );
    }
  }

  List<dynamic> _optionalList(Object? value, String context) {
    if (value == null) return const [];
    if (value is! List) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context must be an array',
      );
    }
    return value;
  }

  int? _optionalInteger(Object? value, String context) {
    if (value == null) return null;
    if (value is! int) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context must be an integer',
      );
    }
    return value;
  }

  String _requiredString(Object? value, String context) {
    final string = _optionalString(value, context);
    if (string == null || string.isEmpty) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context must be a non-empty string',
      );
    }
    return string;
  }

  String? _optionalString(Object? value, String context) {
    if (value == null) return null;
    if (value is! String) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context must be a string',
      );
    }
    return value;
  }

  void _assertOnlyKeys(
    Map<String, dynamic> value,
    Set<String> allowed,
    String context,
  ) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
    if (unknown.isNotEmpty) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        '$context contains unsupported fields: ${unknown.join(', ')}',
      );
    }
  }

  String _referenceAlias(String reference) {
    final parts = reference.split('.');
    if (parts.length != 2) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        'Column reference must be in "alias.column" format: "$reference"',
      );
    }
    return parts.first;
  }

  void _validateParameter(Object? value, PluginDatabasePolicy policy) {
    if (value is! String && value is! num && value is! bool && value != null) {
      throw const PluginDatabaseException(
        'database.invalid_spec',
        'Query parameter must be a JSON scalar',
      );
    }
    if (_estimateValueBytes(value) > policy.maxParameterBytes) {
      throw PluginDatabaseException(
        'database.query_too_large',
        'Query parameter exceeds maxParameterBytes (${policy.maxParameterBytes})',
      );
    }
  }

  /// מפרש ref בפורמט alias.column ומאמת מול policy.
  /// מחזיר (tableName, columnName).
  (String, String) _resolveRef(
    String ref,
    Map<String, String> aliasMap,
    PluginDatabasePolicy policy,
  ) {
    final parts = ref.split('.');
    if (parts.length != 2) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        'Column reference must be in "alias.column" format: "$ref"',
      );
    }
    final alias = parts[0];
    final column = parts[1];
    _assertValidIdentifier(alias, 'column reference alias');
    _assertValidIdentifier(column, 'column name');

    final table = aliasMap[alias];
    if (table == null) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        'Unknown table alias "$alias"',
      );
    }
    if (!policy.isColumnAllowed(table, column)) {
      throw PluginDatabaseException(
        'database.column_not_allowed',
        'Column "$ref" ($table.$column) is not allowed',
      );
    }
    return (table, column);
  }

  void _assertValidIdentifier(String value, String context) {
    final re = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    if (!re.hasMatch(value)) {
      throw PluginDatabaseException(
        'database.invalid_spec',
        'Invalid identifier in $context: "$value"',
      );
    }
  }

  int _estimateValueBytes(Object? value) {
    if (value == null) return 0;
    if (value is String) return value.codeUnits.length * 2;
    if (value is Uint8List) return value.length;
    return 8;
  }

  // ----------------------------------------------------------------
  // Private: SQL compilation
  // ----------------------------------------------------------------

  _CompiledQuery _compileSpec(
    Map<String, dynamic> spec,
    int effectiveLimit,
    int offset,
  ) {
    final params = <Object?>[];
    final sb = StringBuffer();

    // SELECT
    final select = (spec['select'] as List<dynamic>?) ?? [];
    final parts = select
        .map((s) {
          final sm = s as Map<String, dynamic>;
          final expr = sm['expr'] as String;
          final alias = sm['as'] as String?;
          return alias != null ? '$expr AS $alias' : expr;
        })
        .join(', ');
    sb.write('SELECT $parts');

    // FROM
    final from = spec['from'] as Map<String, dynamic>;
    final fromTable = from['table'] as String;
    final fromAlias = from['alias'] as String?;
    sb.write('\nFROM $fromTable');
    if (fromAlias != null && fromAlias != fromTable) {
      sb.write(' $fromAlias');
    }

    // JOINS
    for (final join in (spec['joins'] as List<dynamic>?) ?? []) {
      final jm = join as Map<String, dynamic>;
      final type = (jm['type'] as String? ?? 'inner').toUpperCase();
      final table = jm['table'] as String;
      final alias = jm['alias'] as String?;
      sb.write('\n$type JOIN $table');
      if (alias != null && alias != table) sb.write(' $alias');
      final onConds = (jm['on'] as List<dynamic>?) ?? [];
      if (onConds.isNotEmpty) {
        final onParts = onConds
            .map((c) {
              final cm = c as Map<String, dynamic>;
              return '${cm['left']} = ${cm['right']}';
            })
            .join(' AND ');
        sb.write(' ON $onParts');
      }
    }

    // WHERE
    final where = spec['where'] as Map<String, dynamic>?;
    if (where != null) {
      final clause = _compileWhere(where, params);
      sb.write('\nWHERE $clause');
    }

    // ORDER BY
    final orderBy = (spec['orderBy'] as List<dynamic>?) ?? [];
    if (orderBy.isNotEmpty) {
      final parts = orderBy
          .map((o) {
            final om = o as Map<String, dynamic>;
            final expr = om['expr'] as String;
            final dir = (om['direction'] as String? ?? 'asc').toUpperCase();
            return '$expr $dir';
          })
          .join(', ');
      sb.write('\nORDER BY $parts');
    }

    // LIMIT / OFFSET
    sb.write('\nLIMIT ?');
    params.add(effectiveLimit);
    sb.write('\nOFFSET ?');
    params.add(offset);

    return _CompiledQuery(sb.toString(), params);
  }

  String _compileWhere(Map<String, dynamic> where, List<Object?> params) {
    final op = where['op'] as String;

    if (op == 'and' || op == 'or') {
      final conditions = where['conditions'] as List<dynamic>;
      final parts = conditions
          .map((c) => _compileWhere(c as Map<String, dynamic>, params))
          .toList();
      return '(${parts.join(' ${op.toUpperCase()} ')})';
    }

    final left = where['left'] as String;

    switch (op) {
      case 'isNull':
        return '$left IS NULL';
      case 'isNotNull':
        return '$left IS NOT NULL';
      case 'in':
        final values = where['value'] as List;
        final placeholders = List.filled(values.length, '?').join(', ');
        params.addAll(values.cast<Object?>());
        return '$left IN ($placeholders)';
      case 'between':
        final values = where['value'] as List;
        params.add(values[0] as Object?);
        params.add(values[1] as Object?);
        return '$left BETWEEN ? AND ?';
      default:
        params.add(where['value'] as Object?);
        return '$left $op ?';
    }
  }
}

class _CompiledQuery {
  final String sql;
  final List<Object?> params;

  _CompiledQuery(this.sql, this.params);
}
