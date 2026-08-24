import '../../core/design/fp_images.dart';
import '../models/hiker_profile.dart';
import '../models/trip.dart';

enum LoadSlice {
  water('Water', FpImages.gearBottle),
  food('Food', FpImages.categoryFood),
  clothing('Clothing', FpImages.categoryClothing),
  health('First aid', FpImages.categoryHealth),
  equipment('Equipment', FpImages.gearBackpack),
  electronics('Electronics', FpImages.categoryElectronics),
  other('Other', FpImages.gearCompass),
  pack('Pack & unlisted', FpImages.gearBackpack);

  const LoadSlice(this.label, this.image);

  final String label;
  final String image;

  static LoadSlice fromCategory(GearCategory category) => switch (category) {
    GearCategory.food => food,
    GearCategory.clothing => clothing,
    GearCategory.health => health,
    GearCategory.equipment => equipment,
    GearCategory.electronics => electronics,
    GearCategory.other => other,
  };
}

class LoadPortion {
  const LoadPortion({
    required this.slice,
    required this.weightKg,
    required this.share,
  });

  final LoadSlice slice;
  final double weightKg;

  /// Fraction of the total load, 0..1.
  final double share;
}

/// Feather Load. The point is to surface imbalance, never to forbid a weight.
class LoadResult {
  const LoadResult({
    required this.totalKg,
    required this.portions,
    required this.comfortableKg,
    required this.recommendedMaxKg,
    required this.heavyKg,
    required this.bodySharePercent,
    required this.isItemised,
  });

  final double totalKg;
  final List<LoadPortion> portions;
  final double comfortableKg;
  final double recommendedMaxKg;
  final double heavyKg;

  /// Load as a percentage of the hiker's body weight.
  final double bodySharePercent;

  /// False when nothing has been itemised, so the split is only the declared
  /// pack weight and cannot be analysed for balance.
  final bool isItemised;

  bool get isOverRecommended => totalKg > recommendedMaxKg;
  bool get isHeavy => totalKg > heavyKg;

  /// A single category taking more than this share of the pack is worth a look.
  static const dominantShare = 0.40;

  LoadPortion? get dominantPortion {
    if (!isItemised || portions.isEmpty) return null;
    final biggest = portions.first;
    return biggest.share > dominantShare && biggest.slice != LoadSlice.pack
        ? biggest
        : null;
  }

  static LoadResult of(Trip trip, HikerProfile profile) {
    final weights = <LoadSlice, double>{};

    void add(LoadSlice slice, double value) {
      if (value <= 0) return;
      weights[slice] = (weights[slice] ?? 0) + value;
    }

    // A litre of water is a kilogram carried, so it belongs in the load.
    add(LoadSlice.water, trip.waterLitres ?? 0);
    for (final item in trip.gear) {
      add(LoadSlice.fromCategory(item.category), item.totalKg);
    }
    add(LoadSlice.pack, trip.basePackKg ?? 0);

    final total = weights.values.fold<double>(0, (sum, value) => sum + value);
    final portions =
        weights.entries
            .map(
              (entry) => LoadPortion(
                slice: entry.key,
                weightKg: entry.value,
                share: total == 0 ? 0 : entry.value / total,
              ),
            )
            .toList()
          ..sort((a, b) => b.weightKg.compareTo(a.weightKg));

    return LoadResult(
      totalKg: total,
      portions: portions,
      comfortableKg: profile.comfortableLoadKg,
      recommendedMaxKg: profile.maxRecommendedLoadKg,
      heavyKg: profile.heavyLoadKg,
      bodySharePercent: profile.bodyWeightKg == 0
          ? 0
          : total / profile.bodyWeightKg * 100,
      isItemised: trip.gear.isNotEmpty || (trip.waterLitres ?? 0) > 0,
    );
  }
}
