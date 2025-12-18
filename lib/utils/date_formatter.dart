import 'package:intl/intl.dart';

class DateTimeFormatter {
  static String format(DateTime dateTime) {
    final formatter = DateFormat('dd-MM-yyyy HH:mm:ss.SSS');
    return formatter.format(dateTime);
  }
}
