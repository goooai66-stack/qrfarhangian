import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'food.dart';
import 'food_search.dart';

/// پایگاه غذای ایرانی: بارگذاری `assets/data/foods.json` و جستجو.
/// کاملاً آفلاین؛ فایل داخل اپ است.
class FoodRepository {
  FoodRepository(List<Food> foods)
    : foods = List.unmodifiable(foods),
      _byId = {for (final f in foods) f.id: f},
      _index = FoodSearchIndex(foods);

  static const assetPath = 'assets/data/foods.json';

  final List<Food> foods;
  final Map<String, Food> _byId;
  final FoodSearchIndex _index;

  Food? byId(String id) => _byId[id];

  List<Food> search(String query, {Map<String, int> frequency = const {}}) =>
      _index.search(query, frequency: frequency);

  factory FoodRepository.fromJsonString(String json) {
    final list = jsonDecode(json) as List;
    final foods = [
      for (final e in list) Food.fromJson((e as Map).cast<String, dynamic>()),
    ];
    final ids = <String>{};
    for (final f in foods) {
      if (!ids.add(f.id)) throw FormatException('food_id تکراری: ${f.id}');
    }
    return FoodRepository(foods);
  }

  static Future<FoodRepository> loadFromAssets() async =>
      FoodRepository.fromJsonString(await rootBundle.loadString(assetPath));
}
