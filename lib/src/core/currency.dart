import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0);

String formatMoney(int paise) => _money.format(paise / 100);

int rupeesToPaise(num rupees) => (rupees * 100).round();
