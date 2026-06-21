import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/ledger_repository.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/lock_screen.dart';
import 'features/assistant/assistant_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/ledger/ledger_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';

class SmartLedgerApp extends ConsumerWidget {
  const SmartLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isGuest = ref.watch(guestModeProvider);
    final isSecurityEnabled = ref.watch(isSecurityEnabledProvider);
    final isUnlocked = ref.watch(isUnlockedProvider);

    return MaterialApp(
      title: 'Smart Ledger AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0f766e)),
        useMaterial3: true,
      ),
      home: authState.when(
        data: (user) {
          if (user == null && !isGuest) return const LoginScreen();
          
          return isSecurityEnabled.when(
            data: (enabled) {
              if (enabled && !isUnlocked) {
                return LockScreen(onUnlocked: () => ref.read(isUnlockedProvider.notifier).state = true);
              }
              return const ShellScreen();
            },
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (err, _) => Scaffold(body: Center(child: Text('Security error: $err'))),
          );
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Auth error: $err'))),
      ),
    );
  }
}

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  int _index = 0;

  static const _screens = [
    LedgerScreen(),
    CustomersScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 12),
            Text(_title(_index)),
          ],
        ),
      ),
      body: _screens[_index],
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.summarize_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  String _title(int index) {
    switch (index) {
      case 0: return 'Smart Ledger AI';
      case 1: return 'Customers';
      case 2: return 'Reports';
      case 3: return 'Settings';
      default: return '';
    }
  }

  Widget? _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'assistant',
          onPressed: () => _showAssistant(context),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          mini: true,
          child: const Icon(Icons.smart_toy_outlined),
        ),
        const SizedBox(height: 12),
        if (_index == 0)
          FloatingActionButton.extended(
            heroTag: 'new_entry',
            onPressed: () => LedgerScreen.showEntrySheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('New Entry'),
          ),
        if (_index == 1)
          FloatingActionButton.extended(
            heroTag: 'new_customer',
            onPressed: () => CustomersScreen.addCustomerDialog(context, ref),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('New Customer'),
          ),
      ],
    );
  }

  void _showAssistant(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AssistantBottomSheet(),
    );
  }
}

class AssistantBottomSheet extends StatelessWidget {
  const AssistantBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Expanded(child: AssistantScreen(isBottomSheet: true)),
        ],
      ),
    );
  }
}
