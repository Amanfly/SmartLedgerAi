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
    // 1. Customers Table with Summary Columns
    await customStatement('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        total_credit_paise INTEGER NOT NULL DEFAULT 0,
        total_payment_paise INTEGER NOT NULL DEFAULT 0,
        balance_paise INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Migration for existing customers
    try { await customStatement('ALTER TABLE customers ADD COLUMN total_credit_paise INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
    try { await customStatement('ALTER TABLE customers ADD COLUMN total_payment_paise INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
    try { await customStatement('ALTER TABLE customers ADD COLUMN balance_paise INTEGER NOT NULL DEFAULT 0'); } catch (_) {}

    // 2. Transactions Table
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

    // 3. Triggers for Automatic Balance Updates (Optimizes performance for 10K+ records)
    await _createTriggers();

    // 4. Indexes
    await customStatement('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
    await customStatement("CREATE UNIQUE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone) WHERE phone != ''");
    await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_customer ON transactions(customer_id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_sync_deleted ON transactions(is_synced, is_deleted)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_created ON transactions(created_at DESC)');

    // 5. Utility Tables
    await customStatement('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTriggers() async {
    // TRIGGER: On Insert
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_transactions_insert AFTER INSERT ON transactions
      WHEN NEW.is_deleted = 0
      BEGIN
        UPDATE customers 
        SET total_credit_paise = total_credit_paise + (CASE WHEN NEW.type = 'credit' THEN NEW.amount_paise ELSE 0 END),
            total_payment_paise = total_payment_paise + (CASE WHEN NEW.type = 'payment' THEN NEW.amount_paise ELSE 0 END),
            balance_paise = balance_paise + (CASE WHEN NEW.type = 'credit' THEN NEW.amount_paise ELSE -NEW.amount_paise END)
        WHERE id = NEW.customer_id;
      END;
    ''');

    // TRIGGER: On Soft Delete (Update is_deleted to 1)
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_transactions_soft_delete AFTER UPDATE OF is_deleted ON transactions
      WHEN OLD.is_deleted = 0 AND NEW.is_deleted = 1
      BEGIN
        UPDATE customers 
        SET total_credit_paise = total_credit_paise - (CASE WHEN OLD.type = 'credit' THEN OLD.amount_paise ELSE 0 END),
            total_payment_paise = total_payment_paise - (CASE WHEN OLD.type = 'payment' THEN OLD.amount_paise ELSE 0 END),
            balance_paise = balance_paise - (CASE WHEN OLD.type = 'credit' THEN OLD.amount_paise ELSE -OLD.amount_paise END)
        WHERE id = OLD.customer_id;
      END;
    ''');

    // TRIGGER: On Update (Amount or Type change)
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS trg_transactions_update AFTER UPDATE ON transactions
      WHEN OLD.is_deleted = 0 AND NEW.is_deleted = 0
      BEGIN
        -- Revert OLD values
        UPDATE customers 
        SET total_credit_paise = total_credit_paise - (CASE WHEN OLD.type = 'credit' THEN OLD.amount_paise ELSE 0 END),
            total_payment_paise = total_payment_paise - (CASE WHEN OLD.type = 'payment' THEN OLD.amount_paise ELSE 0 END),
            balance_paise = balance_paise - (CASE WHEN OLD.type = 'credit' THEN OLD.amount_paise ELSE -OLD.amount_paise END)
        WHERE id = OLD.customer_id;
        
        -- Apply NEW values
        UPDATE customers 
        SET total_credit_paise = total_credit_paise + (CASE WHEN NEW.type = 'credit' THEN NEW.amount_paise ELSE 0 END),
            total_payment_paise = total_payment_paise + (CASE WHEN NEW.type = 'payment' THEN NEW.amount_paise ELSE 0 END),
            balance_paise = balance_paise + (CASE WHEN NEW.type = 'credit' THEN NEW.amount_paise ELSE -NEW.amount_paise END)
        WHERE id = NEW.customer_id;
      END;
    ''');
  }
}
