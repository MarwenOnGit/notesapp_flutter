import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class User {
  final int? id;
  final String username;
  final String password; // In production, hash this!
  final String createdAt;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'createdAt': createdAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      createdAt: map['createdAt'],
    );
  }
}

class Mood {
  final int? id;
  final int userId;
  final String content;
  final double sentimentScore;
  final String date;
  final String createdAt;

  Mood({
    this.id,
    required this.userId,
    required this.content,
    required this.sentimentScore,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'sentimentScore': sentimentScore,
      'date': date,
      'createdAt': createdAt,
    };
  }

  factory Mood.fromMap(Map<String, dynamic> map) {
    return Mood(
      id: map['id'],
      userId: map['userId'],
      content: map['content'],
      sentimentScore: map['sentimentScore'] as double,
      date: map['date'],
      createdAt: map['createdAt'],
    );
  }
}

class DatabaseHelper {
  static const String usersTable = 'users';
  static const String moodsTable = 'moods';
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mood_diary.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table
    await db.execute('''
      CREATE TABLE $usersTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Create moods table
    await db.execute('''
      CREATE TABLE $moodsTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        content TEXT NOT NULL,
        sentimentScore REAL NOT NULL,
        date TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(userId) REFERENCES $usersTable(id) ON DELETE CASCADE
      )
    ''');
  }

  // User operations
  Future<User?> registerUser(String username, String password) async {
    try {
      final db = await database;
      final id = await db.insert(
        usersTable,
        User(
          username: username,
          password: password,
          createdAt: DateTime.now().toString(),
        ).toMap(),
      );
      return User(
        id: id,
        username: username,
        password: password,
        createdAt: DateTime.now().toString(),
      );
    } catch (e) {
      return null; // Username already exists
    }
  }

  Future<User?> loginUser(String username, String password) async {
    final db = await database;
    final result = await db.query(
      usersTable,
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );

    if (result.isEmpty) {
      return null;
    }

    return User.fromMap(result.first);
  }

  // Mood operations
  Future<int> insertMood(Mood mood) async {
    final db = await database;
    return await db.insert(moodsTable, mood.toMap());
  }

  Future<List<Mood>> getUserMoods(int userId) async {
    final db = await database;
    final result = await db.query(
      moodsTable,
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return result.map((map) => Mood.fromMap(map)).toList();
  }

  Future<int> deleteMood(int moodId) async {
    final db = await database;
    return await db.delete(
      moodsTable,
      where: 'id = ?',
      whereArgs: [moodId],
    );
  }

  Future<void> deleteAllUserData(int userId) async {
    final db = await database;
    await db.delete(
      moodsTable,
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }
}
