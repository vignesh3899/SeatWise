import 'package:intl/intl.dart';

/// Small presentation helpers kept in one place so formatting stays consistent.
class Formatters {
  Formatters._();

  static final DateFormat _dateTime = DateFormat('MMM d, y • h:mm a');
  static final DateFormat _time = DateFormat('h:mm a');

  static String dateTime(DateTime dt) => _dateTime.format(dt);
  static String time(DateTime dt) => _time.format(dt);

  /// Renders a [Duration] as e.g. "2h 15m" or "45m".
  static String duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours <= 0) return '${minutes}m';
    return '${hours}h ${minutes}m';
  }

  static String distanceKm(double meters) {
    final km = meters / 1000.0;
    if (km < 1) return '${meters.round()} m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  static String temperature(double celsius) => '${celsius.round()}°C';

  /// Formats a 0..100 score with no decimals.
  static String score(double value) => value.round().toString();

  /// Formats a 0..1 confidence as a percentage.
  static String percent(double value) => '${(value * 100).round()}%';
}
