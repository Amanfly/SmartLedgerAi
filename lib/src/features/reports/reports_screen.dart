import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/currency.dart';
import '../../data/ledger_repository.dart';
import 'pdf_statement_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: customers.when(
        data: (items) {
          final outstanding = items.fold<int>(0, (sum, item) => sum + item.balancePaise);
          final positive = items.where((item) => item.balancePaise > 0).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Outstanding balances'),
                subtitle: Text('${positive.length} customers · ${formatMoney(outstanding)}'),
                trailing: IconButton(
                  tooltip: 'Export PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: () async => Printing.sharePdf(
                    bytes: await PdfStatementService().outstandingReport(positive),
                    filename: 'smartledger_outstanding.pdf',
                  ),
                ),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.calendar_today_outlined),
                title: Text('Daily report'),
                subtitle: Text('Available from dashboard totals'),
              ),
              const ListTile(
                leading: Icon(Icons.date_range_outlined),
                title: Text('Weekly and monthly reports'),
                subtitle: Text('Ready for date-range filtering extension'),
              ),
              const ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('Customer statements'),
                subtitle: Text('Generated from each customer ledger'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Report error: $error')),
      ),
    );
  }
}
