import 'dart:math';

class UMAPData {
  // Name of the UMAP Data to visualize
  final String identifier;

  // [[x0, y0], [x1, y1] ..]
  final List<(double, double)> coordinates;

  // Can be protein ids or interaction ids for example
  final List<String>? pointIDs;

  UMAPData(this.identifier, this.pointIDs, this.coordinates) {
    if (pointIDs != null) {
      assert(pointIDs!.length == coordinates.length);
    }
  }

  UMAPData.random(int numberPoints)
      : identifier = "random",
        pointIDs = null,
        coordinates = List.generate(numberPoints, (index) => (_randomCoordinate(), _randomCoordinate()));

  /// Create a random coordinate value within range [-20, 20]
  static double _randomCoordinate() {
    const int maxValue = 20;
    Random random = Random();
    int negativeFactor = random.nextBool() ? -1 : 1;
    double coordinate = (1 + random.nextDouble()) * random.nextInt(maxValue);
    return (negativeFactor * coordinate).clamp(-maxValue, maxValue).toDouble();
  }

  double? x({required int index}) {
    if (index < 0 || coordinates.length < index) {
      return null;
    }
    return coordinates[index].$1;
  }

  double? y({required int index}) {
    if (index < 0 || coordinates.length < index) {
      return null;
    }
    return coordinates[index].$2;
  }

  double minX() {
    return coordinates.map((e) => e.$1).reduce(min);
  }

  double minY() {
    return coordinates.map((e) => e.$2).reduce(min);
  }

  double maxX() {
    return coordinates.map((e) => e.$1).reduce(max);
  }

  double maxY() {
    return coordinates.map((e) => e.$2).reduce(max);
  }

  /// Function to sort categories with low number of subcategories to the top of the category selection
  ///
  /// When looking at categories within UMAP plots, usually unique features to every point
  /// (such as usually the sequence for proteins) are not as interesting as commonly shared features (such as their
  /// species of origin). That is why this function sorts the common features to the top and returns the categories
  /// as the [UMAPCategory] data class in a map with category names as keys.
  static Map<String, UMAPCategory>? sortedUMAPCategoriesFromPointData(List<Map<String, String>>? pointData) {
    if (pointData == null || pointData.isEmpty) {
      return null;
    }

    // Iterate over all point data maps
    // category name -> (sub-category: number of occurrences)
    Map<String, Map<String, int>> uniqueMap = {};
    for (Map<String, String> proteinMap in pointData) {
      for (MapEntry<String, String> proteinKeyValue in proteinMap.entries) {
        uniqueMap.putIfAbsent(proteinKeyValue.key, () => {});

        if (proteinKeyValue.value != "") {
          uniqueMap[proteinKeyValue.key]!.putIfAbsent(proteinKeyValue.value, () => 0);

          int count = uniqueMap[proteinKeyValue.key]![proteinKeyValue.value]! + 1;
          uniqueMap[proteinKeyValue.key]![proteinKeyValue.value] = count;
        }
      }
    }

    Set<UMAPCategory> umapCategories = Set.from(uniqueMap.entries
        .where((element) => element.value.isNotEmpty)
        .map((entry) => UMAPCategory(name: entry.key, subCategoriesWithOccurrences: entry.value)));

    // Sort categories with a lot of values (non-unique categories) down in the list
    List<UMAPCategory> umapCategoriesSorted = List<UMAPCategory>.from(umapCategories)
      ..sort((category1, category2) =>
          category1.subCategoriesWithOccurrences.length.compareTo(category2.subCategoriesWithOccurrences.length));

    return {for (var element in umapCategoriesSorted) element.name: element};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UMAPData &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          coordinates == other.coordinates &&
          pointIDs == other.pointIDs;

  @override
  int get hashCode => identifier.hashCode ^ coordinates.length.hashCode;
}

class UMAPCategory {
  final String name;
  final Map<String, int> subCategoriesWithOccurrences;

  UMAPCategory({required this.name, required this.subCategoriesWithOccurrences});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UMAPCategory &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          subCategoriesWithOccurrences == other.subCategoriesWithOccurrences;

  @override
  int get hashCode => name.hashCode ^ subCategoriesWithOccurrences.hashCode;
}
