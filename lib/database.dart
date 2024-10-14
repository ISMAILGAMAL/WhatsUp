import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  String generateChatId(String userAUid, String userBUid) {
    List<String> uids = [userAUid, userBUid]
      ..sort(); // Ensure they're sorted lexographically for consistency
    return uids.join('_');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String path = join(await getDatabasesPath(), '${uid}_chats.db');

      return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('PRAGMA foreign_keys = ON;'); // Enable foreign keys

          await db.execute(
            'CREATE TABLE chats ('
            'id TEXT PRIMARY KEY, '
            'uid TEXT, '
            'name TEXT, '
            'email TEXT, '
            'profileUrl TEXT, '
            'unreadCount INTEGER'
            ')',
          );
          await db.execute(
            'CREATE TABLE messages ('
            'id TEXT PRIMARY KEY, '
            'chatId TEXT, '
            'content TEXT, '
            'senderId TEXT, '
            'recipientId TEXT, '
            'timestamp INTEGER, '
            'status TEXT, '
            'FOREIGN KEY (chatId) REFERENCES chats(id) ON DELETE CASCADE'
            ')',
          );
        },
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<bool> searchChat(String chatId) async {
    final db = await database;
    List<Map<String, dynamic>> result =
        await db.query('chats', where: 'id = ?', whereArgs: [chatId]);
    return result.isNotEmpty;
  }

  Future<void> createNewChat(Map<String, dynamic> chat) async {
    final db = await database;
    await db.insert(
      'chats',
      chat,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> createNewMessage(Map<String, dynamic> message) async {
    final db = await database;
    if (message['timestamp'] is Timestamp) {
      message['timestamp'] =
          (message['timestamp'] as Timestamp).millisecondsSinceEpoch;
    }
    await db.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> get allChats async {
    final db = await database;
    return await db.query('chats');
  }

  Future<int> unreadCountForChat(String chatId) async {
    final db = await database;
    final result =
        await db.query('chats', where: 'id = ?', whereArgs: [chatId]);
    return result.first['unreadCount'] as int;
  }

  Future<List<Map<String, dynamic>>> allMessagesForChat(String chatId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'chatId= ?',
      whereArgs: [chatId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> allReceivedMessagesForChat(
      String chatId, String recipientId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'chatId = ? AND status = ? AND recipientId = ?',
      whereArgs: [chatId, 'received', recipientId],
      orderBy: 'timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> allUnsyncedMessagesForChat(
      Map<String, dynamic> chat) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'status = ? AND chatId = ?',
      whereArgs: ['pending', chat['id']],
    );
  }

  Future<void> updateMessages(List<Map<String, dynamic>> messages) async {
    final db = await database;
    for (final message in messages) {
      if (message['timestamp'] is Timestamp) {
        message['timestamp'] =
            (message['timestamp'] as Timestamp).millisecondsSinceEpoch;
      }
      await db.update(
        'messages',
        message,
        where: 'id = ?',
        whereArgs: [message['id']],
      );
    }
  }

  Future<void> updateChat(Map<String, dynamic> chat) async {
    final db = await database;
    await db.update(
      'chats',
      {
        'name': chat['name'],
        'email': chat['email'],
        'profileUrl': chat['profileUrl'],
      },
      where: 'uid = ?',
      whereArgs: [chat['uid']],
    );
  }

  Future<void> updateUnreadCount(String chatId, int counter) async {
    final db = await database;
    await db.update(
      'chats',
      {'unreadCount': counter},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<List<Map<String, dynamic>>> getDifferent(
      List<Map<String, dynamic>> messages) async {
    final db = await database;

    List<Map<String, dynamic>> different = [];

    for (var message in messages) {
      message['timestamp'] =
          (message['timestamp'] as Timestamp).millisecondsSinceEpoch;

      final storedMessage = await db
          .query('messages', where: 'id = ?', whereArgs: [message['id']]);
      if (storedMessage.first != message) {
        different.add(message);
      }
    }

    return different;
  }

  Future<void> deleteChat(Map<String, dynamic> chat) async {
    final db = await database;
    await db.delete(
      'chats',
      where: 'id = ?',
      whereArgs: [chat['id']],
    );
  }

  Future<void> deleteMessage(Map<String, dynamic> message) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [message['id']],
    );
  }

  void resetDatabase() {
    _database = null; // Clear the existing database reference
  }
}
