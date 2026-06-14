enum LedgerEntryType { credit, payment }

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    this.notes = '',
  });

  final int id;
  final String name;
  final String phone;
  final DateTime createdAt;
  final String notes;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.type,
    required this.amountPaise,
    required this.description,
    required this.createdAt,
    this.isSynced = false,
  });

  final int id;
  final int customerId;
  final String customerName;
  final LedgerEntryType type;
  final int amountPaise;
  final String description;
  final DateTime createdAt;
  final bool isSynced;

  int get signedAmountPaise => type == LedgerEntryType.credit ? amountPaise : -amountPaise;
}

class CustomerBalance {
  const CustomerBalance({
    required this.customer,
    required this.balancePaise,
  });

  final Customer customer;
  final int balancePaise;
}

class DashboardSummary {
  const DashboardSummary({
    required this.customerCount,
    required this.outstandingPaise,
    required this.todayCreditPaise,
    required this.todayPaymentPaise,
  });

  final int customerCount;
  final int outstandingPaise;
  final int todayCreditPaise;
  final int todayPaymentPaise;
}

class BackupResult {
  const BackupResult._(this.success, this.message);

  const BackupResult.pendingConfiguration(String message) : this._(false, message);
  const BackupResult.ok(String message) : this._(true, message);
  const BackupResult.error(String message) : this._(false, message);

  final bool success;
  final String message;
}
