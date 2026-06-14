import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import '../../core/currency.dart';
import '../../data/ledger_repository.dart';
import '../../data/models.dart';
import 'intent_parser.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.isBottomSheet = false});

  final bool isBottomSheet;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  String _result = 'Try: Add groceries 500 to Raj';
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;

      bool available = await _speech.initialize(
        onStatus: (val) {},
        onError: (val) {},
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.all(16),
      shrinkWrap: widget.isBottomSheet,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Command',
                  border: OutlineInputBorder(),
                  hintText: 'Speak or type command...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              color: _isListening ? Colors.red : null,
              tooltip: 'Voice command',
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _run,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Run command'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(_result, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'Add groceries 500 to Raj',
            'Raj paid 200',
            'Raj ka balance dikhao',
            'Monthly report',
          ].map((text) => _Example(text, onPressed: (val) => setState(() => _controller.text = val))).toList(),
        ),
      ],
    );

    if (widget.isBottomSheet) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: body,
    );
  }

  Future<void> _run() async {
    if (_controller.text.isEmpty) return;
    final repo = ref.read(ledgerRepositoryProvider);
    final parsed = IntentParser().parse(_controller.text);
    switch (parsed.intent) {
      case CommandIntent.addCredit:
      case CommandIntent.addPayment:
        final name = parsed.customerName;
        final amount = parsed.amountPaise;
        if (name == null || amount == null) {
          setState(() => _result = 'I need a customer name and amount.');
          return;
        }
        final id = await repo.findCustomerId(name);
        if (id == null) {
          setState(() => _result = 'Customer "$name" not found. Please add them first.');
          return;
        }
        final type = parsed.intent == CommandIntent.addCredit ? LedgerEntryType.credit : LedgerEntryType.payment;
        await repo.addEntry(customerId: id, type: type, amountPaise: amount, description: parsed.description ?? '');
        ref.invalidate(dashboardProvider);
        ref.invalidate(customersProvider);
        ref.invalidate(entriesProvider);
        setState(() => _result = '${type.name} saved for $name: ${formatMoney(amount)}');
        break;
      case CommandIntent.addCustomer:
        final name = parsed.customerName;
        if (name == null || name.isEmpty) return;
        await repo.findOrCreateCustomer(name);
        ref.invalidate(customersProvider);
        setState(() => _result = 'Customer added or already exists: $name');
        break;
      case CommandIntent.showBalance:
        final balances = await repo.customersWithBalances();
        final balance = balances.where((item) => item.customer.name.toLowerCase() == parsed.customerName?.toLowerCase()).firstOrNull;
        setState(() => _result = balance == null ? 'Customer not found.' : '${balance.customer.name}: ${formatMoney(balance.balancePaise)}');
        break;
      case CommandIntent.backup:
        setState(() => _result = 'Auto-backup is enabled. Syncing to Google Sheets...');
        await ref.read(backupServiceProvider).backupToGoogleSheets(repo);
        break;
      case CommandIntent.restore:
        setState(() => _result = 'Opening restore options...');
        break;
      case CommandIntent.showReport:
        setState(() => _result = 'Opening reports summaries...');
        break;
      case CommandIntent.unknown:
        setState(() => _result = 'Command not understood yet.');
        break;
    }
  }
}

class _Example extends StatelessWidget {
  const _Example(this.text, {required this.onPressed});
  final String text;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () => onPressed(text),
    );
  }
}
