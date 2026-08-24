/// The person doing the planning. Body weight is not decoration: the safe pack
/// range and the load warnings are derived from it.
class HikerProfile {
  const HikerProfile({
    this.name = '',
    this.bodyWeightKg = 70,
    this.avatarFileName,
    this.homeArea = '',
  });

  final String name;
  final double bodyWeightKg;

  /// File name inside the app documents directory. Only the name is stored so
  /// the reference survives an iOS container path change between launches.
  final String? avatarFileName;

  final String homeArea;

  static const minBodyWeightKg = 35.0;
  static const maxBodyWeightKg = 160.0;

  /// Widely used day-hiking guidance: a comfortable pack sits between 15% and
  /// 20% of body weight.
  double get comfortableLoadKg => bodyWeightKg * 0.15;
  double get maxRecommendedLoadKg => bodyWeightKg * 0.20;
  double get heavyLoadKg => bodyWeightKg * 0.25;

  bool get hasName => name.trim().isNotEmpty;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  HikerProfile copyWith({
    String? name,
    double? bodyWeightKg,
    String? avatarFileName,
    bool clearAvatar = false,
    String? homeArea,
  }) {
    return HikerProfile(
      name: name ?? this.name,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      avatarFileName: clearAvatar ? null : (avatarFileName ?? this.avatarFileName),
      homeArea: homeArea ?? this.homeArea,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'bodyWeightKg': bodyWeightKg,
    'avatarFileName': avatarFileName,
    'homeArea': homeArea,
  };

  factory HikerProfile.fromJson(Map<dynamic, dynamic> json) => HikerProfile(
    name: json['name'] as String? ?? '',
    bodyWeightKg: (json['bodyWeightKg'] as num?)?.toDouble() ?? 70,
    avatarFileName: json['avatarFileName'] as String?,
    homeArea: json['homeArea'] as String? ?? '',
  );
}
