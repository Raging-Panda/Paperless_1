import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'paperless.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        payment_method TEXT NOT NULL
      )
    ''');
  }

  /// Get the first user from the database (or null if no user exists)
  Future<User?> getUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return User.fromMap(maps.first);
  }

  /// Insert or update user data
  /// If user with id=1 exists, update it; otherwise insert new user
  Future<void> insertOrUpdateUser(User user) async {
    final db = await database;

    // Check if a user exists
    final existingUsers = await db.query('users', limit: 1);

    if (existingUsers.isEmpty) {
      // Insert new user with id=1
      await db.insert(
        'users',
        user.copyWith(id: 1).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // Update existing user (always use id=1)
      await db.update(
        'users',
        user.copyWith(id: 1).toMap(),
        where: 'id = ?',
        whereArgs: [1],
      );
    }
  }

  /// Delete all users (for testing purposes)
  Future<void> deleteAllUsers() async {
    final db = await database;
    await db.delete('users');
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
