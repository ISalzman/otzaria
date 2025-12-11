import 'package:sqflite/sqflite.dart';
import '../../core/models/category.dart';
import '../sqflite/query_loader.dart';
import 'database.dart';

class CategoryDao {
  final MyDatabase _db;
  late final Map<String, String> _queries;

  CategoryDao(this._db) {
    _queries = QueryLoader.loadQueries('CategoryQueries.sq');
  }

  Future<Database> get database => _db.database;

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectAll']!);
    return result.map((row) => Category.fromJson(row)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectById']!, [id]);
    if (result.isEmpty) return null;
    return Category.fromJson(result.first);
  }

  Future<List<Category>> getRootCategories() async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectRoot']!);
    return result.map((row) => Category.fromJson(row)).toList();
  }

  Future<List<Category>> getCategoriesByParentId(int parentId) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectByParentId']!, [parentId]);
    return result.map((row) => Category.fromJson(row)).toList();
  }

  Future<int> insertCategory(int? parentId, String title, int level) async {
    final db = await database;
    return await db.rawInsert(_queries['insert']!, [parentId, title, level]);
  }

  Future<int> insertCategoryAndGetId(int? parentId, String title, int level) async {
    final db = await database;
    await db.rawInsert(_queries['insert']!, [parentId, title, level]);
    final result = await db.rawQuery(_queries['lastInsertRowId']!);
    return result.first.values.first as int;
  }

  Future<int> updateCategory(int id, String title) async {
    final db = await database;
    return await db.rawUpdate(_queries['update']!, [title, id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.rawDelete(_queries['delete']!, [id]);
  }

  Future<int> countAllCategories() async {
    final db = await database;
    final result = await db.rawQuery(_queries['countAll']!);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
