import 'package:sqflite/sqflite.dart';
import '../../core/models/topic.dart';
import '../sqflite/query_loader.dart';
import 'database.dart';

class TopicDao {
  final MyDatabase _db;
  late final Map<String, String> _queries;

  TopicDao(this._db) {
    _queries = QueryLoader.loadQueries('TopicQueries.sq');
  }

  Future<Database> get database => _db.database;

  Future<List<Topic>> getAllTopics() async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectAll']!);
    return result.map((row) => Topic.fromJson(row)).toList();
  }

  Future<Topic?> getTopicById(int id) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectById']!, [id]);
    if (result.isEmpty) return null;
    return Topic.fromJson(result.first);
  }

  Future<Topic?> getTopicByName(String name) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectByName']!, [name]);
    if (result.isEmpty) return null;
    return Topic.fromJson(result.first);
  }

  Future<List<Topic>> getTopicsByBookId(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectByBookId']!, [bookId]);
    return result.map((row) => Topic.fromJson(row)).toList();
  }

  Future<int> insertTopic(String name) async {
    final db = await database;
    return await db.rawInsert(_queries['insert']!, [name]);
  }

  Future<int> insertTopicAndGetId(String name) async {
    final db = await database;
    await db.rawInsert(_queries['insertAndGetId']!, [name]);
    final result = await db.rawQuery(_queries['lastInsertRowId']!);
    return result.first.values.first as int;
  }

  Future<int?> getTopicIdByName(String name) async {
    final db = await database;
    final result = await db.rawQuery(_queries['selectIdByName']!, [name]);
    if (result.isEmpty) return null;
    return result.first['id'] as int;
  }

  Future<int> deleteTopic(int id) async {
    final db = await database;
    return await db.rawDelete(_queries['delete']!, [id]);
  }

  Future<int> countAllTopics() async {
    final db = await database;
    final result = await db.rawQuery(_queries['countAll']!);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Junction table operations
  Future<int> linkBookTopic(int bookId, int topicId) async {
    final db = await database;
    return await db.rawInsert(_queries['linkBookTopic']!, [bookId, topicId]);
  }

  Future<int> unlinkBookTopic(int bookId, int topicId) async {
    final db = await database;
    return await db.rawDelete(_queries['unlinkBookTopic']!, [bookId, topicId]);
  }

  Future<int> deleteAllBookTopics(int bookId) async {
    final db = await database;
    return await db.rawDelete(_queries['deleteAllBookTopics']!, [bookId]);
  }

  Future<int> countBookTopics(int bookId) async {
    final db = await database;
    final result = await db.rawQuery(_queries['countBookTopics']!, [bookId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
