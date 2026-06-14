import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<int> _pin = [];
  bool _error = false;

  void _handlePress(int digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin.add(digit);
        _error = false;
      });
      if (_pin.length == 4) {
        _verify();
      }
    }
  }

  void _handleDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin.removeLast());
    }
  }

  Future<void> _verify() async {
    final service = ref.read(securityServiceProvider);
    final isValid = await service.verifyPin(_pin.join());
    if (isValid) {
      widget.onUnlocked();
    } else {
      setState(() {
        _pin.clear();
        _error = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  Future<void> _tryBiometrics() async {
    final service = ref.read(securityServiceProvider);
    if (await service.isBiometricEnabled()) {
      final authenticated = await service.authenticateWithBiometrics();
      if (authenticated) {
        widget.onUnlocked();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Color(0xff0f766e)),
            const SizedBox(height: 24),
            Text(
              'Enter PIN',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.all(8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pin.length
                        ? const Color(0xff0f766e)
                        : (_error ? Colors.red.shade100 : Colors.grey.shade300),
                    border: _error && index >= _pin.length
                        ? Border.all(color: Colors.red)
                        : null,
                  ),
                );
              }),
            ),
            if (_error)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Incorrect PIN', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 48),
            _buildKeypad(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row in [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((d) => _buildKey(d)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80, height: 80), // Placeholder for alignment
            _buildKey(0),
            _buildIconButton(Icons.backspace_outlined, _handleDelete),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(int digit) {
    return Container(
      margin: const EdgeInsets.all(12),
      width: 64,
      height: 64,
      child: OutlinedButton(
        onPressed: () => _handlePress(digit),
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        child: Text('$digit', style: const TextStyle(fontSize: 24, color: Colors.black87)),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(12),
      width: 64,
      height: 64,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
