import 'package:intl/intl.dart';

import '../../domain/models/app_settings.dart';

/// Turns the metric values kept in storage into the units the user picked.
/// Every screen formats through this class so a unit change is felt everywhere
/// at once.
class FpFormat {
  const FpFormat(this.settings);

  final AppSettings settings;

  String distance(double? km, {int decimals = 1, bool withUnit = true}) {
    if (km == null) return '—';
    final value = km * settings.distanceUnit.perKilometre;
    return _number(value, decimals) +
        (withUnit ? ' ${settings.distanceUnit.symbol}' : '');
  }

  String elevation(double? metres, {bool withUnit = true}) {
    if (metres == null) return '—';
    final value = metres * settings.elevationUnit.perMetre;
    return _number(value, 0) +
        (withUnit ? ' ${settings.elevationUnit.symbol}' : '');
  }

  String weight(double? kg, {int decimals = 1, bool withUnit = true}) {
    if (kg == null) return '—';
    final value = kg * settings.weightUnit.perKilogram;
    return _number(value, decimals) +
        (withUnit ? ' ${settings.weightUnit.symbol}' : '');
  }

  String volume(double? litres, {bool withUnit = true}) {
    if (litres == null) return '—';
    final value = litres * settings.volumeUnit.perLitre;
    return _number(value, 1) +
        (withUnit ? ' ${settings.volumeUnit.symbol}' : '');
  }

  String money(double? amount) {
    if (amount == null) return '—';
    final rounded = amount.roundToDouble() == amount
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return '${settings.currencySymbol}$rounded';
  }

  /// Durations read as "5 h 30 m", which is how hikers talk about them.
  String duration(int? minutes) {
    if (minutes == null) return '—';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest m';
    if (rest == 0) return '$hours h';
    return '$hours h $rest m';
  }

  String date(DateTime? value) {
    if (value == null) return 'No date';
    return DateFormat('MMM d, yyyy').format(value);
  }

  String shortDate(DateTime value) => DateFormat('MMM d').format(value);

  String time(DateTime value) => DateFormat(
    settings.timeFormat == TimeFormat.twentyFour ? 'HH:mm' : 'h:mm a',
  ).format(value);

  String dateTime(DateTime value) => '${date(value)} · ${time(value)}';

  String percent(double fraction) => '${(fraction * 100).round()}%';

  String bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Field labels carry the unit so a form never asks for an ambiguous number.
  String get distanceSymbol => settings.distanceUnit.symbol;
  String get elevationSymbol => settings.elevationUnit.symbol;
  String get weightSymbol => settings.weightUnit.symbol;
  String get volumeSymbol => settings.volumeUnit.symbol;

  double distanceToKm(double value) => value / settings.distanceUnit.perKilometre;
  double elevationToMetres(double value) =>
      value / settings.elevationUnit.perMetre;
  double weightToKg(double value) => value / settings.weightUnit.perKilogram;
  double volumeToLitres(double value) => value / settings.volumeUnit.perLitre;

  double kmToDistance(double km) => km * settings.distanceUnit.perKilometre;
  double metresToElevation(double m) => m * settings.elevationUnit.perMetre;
  double kgToWeight(double kg) => kg * settings.weightUnit.perKilogram;
  double litresToVolume(double l) => l * settings.volumeUnit.perLitre;

  static String _number(double value, int decimals) {
    final text = value.toStringAsFixed(decimals);
    return decimals > 0 && text.endsWith('.0')
        ? text.substring(0, text.length - 2)
        : text;
  }
}
