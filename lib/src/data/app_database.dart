import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'smartledger.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

class AppDatabase extends GeneratedDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  Future<void> initialize() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
        type TEXT NOT NULL CHECK(type IN ('credit', 'payment')),
        amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    try {
      await customStatement('ALTER TABLE transactions ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    try {
      await customStatement('ALTER TABLE transactions ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
    } catch (_) {}
    await customStatement('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
    await customStatement("CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone) WHERE phone != ''");
    await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_customer ON transactions(customer_id)');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS backup_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        provider TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
