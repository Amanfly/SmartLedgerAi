import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/currency.dart';
import '../../data/ledger_repository.dart';
import '../../data/models.dart';
import '../ledger/ledger_screen.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerProvider(customerId));
    final entriesAsync = ref.watch(customerEntriesProvider(customerId));

    return customerAsync.when(
      data: (customerBalance) {
        if (customerBalance == null) {
          return const Scaffold(body: Center(child: Text('Customer not found')));
        }
        
        final balance = customerBalance.balancePaise;
        final balanceColor = balance > 0 ? Colors.red.shade700 : (balance < 0 ? Colors.green.shade700 : Colors.grey);

        return Scaffold(
          appBar: AppBar(
            title: Text(customerBalance.customer.name),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Chip(
                    backgroundColor: balanceColor.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    label: Text(
                      formatMoney(balance.abs()),
                      style: TextStyle(fontWeight: FontWeight.bold, color: balanceColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (customerBalance.customer.phone.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(customerBalance.customer.phone),
                  subtitle: const Text('Mobile'),
                  trailing: IconButton(
                    icon: const Icon(Icons.message_outlined),
                    onPressed: () {
                      // Future: Send WhatsApp/SMS reminder
                    },
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: entriesAsync.when(
                  data: (entries) => entries.isEmpty
                      ? const Center(child: Text('No transactions for this customer.'))
                      : ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final isCredit = entry.type == LedgerEntryType.credit;
                            final color = isCredit ? Colors.red.shade700 : Colors.green.shade700;
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(isCredit ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 18),
                              ),
                              title: Row(
                                children: [
                                  Expanded(child: Text(entry.description.isEmpty ? (isCredit ? 'Credit' : 'Payment') : entry.description)),
                                  IconButton(
                                    icon: Icon(
                                      entry.isSynced ? Icons.cloud_done : Icons.cloud_off_outlined,
                                      size: 14,
                                      color: entry.isSynced ? Colors.blue : Colors.grey,
                                    ),
                                    onPressed: () async {
                                      final repo = ref.read(ledgerRepositoryProvider);
                                      await repo.syncSingleEntry(entry.id);
                                      ref.invalidate(customerEntriesProvider(customerId));
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Sync status (Tap to sync now)',
                                  ),
                                ],
                              ),
                              subtitle: Text(entry.createdAt.toString().split('.')[0]),
                              trailing: Text(
                                formatMoney(entry.amountPaise),
                                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15),
                              ),
                              onTap: () => _showOptions(context, ref, entry, customerBalance.customer),
                            );
                          },
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEntrySheet(context, ref, customerBalance.customer),
            label: const Text('Add Transaction'),
            icon: const Icon(Icons.add),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, LedgerEntry entry, Customer customer) {
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
            onTap: () {
              Navigator.pop(context);
              final text = 'Hello ${customer.name}, a ${entry.type.name} of ${formatMoney(entry.amountPaise)} was added to your ledger. ${entry.description.isNotEmpty ? "Details: ${entry.description}" : ""}\n\nPowered by Smart Ledger AI';
              Share.share(text);
            },
          ),
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
                text = 'Hello ${customer.name},\n\n'
                    'New Credit (Udhar) added: ${formatMoney(entry.amountPaise)}\n'
                    '${entry.description.isNotEmpty ? "Details: ${entry.description}\n" : ""}'
                    'Total Balance Due: ${formatMoney(balance?.balancePaise ?? 0)}\n\n';
                
                if (merchantPhone.isNotEmpty) {
                  text += 'Please pay online to: $merchantPhone\n\n';
                }
              } else {
                text = 'Hello ${customer.name},\n\n'
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
              _showEntrySheet(context, ref, customer, existingEntry: entry);
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
                  content: const Text('Are you sure you want to delete this entry? This cannot be undone.'),
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
                ref.invalidate(customerEntriesProvider(customer.id));
                ref.invalidate(entriesProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _showEntrySheet(BuildContext context, WidgetRef ref, Customer customer, {LedgerEntry? existingEntry}) async {
    // Re-use the sheet logic from LedgerScreen or implement specialized one
    // For now, using the one we optimized in LedgerScreen but customized for this customer
    final amount = TextEditingController(text: existingEntry != null ? (existingEntry.amountPaise / 100).toString() : '');
    final description = TextEditingController(text: existingEntry?.description ?? '');
    var type = existingEntry?.type ?? LedgerEntryType.credit;

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
              Text(existingEntry == null ? 'Transaction for ${customer.name}' : 'Edit Transaction', style: Theme.of(context).textTheme.titleLarge),
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
                onPressed: () async {
                  final parsedAmount = num.tryParse(amount.text);
                  if (parsedAmount == null || parsedAmount <= 0) return;

                  final repo = ref.read(ledgerRepositoryProvider);
                  if (existingEntry == null) {
                    await repo.addEntry(
                      customerId: customer.id,
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
                  ref.invalidate(customerEntriesProvider(customer.id));
                  ref.invalidate(entriesProvider);
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
