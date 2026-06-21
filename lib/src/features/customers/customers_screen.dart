import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../data/ledger_repository.dart';
import '../../data/models.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);

    return customers.when(
      data: (items) => items.isEmpty
          ? const Center(child: Text('No customers added yet.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _CustomerTile(item: item);
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Customer error: $error')),
    );
  }

  static Future<void> addCustomerDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name, 
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone, 
              decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final trimmedName = name.text.trim();
              if (trimmedName.isEmpty) return;
              
              final repo = ref.read(ledgerRepositoryProvider);
              final existing = await repo.findCustomerId(trimmedName, phone: phone.text.trim());
              
              if (existing != null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer already exists')),
                  );
                }
                return;
              }
              
              await repo.addCustomer(trimmedName, phone: phone.text.trim());
              ref.invalidate(customersProvider);
              ref.invalidate(dashboardProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _CustomerTile extends StatefulWidget {
  const _CustomerTile({required this.item});
  final CustomerBalance item;

  @override
  State<_CustomerTile> createState() => _CustomerTileState();
}

class _CustomerTileState extends State<_CustomerTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final balanceColor = widget.item.balancePaise > 0 
        ? Colors.red.shade700 
        : (widget.item.balancePaise < 0 ? Colors.green.shade700 : Colors.grey);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(widget.item.customer.name.characters.first.toUpperCase(), 
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
      ),
      title: Text(widget.item.customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(widget.item.customer.phone.isEmpty ? 'No phone' : widget.item.customer.phone),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _revealed ? formatMoney(widget.item.balancePaise.abs()) : '••••', 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: balanceColor, 
                  fontSize: 16,
                  letterSpacing: _revealed ? null : 2,
                ),
              ),
              Text(widget.item.balancePaise >= 0 ? 'Due' : 'Advance', 
                  style: TextStyle(fontSize: 10, color: balanceColor)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _revealed ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 18,
              color: Colors.grey,
            ),
            onPressed: () => setState(() => _revealed = !_revealed),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerDetailScreen(customerId: widget.item.customer.id),
        ),
      ),
    );
  }
}
