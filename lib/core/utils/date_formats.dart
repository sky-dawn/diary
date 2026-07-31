import 'package:intl/intl.dart';

String formatEntryDate(DateTime date) {
  return DateFormat('yyyy\u5e74M\u6708d\u65e5').format(date);
}

String formatEntryDateShort(DateTime date) {
  return DateFormat('M\u6708d\u65e5').format(date);
}

String formatMonthLabel(DateTime date) {
  return DateFormat('yyyy\u5e74M\u6708').format(date);
}

DateTime normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String storageDate(DateTime date) {
  final DateTime normalized = normalizeDate(date);
  return DateFormat('yyyy-MM-dd').format(normalized);
}
