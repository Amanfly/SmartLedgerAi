import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

import 'package:smartledger_ai/src/core/security_service.dart';
import 'app_database.dart';
import 'models.dart';

// Providers
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      sheets.SheetsApi.spreadsheetsScope,
    ],
  );
});

final authStateProvider = StreamProvider<GoogleSignInAccount?>((ref) async* {
  final googleSignIn = ref.watch(googleSignInProvider);
  yield googleSignIn.currentUser;
  try {
    final user = await googleSignIn.signInSilently();
    yield user;
  } catch (e) {
    yield null;
  }
  yield* googleSignIn.onCurrentUserChanged;
});

final guestModeProvider = StateProvider<bool>((ref) => false);
final isUnlockedProvider = StateProvider<bool>((ref) => false);

final isSecurityEnabledProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(securityServiceProvider).isPinSet();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(googleSignInProvider));
});

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  return LedgerRepository(
    ref.watch(databaseProvider),
    ref.watch(backupServiceProvider),
  );
});

final dashboardProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(ledgerRepositoryProvider).dashboard();
});

final customersProvider = FutureProvider<List<CustomerBalance>>((ref) {
  return ref.watch(ledgerRepositoryProvider).customersWithBalances();
});

final customerProvider = FutureProvider.family<CustomerBalance?, int>((ref, customerId) async {
  return await ref.watch(ledgerRepositoryProvider).getCustomerBalance(customerId);
});

final entriesProvider = FutureProvider<List<LedgerEntry>>((ref) {
  return ref.watch(ledgerRepositoryProvider).recentEntries();
});

final customerEntriesProvider = FutureProvider.family<List<LedgerEntry>, int>((ref, customerId) {
  return ref.watch(ledgerRepositoryProvider).customerEntries(customerId);
});

// Classes
class LedgerRepository {
  LedgerRepository(this._db, this._backup);

  final AppDatabase _db;
  final BackupService _backup;

  Future<void> ensureReady() => _db.initialize();

  Future<int> addCustomer(String name, {String phone = '', String notes = ''}) async {
    await ensureReady();
    final id = await _db.customInsert(
      'INSERT INTO customers (name, phone, notes, created_at) VALUES (?, ?, ?, ?)',
      variables: [
        Variable(name.trim()),
        Variable(phone.trim()),
        Variable(notes.trim()),
        Variable(DateTime.now().millisecondsSinceEpoch),
      ],
    );
    _backup.scheduleBackup(this);
    return id;
  }

  Future<int?> findCustomerId(String name, {String? phone}) async {
    await ensureReady();
    if (phone != null && phone.trim().isNotEmpty) {
      final phoneRows = await _db.customSelect(
        'SELECT id FROM customers WHERE phone = ? LIMIT 1',
        variables: [Variable(phone.trim())],
      ).get();
      if (phoneRows.isNotEmpty) return phoneRows.first.read<int>('id');
    }
    final rows = await _db.customSelect(
      'SELECT id FROM customers WHERE lower(name) = lower(?) LIMIT 1',
      variables: [Variable(name.trim())],
    ).get();
    return rows.isEmpty ? null : rows.first.read<int>('id');
  }

  Future<int> findOrCreateCustomer(String name, {String? phone}) async {
    final existingId = await findCustomerId(name, phone: phone);
    if (existingId != null) return existingId;
    return await addCustomer(name, phone: phone ?? '');
  }

  Future<void> addEntry({
    required int customerId,
    required LedgerEntryType type,
    required int amountPaise,
    String description = '',
    DateTime? createdAt,
  }) async {
    await ensureReady();
    await _db.customInsert(
      'INSERT INTO transactions (customer_id, type, amount_paise, description, created_at, is_synced) VALUES (?, ?, ?, ?, ?, 0)',
      variables: [
        Variable(customerId),
        Variable(type.name),
        Variable(amountPaise),
        Variable(description.trim()),
        Variable((createdAt ?? DateTime.now()).millisecondsSinceEpoch),
      ],
    );
    // Trigger auto-backup
    _backup.scheduleBackup(this);
  }

  Future<void> resetDatabase() async {
    await ensureReady();
    await _db.customStatement('DELETE FROM transactions');
    await _db.customStatement('DELETE FROM customers');
    await _db.customStatement('DELETE FROM sqlite_sequence WHERE name IN ("transactions", "customers")');
  }

  Future<void> updateEntry({
    required int id,
    required LedgerEntryType type,
    required int amountPaise,
    String description = '',
  }) async {
    await ensureReady();
    await _db.customUpdate(
      'UPDATE transactions SET type = ?, amount_paise = ?, description = ?, is_synced = 0 WHERE id = ?',
      variables: [
        Variable(type.name),
        Variable(amountPaise),
        Variable(description.trim()),
        Variable(id),
      ],
    );
    // Trigger auto-backup
    _backup.scheduleBackup(this);
  }

