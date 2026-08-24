import '../../core/design/fp_images.dart';

/// Surface underfoot. The factor is the terrain contribution to the difficulty
/// score, from an easy graded path to snow and ice.
enum Terrain {
  grass('Grass & path', 0.30, FpImages.terrainGrass),
  sand('Sand & gravel', 0.60, FpImages.terrainSand),
  rock('Rocky & technical', 0.85, FpImages.terrainRock),
  snow('Snow & ice', 1.00, FpImages.terrainSnow);

  const Terrain(this.label, this.factor, this.image);

  final String label;
  final double factor;
  final String image;
}

/// How hard the group intends to push. Only affects the food reserve.
enum Intensity {
  light('Light', 0.90),
  moderate('Moderate', 1.00),
  high('High', 1.20),
  veryHigh('Very high', 1.35);

  const Intensity(this.label, this.foodFactor);

  final String label;
  final double foodFactor;
}

enum GearCategory {
  food('Food', FpImages.categoryFood),
  clothing('Clothing', FpImages.categoryClothing),
  health('First aid', FpImages.categoryHealth),
  equipment('Equipment', FpImages.gearBackpack),
  electronics('Electronics', FpImages.categoryElectronics),
  other('Other', FpImages.gearCompass);

  const GearCategory(this.label, this.image);

  final String label;
  final String image;
}

enum ExpenseCategory {
  transport('Transport'),
  food('Food'),
  parking('Parking'),
  gear('Gear'),
  other('Other');

  const ExpenseCategory(this.label);

  final String label;
}

class GearItem {
  const GearItem({
    required this.id,
    required this.name,
    required this.category,
    required this.weightKg,
    this.quantity = 1,
  });

  final String id;
  final String name;
  final GearCategory category;
  final double weightKg;
  final int quantity;

  double get totalKg => weightKg * quantity;

  GearItem copyWith({
    String? name,
    GearCategory? category,
    double? weightKg,
    int? quantity,
  }) {
    return GearItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      weightKg: weightKg ?? this.weightKg,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'weightKg': weightKg,
    'quantity': quantity,
  };

  factory GearItem.fromJson(Map<dynamic, dynamic> json) => GearItem(
    id: json['id'] as String,
    name: json['name'] as String,
    category: GearCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => GearCategory.other,
    ),
    weightKg: (json['weightKg'] as num).toDouble(),
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );
}

class Expense {
  const Expense({
    required this.id,
    required this.label,
    required this.category,
    required this.amount,
  });

  final String id;
  final String label;
  final ExpenseCategory category;
  final double amount;

  Expense copyWith({
    String? label,
    ExpenseCategory? category,
    double? amount,
  }) {
    return Expense(
      id: id,
      label: label ?? this.label,
      category: category ?? this.category,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'category': category.name,
    'amount': amount,
  };

  factory Expense.fromJson(Map<dynamic, dynamic> json) => Expense(
    id: json['id'] as String,
    label: json['label'] as String,
    category: ExpenseCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => ExpenseCategory.other,
    ),
    amount: (json['amount'] as num).toDouble(),
  );
}

/// A planned trip. All measurements are stored in metric units; display units
/// are applied at render time.
class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.plannedDate,
    this.distanceKm,
    this.elevationGainM,
    this.movingMinutes,
    this.terrain,
    this.basePackKg,
    this.waterLitres,
    this.people = 1,
    this.intensity = Intensity.moderate,
    this.notes = '',
    this.gear = const [],
    this.expenses = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? plannedDate;

  final double? distanceKm;
  final double? elevationGainM;

  /// Estimated time actually spent moving, excluding overnight stops. Kept
  /// explicit because the food estimate depends on active hours, not calendar
  /// duration.
  final int? movingMinutes;

  final Terrain? terrain;

  /// Weight of the pack itself plus anything the user has not itemised.
  final double? basePackKg;

  final double? waterLitres;
  final int people;
  final Intensity intensity;
  final String notes;
  final List<GearItem> gear;
  final List<Expense> expenses;

  bool get hasRouteBasics => distanceKm != null && movingMinutes != null;

  double get itemisedGearKg =>
      gear.fold<double>(0, (sum, item) => sum + item.totalKg);

  /// Total carried mass: the declared pack weight, every itemised piece of gear
  /// and the water, which is counted at 1 kg per litre.
  double get totalLoadKg =>
      (basePackKg ?? 0) + itemisedGearKg + (waterLitres ?? 0);

  bool get hasLoadData =>
      basePackKg != null || gear.isNotEmpty || waterLitres != null;

  double get expensesTotal =>
      expenses.fold<double>(0, (sum, item) => sum + item.amount);

  double? get movingHours =>
      movingMinutes == null ? null : movingMinutes! / 60.0;

  Trip copyWith({
    String? name,
    DateTime? updatedAt,
    DateTime? plannedDate,
    bool clearPlannedDate = false,
    double? distanceKm,
    double? elevationGainM,
    int? movingMinutes,
    Terrain? terrain,
    double? basePackKg,
    double? waterLitres,
    int? people,
    Intensity? intensity,
    String? notes,
    List<GearItem>? gear,
    List<Expense>? expenses,
  }) {
    return Trip(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      plannedDate: clearPlannedDate ? null : (plannedDate ?? this.plannedDate),
      distanceKm: distanceKm ?? this.distanceKm,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      movingMinutes: movingMinutes ?? this.movingMinutes,
      terrain: terrain ?? this.terrain,
      basePackKg: basePackKg ?? this.basePackKg,
      waterLitres: waterLitres ?? this.waterLitres,
      people: people ?? this.people,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      gear: gear ?? this.gear,
      expenses: expenses ?? this.expenses,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'plannedDate': plannedDate?.toIso8601String(),
    'distanceKm': distanceKm,
    'elevationGainM': elevationGainM,
    'movingMinutes': movingMinutes,
    'terrain': terrain?.name,
    'basePackKg': basePackKg,
    'waterLitres': waterLitres,
    'people': people,
    'intensity': intensity.name,
    'notes': notes,
    'gear': gear.map((item) => item.toJson()).toList(),
    'expenses': expenses.map((item) => item.toJson()).toList(),
  };

  factory Trip.fromJson(Map<dynamic, dynamic> json) {
    DateTime? date(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: date(json['createdAt']) ?? DateTime.now(),
      updatedAt: date(json['updatedAt']) ?? DateTime.now(),
      plannedDate: date(json['plannedDate']),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      elevationGainM: (json['elevationGainM'] as num?)?.toDouble(),
      movingMinutes: (json['movingMinutes'] as num?)?.toInt(),
      terrain: json['terrain'] == null
          ? null
          : Terrain.values.firstWhere(
              (t) => t.name == json['terrain'],
              orElse: () => Terrain.grass,
            ),
      basePackKg: (json['basePackKg'] as num?)?.toDouble(),
      waterLitres: (json['waterLitres'] as num?)?.toDouble(),
      people: (json['people'] as num?)?.toInt() ?? 1,
      intensity: Intensity.values.firstWhere(
        (i) => i.name == json['intensity'],
        orElse: () => Intensity.moderate,
      ),
      notes: json['notes'] as String? ?? '',
      gear: ((json['gear'] as List?) ?? const [])
          .map((raw) => GearItem.fromJson(raw as Map))
          .toList(),
      expenses: ((json['expenses'] as List?) ?? const [])
          .map((raw) => Expense.fromJson(raw as Map))
          .toList(),
    );
  }
}
