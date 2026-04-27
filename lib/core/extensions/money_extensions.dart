import 'package:intl/intl.dart';

extension MoneyExt on double {
  String toLocaleString() {
    return NumberFormat('#,###', 'fr').format(this).replaceAll(',', '\u00a0');
  }
  String toDA() => '${toLocaleString()} DA';
}

extension IntMoneyExt on int {
  String toLocaleString() {
    return NumberFormat('#,###', 'fr').format(this).replaceAll(',', '\u00a0');
  }
}