  Future<void> markEntriesAsSynced(List<int> ids) async {
    await ensureReady();
    if (ids.isEmpty) return;
    final placeholders = ids.map((_) => '?').join(',');
    await _db.customUpdate(
      'UPDATE transactions SET is_synced = 1 WHERE id IN ($placeholders)',
      variables: ids.map((id) => Variable(id)).toList(),
    );
  }

  Future<void> softDeleteEntry(int id) async {
    await ensureReady();
    await _db.customUpdate(
      'UPDATE transactions SET is_deleted = 1, is_synced = 0 WHERE id = ?',
      variables: [Variable(id)],
    );
    // Trigger auto-backup
    _backup.scheduleBackup(this);
  }

  Future<void> syncSingleEntry(int id) async {
    await _backup.backupToGoogleSheets(this);
  }

  Future<String> getSetting(String key, String defaultValue) async {
    await ensureReady();
    final rows = await _db.customSelect('SELECT value FROM settings WHERE key = ?', variables: [Variable(key)]).get();
    if (rows.isEmpty) return defaultValue;
    return rows.first.read<String>('value');
  }

  Future<void> saveSetting(String key, String value) async {
    await ensureReady();
    await _db.customInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      variables: [Variable(key), Variable(value)],
    );
  }

  Future<List<CustomerBalance>> customersWithBalances() async {
    await ensureReady();
    final rows = await _db.customSelect('''
      SELECT c.id, c.name, c.phone, c.notes, c.created_at,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN (CASE WHEN t.type = 'credit' THEN t.amount_paise ELSE -t.amount_paise END) ELSE 0 END), 0) AS balance
      FROM customers c
      LEFT JOIN transactions t ON t.customer_id = c.id
      GROUP BY c.id
      HAVING balance != 0 OR c.created_at > 0
      ORDER BY c.name COLLATE NOCASE
    ''').get();
    return rows.map(_customerFromRow).toList();
  }

  Future<CustomerBalance?> getCustomerBalance(int customerId) async {
    await ensureReady();
    final rows = await _db.customSelect('''
      SELECT c.id, c.name, c.phone, c.notes, c.created_at,
        COALESCE(SUM(CASE WHEN t.is_deleted = 0 THEN (CASE WHEN t.type = 'credit' THEN t.amount_paise ELSE -t.amount_paise END) ELSE 0 END), 0) AS balance
      FROM customers c
      LEFT JOIN transactions t ON t.customer_id = c.id
      WHERE c.id = ?
      GROUP BY c.id
    ''', variables: [Variable(customerId)]).get();
    return rows.isEmpty ? null : _customerFromRow(rows.first);
  }

  CustomerBalance _customerFromRow(QueryRow row) {
    final customer = Customer(
      id: row.read<int>('id'),
      name: row.read<String>('name'),
      phone: row.read<String>('phone'),
      notes: row.read<String>('notes'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
    );
    return CustomerBalance(customer: customer, balancePaise: row.read<int>('balance'));
  }

  Future<List<LedgerEntry>> recentEntries({int limit = 100}) async {
    await ensureReady();
    final rows = await _db.customSelect('''
      SELECT t.id, t.customer_id, c.name AS customer_name, t.type, t.amount_paise, t.description, t.created_at, t.is_synced
      FROM transactions t
      JOIN customers c ON c.id = t.customer_id
      WHERE t.is_deleted = 0
      ORDER BY t.created_at DESC
      LIMIT ?
    ''', variables: [Variable(limit)]).get();
    return rows.map(_entryFromRow).toList();
  }

  Future<List<LedgerEntry>> customerEntries(int customerId) async {
    await ensureReady();
    final rows = await _db.customSelect('''
      SELECT t.id, t.customer_id, c.name AS customer_name, t.type, t.amount_paise, t.description, t.created_at, t.is_synced
      FROM transactions t
      JOIN customers c ON c.id = t.customer_id
      WHERE t.customer_id = ? AND t.is_deleted = 0
      ORDER BY t.created_at DESC
    ''', variables: [Variable(customerId)]).get();
    return rows.map(_entryFromRow).toList();
  }

  Future<DashboardSummary> dashboard() async {
    await ensureReady();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
    final rows = await _db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM customers) AS customer_count,
        COALESCE((SELECT SUM(CASE WHEN type = 'credit' THEN amount_paise ELSE -amount_paise END) FROM transactions WHERE is_deleted = 0), 0) AS outstanding,
        COALESCE((SELECT SUM(amount_paise) FROM transactions WHERE type = 'credit' AND created_at >= ? AND is_deleted = 0), 0) AS today_credit,
        COALESCE((SELECT SUM(amount_paise) FROM transactions WHERE type = 'payment' AND created_at >= ? AND is_deleted = 0), 0) AS today_payment
    ''', variables: [Variable(start), Variable(start)]).get();
    final row = rows.first;
    return DashboardSummary(
      customerCount: row.read<int>('customer_count'),
      outstandingPaise: row.read<int>('outstanding'),
      todayCreditPaise: row.read<int>('today_credit'),
      todayPaymentPaise: row.read<int>('today_payment'),
    );
  }

  LedgerEntry _entryFromRow(QueryRow row) {
    return LedgerEntry(
      id: row.read<int>('id'),
      customerId: row.read<int>('customer_id'),
      customerName: row.read<String>('customer_name'),
      type: LedgerEntryType.values.byName(row.read<String>('type')),
      amountPaise: row.read<int>('amount_paise'),
      description: row.read<String>('description'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      isSynced: row.read<int>('is_synced') == 1,
    );
  }
}

class BackupService {
  BackupService(this._googleSignIn);
  final GoogleSignIn _googleSignIn;
  Timer? _backupTimer;

  void scheduleBackup(LedgerRepository repo) {
    _backupTimer?.cancel();
    _backupTimer = Timer(const Duration(minutes: 1), () {
      backupToGoogleSheets(repo);
    });
  }

  Future<bool> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> signOut() => _googleSignIn.signOut();

  Future<BackupResult> backupToGoogleSheets(LedgerRepository repo) async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      return const BackupResult.pendingConfiguration('Google account not connected.');
    }

    try {
      final authHeaders = await account.authHeaders;
      final authenticateClient = _GoogleAuthClient(authHeaders);
      final sheetsApi = sheets.SheetsApi(authenticateClient);
      final driveApi = drive.DriveApi(authenticateClient);

      final list = await driveApi.files.list(
        q: "name = 'Smart Ledger Backup' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        spaces: 'drive',
      );

      String spreadsheetId;
      if (list.files != null && list.files!.isNotEmpty) {
        spreadsheetId = list.files!.first.id!;
      } else {
        final spreadsheet = sheets.Spreadsheet(
          properties: sheets.SpreadsheetProperties(title: 'Smart Ledger Backup'),
        );
        final created = await sheetsApi.spreadsheets.create(spreadsheet);
        spreadsheetId = created.spreadsheetId!;
      }

      final entries = await repo.recentEntries(limit: 10000); 
      final customers = await repo.customersWithBalances();
      final customerMap = {for (var c in customers) c.customer.id: c.customer};

      final header = ['Date', 'Customer Name', 'Customer Phone', 'Type', 'Amount', 'Description'];
      final rows = entries.map((e) {
        final c = customerMap[e.customerId];
        return [
          e.createdAt.toIso8601String(),
          e.customerName,
          c?.phone ?? '',
          e.type.name,
          (e.amountPaise / 100).toStringAsFixed(2),
          e.description,
        ];
      }).toList();

      final valueRange = sheets.ValueRange(
        values: [header, ...rows],
      );

      await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        'Sheet1!A1',
        valueInputOption: 'RAW',
      );

      // Mark entries as synced in database
      await repo.markEntriesAsSynced(entries.map((e) => e.id).toList());

      return const BackupResult.ok('Sync to Google Sheets successful.');
    } catch (e) {
      return BackupResult.error('Sheets Sync failed: $e');
    }
  }

  Future<BackupResult> restoreFromGoogleSheets(LedgerRepository repo) async {
    final account = _googleSignIn.currentUser;
    if (account == null) return const BackupResult.pendingConfiguration('Connect Google account.');

    try {
      final authHeaders = await account.authHeaders;
      final authenticateClient = _GoogleAuthClient(authHeaders);
      final sheetsApi = sheets.SheetsApi(authenticateClient);
      final driveApi = drive.DriveApi(authenticateClient);

      final list = await driveApi.files.list(
        q: "name = 'Smart Ledger Backup' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        spaces: 'drive',
      );

      if (list.files == null || list.files!.isEmpty) {
        return const BackupResult.error('Backup sheet not found.');
      }

      final spreadsheetId = list.files!.first.id!;
      final response = await sheetsApi.spreadsheets.values.get(spreadsheetId, 'Sheet1!A:F');
      
      final rows = response.values;
      if (rows == null || rows.length <= 1) {
        return const BackupResult.error('Backup sheet is empty.');
      }

      await repo.resetDatabase();

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 5) continue;

        final dateStr = row[0].toString();
        final name = row[1].toString();
        final phone = row[2].toString();
        final typeName = row[3].toString();
        final amountRupees = double.tryParse(row[4].toString()) ?? 0.0;
        final description = row.length > 5 ? row[5].toString() : '';

        final customerId = await repo.findOrCreateCustomer(name, phone: phone);
        await repo.addEntry(
          customerId: customerId,
          type: LedgerEntryType.values.byName(typeName),
          amountPaise: (amountRupees * 100).round(),
          description: description,
          createdAt: DateTime.tryParse(dateStr),
        );
      }
      
      // Mark all as synced after restore
      final newEntries = await repo.recentEntries(limit: 10000);
      await repo.markEntriesAsSynced(newEntries.map((e) => e.id).toList());

      return const BackupResult.ok('Restore from Sheets successful.');
    } catch (e) {
      return BackupResult.error('Restore failed: $e');
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
