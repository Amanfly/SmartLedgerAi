import '../../core/currency.dart';

enum CommandIntent {
  addCustomer,
  addCredit,
  addPayment,
  showBalance,
  showReport,
  backup,
  restore,
  unknown,
}

class ParsedCommand {
  const ParsedCommand({
    required this.intent,
    this.customerName,
    this.amountPaise,
    this.description,
  });

  final CommandIntent intent;
  final String? customerName;
  final int? amountPaise;
  final String? description;
}

class IntentParser {
  ParsedCommand parse(String input) {
    final text = input.trim();
    final lower = text.toLowerCase();
    if (lower.isEmpty) return const ParsedCommand(intent: CommandIntent.unknown);
    
    // 1. Core utility commands
    if (lower.contains('backup') || lower.contains('sync') || lower.contains('save to cloud')) {
      return const ParsedCommand(intent: CommandIntent.backup);
    }
    if (lower.contains('restore') || lower.contains('pull') || lower.contains('get from cloud')) {
      return const ParsedCommand(intent: CommandIntent.restore);
    }
    if (lower.contains('report') || lower.contains('summary') || lower.contains('hisab')) {
      return const ParsedCommand(intent: CommandIntent.showReport);
    }

    // 2. Identify Amount
    final amount = _amount(lower);

    // 3. Balance Checks (Hinglish Support)
    if (amount == null && (
        lower.contains('balance') || 
        lower.contains('baki') || 
        lower.contains('dikhao') || 
        lower.contains('kitna') ||
        lower.contains('due')
    )) {
      return ParsedCommand(intent: CommandIntent.showBalance, customerName: _nameAroundBalance(text));
    }

    // 4. Transaction keywords
    final paymentWords = ['paid', 'payment', 'pay', 'jama', 'de diya', 'diya', 'received', 'mile', 'aaye'];
    final creditWords = ['add', 'credit', 'khata', 'account', 'udhar', 'debit', 'le gaya', 'liye', 'becha'];
    
    final isPayment = paymentWords.any(lower.contains);
    final isCredit = creditWords.any(lower.contains);

    // 5. Build transaction command
    if (amount != null) {
      final name = _name(text, lower, amount.raw);
      if (isPayment) {
        return ParsedCommand(
          intent: CommandIntent.addPayment,
          customerName: name,
          amountPaise: rupeesToPaise(amount.value),
          description: _extractDescription(text, lower, name, amount.raw),
        );
      }
      if (isCredit) {
        return ParsedCommand(
          intent: CommandIntent.addCredit,
          customerName: name,
          amountPaise: rupeesToPaise(amount.value),
          description: _extractDescription(text, lower, name, amount.raw),
        );
      }
    }

    // 6. Customer addition
    if (lower.startsWith('add customer ') || lower.startsWith('new customer ')) {
      return ParsedCommand(intent: CommandIntent.addCustomer, customerName: text.substring(13).trim());
    }
    
    return const ParsedCommand(intent: CommandIntent.unknown);
  }

  _Amount? _amount(String lower) {
    // Matches numbers like 500, 500.50, or Rs 500
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(lower);
    if (match == null) return null;
    return _Amount(num.parse(match.group(1)!), match.group(0)!);
  }

  String? _name(String original, String lower, String amountRaw) {
    // Priority 1: "to [Name]" or "from [Name]"
    final pattern = RegExp(r'\b(to|from|of|for|ka|ko|se)\s+([a-zA-Z ]+)', caseSensitive: false).firstMatch(original);
    if (pattern != null) {
      final candidate = pattern.group(2)!.trim().split(' ').first; // Take first word of name
      if (candidate.length > 2) return _title(candidate);
    }

    // Priority 2: Word before keywords like "paid" or "le gaya"
    final words = lower.split(' ');
    final keywords = ['paid', 'pay', 'jama', 'add', 'credit', 'udhar', 'le', 'ne'];
    for (var i = 0; i < words.length; i++) {
      if (keywords.contains(words[i]) && i > 0) {
        final candidate = words[i - 1];
        if (candidate.length > 2 && double.tryParse(candidate) == null) {
          return _title(candidate);
        }
      }
    }

    // Fallback: Just try to find a capitalized word that isn't the amount
    return null;
  }

  String _extractDescription(String original, String lower, String? name, String amountRaw) {
    var cleaned = original
        .replaceAll(RegExp(RegExp.escape(amountRaw)), '')
        .replaceAll(RegExp(r'\b(add|credit|paid|payment|pay|to|from|for|ka|ko|se|me|mein|account|khata|jama|karo|diya|de|mile|aaye|le|gaya|liye|becha|Rs|rupees|rupaye)\b', caseSensitive: false), ' ');
    
    if (name != null) {
      cleaned = cleaned.replaceAll(RegExp(RegExp.escape(name), caseSensitive: false), '');
    }
    
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _nameAroundBalance(String original) {
    final cleaned = original
        .replaceAll(RegExp(r'\b(balance|baki|dikhao|show|ka|ki|account|kitna|hai|due|status)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : _title(cleaned.split(' ').first);
  }

  String _title(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class _Amount {
  const _Amount(this.value, this.raw);
  final num value;
  final String raw;
}
