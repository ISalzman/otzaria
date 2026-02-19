import 'package:sqflite/sqflite.dart';
import '../../core/models/generation.dart';
import '../sqflite/query_loader.dart';
import 'database.dart';

class GenerationDao {
  final MyDatabase _db;
  late final Map<String, String> _queries;

  GenerationDao(this._db) {
    _queries = QueryLoader.loadQueries('GenerationQueries.sq');
  }

  Future<Database> get database => _db.database;

  Future<List<Generation>> getAllGenerations() async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectAll']!);
    return result.map((row) => Generation.fromJson(row)).toList();
  }

  Future<Generation?> getGenerationById(int id) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectById']!, [id]);
    if (result.isEmpty) return null;
    return Generation.fromJson(result.first);
  }

  Future<Generation?> getGenerationByName(String name) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectByName']!, [name]);
    if (result.isEmpty) return null;
    return Generation.fromJson(result.first);
  }

  Future<List<Generation>> getChildren(int parentGenerationId) async {
    final db = await database;
    final result =
        await db.rawQuery(_queries['selectChildren']!, [parentGenerationId]);
    return result.map((row) => Generation.fromJson(row)).toList();
  }
}
