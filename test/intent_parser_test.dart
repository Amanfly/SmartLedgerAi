import 'package:flutter_test/flutter_test.dart';
import 'package:smartledger_ai/src/features/assistant/intent_parser.dart';

void main() {
  group('IntentParser', () {
    final parser = IntentParser();

    test('parses English credit command', () {
      final command = parser.parse('Add groceries 500 to Raj');
      expect(command.intent, CommandIntent.addCredit);
      expect(command.amountPaise, 50000);
      expect(command.customerName, 'Raj');
    });

    test('parses payment command', () {
      final command = parser.parse('Raj paid 200');
      expect(command.intent, CommandIntent.addPayment);
      expect(command.amountPaise, 20000);
      expect(command.customerName, 'Raj');
    });

    test('parses Hinglish balance command', () {
      final command = parser.parse('Raj ka balance dikhao');
      expect(command.intent, CommandIntent.showBalance);
      expect(command.customerName, 'Raj');
    });
  });
}
