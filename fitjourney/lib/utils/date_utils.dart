// lib/utils/date_utils.dart
String normaliseDate(DateTime date) {
  // Remove time component and timezone
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.toIso8601String().split('T')[0];
}