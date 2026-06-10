import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/receipt.dart';

class ReceiptDatabase {
  static final ReceiptDatabase instance = ReceiptDatabase._init();
  static Database? _database;

  ReceiptDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE receipts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT NOT NULL,
        firestore_id TEXT,
        category TEXT,
        photo_url TEXT,
        is_recurring INTEGER NOT NULL DEFAULT 0,
        recurring_interval TEXT,
        next_due_date TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE receipts ADD COLUMN firestore_id TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE receipts ADD COLUMN category TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE receipts ADD COLUMN photo_url TEXT');
      await db.execute('ALTER TABLE receipts ADD COLUMN is_recurring INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE receipts ADD COLUMN recurring_interval TEXT');
      await db.execute('ALTER TABLE receipts ADD COLUMN next_due_date TEXT');
    }
  }

  Future<Receipt> createReceipt(Receipt receipt) async {
    final db = await instance.database;
    final id = await db.insert('receipts', receipt.toMap());
    return receipt.copyWith(id: id);
  }

  Future<List<Receipt>> readAllReceipts() async {
    final db = await instance.database;
    final result = await db.query('receipts', orderBy: 'date DESC');
    return result.map((json) => Receipt.fromMap(json)).toList();
  }

  Future<void> updateReceipt(Receipt receipt) async {
    final db = await instance.database;
    await db.update(
      'receipts',
      receipt.toMap(),
      where: 'id = ?',
      whereArgs: [receipt.id],
    );
  }

  Future<void> deleteReceipt(int id) async {
    final db = await instance.database;
    await db.delete('receipts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertAll(List<Receipt> receipts) async {
    final db = await instance.database;
    await db.delete('receipts');
    for (final receipt in receipts) {
      await db.insert('receipts', receipt.toMap());
    }
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('receipts');
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
  }
}
