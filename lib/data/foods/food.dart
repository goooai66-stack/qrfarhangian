import '../../core/nutrition/serving.dart';

/// واحد اندازه‌گیری یک غذا (کفگیر، ملاقه، …). [grams] = null یعنی هنوز
/// با ترازو اندازه‌گیری نشده (بخش ۷-۲).
class FoodUnit {
  const FoodUnit({required this.unit, required this.nameFa, this.grams});

  final String unit;
  final String nameFa;
  final double? grams;

  factory FoodUnit.fromJson(Map<String, dynamic> j) => FoodUnit(
    unit: j['unit'] as String,
    nameFa: j['name_fa'] as String,
    grams: (j['grams'] as num?)?.toDouble(),
  );
}

/// یک رکورد `assets/data/foods.json` (بخش ۷-۱).
class Food {
  const Food({
    required this.id,
    required this.nameFa,
    this.aliases = const [],
    this.nameEn,
    required this.category,
    required this.per100g,
    this.fiberPer100g,
    required this.units,
    required this.defaultUnit,
    this.source,
    this.verified = false,
  });

  final String id;
  final String nameFa;
  final List<String> aliases;
  final String? nameEn;
  final String category;
  final Nutrients per100g;
  final double? fiberPer100g;
  final List<FoodUnit> units;
  final String defaultUnit;
  final String? source;
  final bool verified;

  /// همه‌ی مقادیر در ۱۰۰ گرم از منبع آمده‌اند.
  bool get hasNutrition => per100g.isComplete;

  FoodUnit unitOf(String code) => units.firstWhere(
    (u) => u.unit == code,
    orElse: () => units.firstWhere(
      (u) => u.unit == defaultUnit,
      orElse: () => units.first,
    ),
  );

  /// ارزش غذایی [quantity] از واحد [unit].
  ({double? grams, Nutrients nutrients}) serving(String unit, double quantity) {
    final g = servingGrams(quantity: quantity, unitGrams: unitOf(unit).grams);
    return (grams: g, nutrients: servingNutrients(per100g, g));
  }

  factory Food.fromJson(Map<String, dynamic> j) {
    final p = (j['per_100g'] as Map?)?.cast<String, dynamic>() ?? const {};
    double? n(String k) => (p[k] as num?)?.toDouble();
    final units = [
      for (final u in (j['units'] as List? ?? const []))
        FoodUnit.fromJson((u as Map).cast<String, dynamic>()),
    ];
    if (units.isEmpty) {
      throw FormatException('غذای ${j['id']} هیچ واحدی ندارد');
    }
    return Food(
      id: j['id'] as String,
      nameFa: j['name_fa'] as String,
      aliases: [for (final a in (j['aliases'] as List? ?? const [])) '$a'],
      nameEn: j['name_en'] as String?,
      category: j['category'] as String? ?? 'other',
      per100g: Nutrients(
        kcal: n('kcal'),
        protein: n('protein'),
        carbs: n('carbs'),
        fat: n('fat'),
      ),
      fiberPer100g: n('fiber'),
      units: units,
      defaultUnit: j['default_unit'] as String? ?? units.first.unit,
      source: j['source'] as String?,
      verified: j['verified'] as bool? ?? false,
    );
  }
}
