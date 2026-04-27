extension DateExt on DateTime {
  String toDisplayDate() {
    return '${day.toString().padLeft(2, "0")}/${month.toString().padLeft(2, "0")}/$year';
  }

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isPast => isBefore(DateTime.now());
}
