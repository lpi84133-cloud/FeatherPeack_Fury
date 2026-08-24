import 'trip.dart';

enum DistanceUnit {
  kilometres('km', 1),
  miles('mi', 0.621371);

  const DistanceUnit(this.symbol, this.perKilometre);

  final String symbol;
  final double perKilometre;

  String get label => switch (this) {
    DistanceUnit.kilometres => 'Kilometres (km)',
    DistanceUnit.miles => 'Miles (mi)',
  };
}

enum ElevationUnit {
  metres('m', 1),
  feet('ft', 3.28084);

  const ElevationUnit(this.symbol, this.perMetre);

  final String symbol;
  final double perMetre;

  String get label => switch (this) {
    ElevationUnit.metres => 'Metres (m)',
    ElevationUnit.feet => 'Feet (ft)',
  };
}

enum WeightUnit {
  kilograms('kg', 1),
  pounds('lb', 2.20462);

  const WeightUnit(this.symbol, this.perKilogram);

  final String symbol;
  final double perKilogram;

  String get label => switch (this) {
    WeightUnit.kilograms => 'Kilograms (kg)',
    WeightUnit.pounds => 'Pounds (lb)',
  };
}

enum VolumeUnit {
  litres('L', 1),
  usQuarts('qt', 1.05669);

  const VolumeUnit(this.symbol, this.perLitre);

  final String symbol;
  final double perLitre;

  String get label => switch (this) {
    VolumeUnit.litres => 'Litres (L)',
    VolumeUnit.usQuarts => 'US quarts (qt)',
  };
}

enum TimeFormat {
  twentyFour('24-hour'),
  twelve('12-hour');

  const TimeFormat(this.label);

  final String label;
}

/// Local preferences. Values are display-level only: everything is stored in
/// metric internally, so switching units re-renders saved trips rather than
/// rewriting them.
class AppSettings {
  const AppSettings({
    this.distanceUnit = DistanceUnit.kilometres,
    this.elevationUnit = ElevationUnit.metres,
    this.weightUnit = WeightUnit.kilograms,
    this.volumeUnit = VolumeUnit.litres,
    this.timeFormat = TimeFormat.twentyFour,
    this.currencySymbol = r'$',
    this.defaultIntensity = Intensity.moderate,
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.onboardingSeen = false,
  });

  final DistanceUnit distanceUnit;
  final ElevationUnit elevationUnit;
  final WeightUnit weightUnit;
  final VolumeUnit volumeUnit;
  final TimeFormat timeFormat;
  final String currencySymbol;
  final Intensity defaultIntensity;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool onboardingSeen;

  static const currencyChoices = <String>[r'$', '€', '£', '¥', 'CHF', 'kr'];

  AppSettings copyWith({
    DistanceUnit? distanceUnit,
    ElevationUnit? elevationUnit,
    WeightUnit? weightUnit,
    VolumeUnit? volumeUnit,
    TimeFormat? timeFormat,
    String? currencySymbol,
    Intensity? defaultIntensity,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? onboardingSeen,
  }) {
    return AppSettings(
      distanceUnit: distanceUnit ?? this.distanceUnit,
      elevationUnit: elevationUnit ?? this.elevationUnit,
      weightUnit: weightUnit ?? this.weightUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      timeFormat: timeFormat ?? this.timeFormat,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      defaultIntensity: defaultIntensity ?? this.defaultIntensity,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    );
  }

  Map<String, dynamic> toJson() => {
    'distanceUnit': distanceUnit.name,
    'elevationUnit': elevationUnit.name,
    'weightUnit': weightUnit.name,
    'volumeUnit': volumeUnit.name,
    'timeFormat': timeFormat.name,
    'currencySymbol': currencySymbol,
    'defaultIntensity': defaultIntensity.name,
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
    'onboardingSeen': onboardingSeen,
  };

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      return values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    }

    return AppSettings(
      distanceUnit: pick(
        DistanceUnit.values,
        json['distanceUnit'],
        DistanceUnit.kilometres,
      ),
      elevationUnit: pick(
        ElevationUnit.values,
        json['elevationUnit'],
        ElevationUnit.metres,
      ),
      weightUnit: pick(
        WeightUnit.values,
        json['weightUnit'],
        WeightUnit.kilograms,
      ),
      volumeUnit: pick(VolumeUnit.values, json['volumeUnit'], VolumeUnit.litres),
      timeFormat: pick(
        TimeFormat.values,
        json['timeFormat'],
        TimeFormat.twentyFour,
      ),
      currencySymbol: (json['currencySymbol'] as String?) ?? r'$',
      defaultIntensity: pick(
        Intensity.values,
        json['defaultIntensity'],
        Intensity.moderate,
      ),
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
      onboardingSeen: json['onboardingSeen'] as bool? ?? false,
    );
  }
}
