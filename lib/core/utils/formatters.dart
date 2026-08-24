import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy • h:mm a');
  static final DateFormat _time = DateFormat('h:mm a');

  static String currency(num value) => _currency.format(value);

  static String date(DateTime value) => _date.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String time(DateTime value) => _time.format(value);

  static String relative(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(value);
  }

  static String quantity(num value, String unit) {
    final trimmed = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
    return '$trimmed $unit';
  }
}
