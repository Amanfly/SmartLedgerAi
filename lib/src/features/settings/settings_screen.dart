import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/ledger_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(ledgerRepositoryProvider);
    _phoneController.text = await repo.getSetting('merchant_phone', '');
  }

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final security = ref.watch(securityServiceProvider);
    final isSecurityEnabled = ref.watch(isSecurityEnabledProvider).asData?.value ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                  child: user.photoUrl == null ? Text(user.displayName?[0] ?? 'U') : null,
                ),
                title: Text(user.displayName ?? 'User'),
                subtitle: Text(user.email),
                trailing: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () => _showLogoutDialog(context, backupService),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Profile Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Merchant Phone (for WhatsApp payments)',
              border: OutlineInputBorder(),
              prefixText: '+',
            ),
            keyboardType: TextInputType.phone,
            onChanged: (value) => ref.read(ledgerRepositoryProvider).saveSetting('merchant_phone', value),
          ),
          const SizedBox(height: 24),
          const Text('App Security', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            value: isSecurityEnabled,
            onChanged: (value) => _toggleSecurity(context, ref, value),
            secondary: const Icon(Icons.lock_outline),
            title: const Text('App PIN lock'),
            subtitle: const Text('Require a 4-digit PIN to open the app'),
          ),
          if (isSecurityEnabled)
            FutureBuilder<bool>(
              future: security.canCheckBiometrics(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return FutureBuilder<bool>(
                    future: security.isBiometricEnabled(),
                    builder: (context, bioSnapshot) {
                      return SwitchListTile(
                        value: bioSnapshot.data ?? false,
                        onChanged: (value) async {
                          await security.setBiometricEnabled(value);
                          ref.invalidate(isSecurityEnabledProvider);
                        },
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Fingerprint / Face lock'),
                        subtitle: const Text('Use phone security for faster access'),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          const Divider(),
          const Text('Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Sync to Google Sheets'),
            enabled: user != null,
            onTap: () async {
              final repo = ref.read(ledgerRepositoryProvider);
              final result = await backupService.backupToGoogleSheets(repo);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: const Text('Restore from Sheets'),
            enabled: user != null,
            onTap: () async {
              final confirm = await _showConfirmDialog(
                context,
                'Reload database from Sheets?',
                'This will replace your local data with the data from "Smart Ledger Backup" spreadsheet. Current local data will be lost.',
              );

              if (confirm == true) {
                final repo = ref.read(ledgerRepositoryProvider);
                final result = await backupService.restoreFromGoogleSheets(repo);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message), duration: const Duration(seconds: 5)),
                  );
                  if (result.success) {
                    ref.invalidate(dashboardProvider);
                    ref.invalidate(customersProvider);
                    ref.invalidate(entriesProvider);
                  }
                }
              }
            },
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSecurity(BuildContext context, WidgetRef ref, bool enable) async {
    final security = ref.read(securityServiceProvider);
    if (enable) {
      final pin = await _showPinDialog(context);
      if (pin != null && pin.length == 4) {
        await security.setPin(pin);
        ref.invalidate(isSecurityEnabledProvider);
      }
    } else {
      final confirm = await _showConfirmDialog(context, 'Disable security?', 'Are you sure you want to remove the PIN lock?');
      if (confirm == true) {
        await security.removePin();
        ref.invalidate(isSecurityEnabledProvider);
      }
    }
  }

  Future<String?> _showPinDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set 4-digit PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter 4 digits'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.length == 4) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, BackupService service) async {
    final confirm = await _showConfirmDialog(
      context,
      'Logout?',
      'You will be signed out of your Google account. Cloud sync will be paused.',
    );
    if (confirm == true) {
      await service.signOut();
    }
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(title.contains('Logout') || title.contains('Disable') ? 'Proceed' : 'Confirm', 
                style: TextStyle(color: title.contains('Logout') || title.contains('Disable') ? Colors.red : null)),
          ),
        ],
      ),
    );
  }
}
