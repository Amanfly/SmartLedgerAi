import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/currency.dart';
import '../../data/ledger_repository.dart';
import '../../data/models.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final entries = ref.watch(entriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Ledger AI'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(entriesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: dashboard.when(
                  data: (item) => _SummaryGrid(summary: item),
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (error, _) => Text('Dashboard error: $error'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            entries.when(
              data: (items) => items.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No transactions yet.')),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _EntryTile(items[index], ref: ref),
                        childCount: items.length,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (error, _) => SliverToBoxAdapter(child: Text('Ledger error: $error')),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)), // Space for FAB
          ],
        ),
      ),
    );
  }

  static Future<void> showEntrySheet(BuildContext context, WidgetRef ref, {LedgerEntry? existingEntry}) async {
    final amount = TextEditingController(text: existingEntry != null ? (existingEntry.amountPaise / 100).toString() : '');
    final description = TextEditingController(text: existingEntry?.description ?? '');
    var type = existingEntry?.type ?? LedgerEntryType.credit;
    int? selectedCustomerId = existingEntry?.customerId;
    final customers = ref.read(customersProvider).asData?.value ?? [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(existingEntry == null ? 'Add Entry' : 'Edit Entry', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<LedgerEntryType>(
                segments: const [
                  ButtonSegment(value: LedgerEntryType.credit, label: Text('Credit'), icon: Icon(Icons.add_circle_outline)),
                  ButtonSegment(value: LedgerEntryType.payment, label: Text('Payment'), icon: Icon(Icons.remove_circle_outline)),
                ],
                selected: {type},
                onSelectionChanged: (value) => setState(() => type = value.first),
              ),
              const SizedBox(height: 12),
              if (customers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Please add a customer first in the Customers tab.', style: TextStyle(color: Colors.red)),
                )
              else
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Select Customer', border: OutlineInputBorder()),
                  value: selectedCustomerId,
                  items: customers
                      .map((item) => DropdownMenuItem(
                            value: item.customer.id,
                            child: Text('${item.customer.name} (${item.customer.phone.isEmpty ? "No phone" : item.customer.phone})'),
                          ))
                      .toList(),
                  onChanged: existingEntry != null ? null : (value) => setState(() => selectedCustomerId = value),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Product details / Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (selectedCustomerId == null || customers.isEmpty)
                    ? null
                    : () async {
                        final parsedAmount = num.tryParse(amount.text);
                        if (parsedAmount == null || parsedAmount <= 0) return;

                        final repo = ref.read(ledgerRepositoryProvider);
                        if (existingEntry == null) {
                          await repo.addEntry(
                            customerId: selectedCustomerId!,
                            type: type,
                            amountPaise: rupeesToPaise(parsedAmount),
                            description: description.text,
                          );
                        } else {
                          await repo.updateEntry(
                            id: existingEntry.id,
                            type: type,
                            amountPaise: rupeesToPaise(parsedAmount),
                            description: description.text,
                          );
                        }
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(customersProvider);
                        ref.invalidate(entriesProvider);
                        ref.invalidate(customerEntriesProvider(selectedCustomerId!));
                        if (context.mounted) Navigator.pop(context);
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(existingEntry == null ? 'Save Entry' : 'Update Entry'),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _SummaryCard(title: 'Customers', value: summary.customerCount.toString(), icon: Icons.people_alt_outlined, color: Colors.blue),
        _SummaryCard(title: 'Outstanding', value: formatMoney(summary.outstandingPaise), icon: Icons.account_balance_wallet_outlined, color: Colors.orange),
        _SummaryCard(title: 'Today Credit', value: formatMoney(summary.todayCreditPaise), icon: Icons.trending_up, color: Colors.red),
        _SummaryCard(title: 'Today Paid', value: formatMoney(summary.todayPaymentPaise), icon: Icons.payments_outlined, color: Colors.green),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.entry, {required this.ref});
  final LedgerEntry entry;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.type == LedgerEntryType.credit;
    final color = isCredit ? Colors.red.shade700 : Colors.green.shade700;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(isCredit ? Icons.north_east : Icons.south_west, color: color, size: 20),
      ),
      title: Row(
        children: [
          Expanded(child: Text(entry.customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(
            icon: Icon(
              entry.isSynced ? Icons.cloud_done : Icons.cloud_off_outlined,
              size: 16,
              color: entry.isSynced ? Colors.blue : Colors.grey,
            ),
            onPressed: () async {
              final repo = ref.read(ledgerRepositoryProvider);
              await repo.syncSingleEntry(entry.id);
              ref.invalidate(entriesProvider);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Sync status (Tap to sync now)',
          ),
        ],
      ),
      subtitle: Text(entry.description.isEmpty ? entry.type.name : entry.description, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(formatMoney(entry.amountPaise), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      onTap: () => _showOptions(context),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share to WhatsApp'),
            onTap: () async {
              Navigator.pop(context);
              final repo = ref.read(ledgerRepositoryProvider);
              final balance = await repo.getCustomerBalance(entry.customerId);
              final merchantPhone = await repo.getSetting('merchant_phone', '');
              
              String text;
              if (entry.type == LedgerEntryType.credit) {
                text = 'Hello ${entry.customerName},\n\n'
                    'New Credit (Udhar) added: ${formatMoney(entry.amountPaise)}\n'
                    '${entry.description.isNotEmpty ? "Details: ${entry.description}\n" : ""}'
                    'Total Balance Due: ${formatMoney(balance?.balancePaise ?? 0)}\n\n';
                
                if (merchantPhone.isNotEmpty) {
                  text += 'Please pay online to: $merchantPhone\n\n';
                }
              } else {
                text = 'Hello ${entry.customerName},\n\n'
                    'Payment (Jama) Received: ${formatMoney(entry.amountPaise)}\n'
                    '${entry.description.isNotEmpty ? "Details: ${entry.description}\n" : ""}'
                    'Remaining Balance: ${formatMoney(balance?.balancePaise ?? 0)}\n\n'
                    'Thank you for your payment!';
              }
              
              text += '\nPowered by Smart Ledger AI';
              Share.share(text);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit Transaction'),
            onTap: () {
              Navigator.pop(context);
              LedgerScreen.showEntrySheet(context, ref, existingEntry: entry);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete Transaction', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete transaction?'),
                  content: const Text('Are you sure you want to delete this entry?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(ledgerRepositoryProvider).softDeleteEntry(entry.id);
                ref.invalidate(dashboardProvider);
                ref.invalidate(customersProvider);
                ref.invalidate(entriesProvider);
                ref.invalidate(customerEntriesProvider(entry.customerId));
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
