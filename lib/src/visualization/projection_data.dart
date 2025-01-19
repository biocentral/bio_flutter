import 'dart:math';

extension XYZ on List<double> {
  double get x => this[0];
  double get y => this[1];
  double get z => this[2];
}

class ProjectionData {
  // Usually name of the projection method
  final String identifier;

  // [[x0, y0], [x1, y1] ..]
  final List<List<double>> coordinates;

  // Can be protein ids or interaction ids for example
  final List<String>? pointIDs;

  ProjectionData(this.identifier, this.pointIDs, this.coordinates) {
    if (pointIDs != null) {
      assert(pointIDs!.length == coordinates.length);
    }
  }

  ProjectionData.random(int numberPoints, int dimensions)
      : identifier = "random",
        pointIDs = null,
        coordinates = List.generate(numberPoints, (index) => List.generate(dimensions, (_) => _randomCoordinate()));

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
    return coordinates[index].x;
  }

  double? y({required int index}) {
    if (index < 0 || coordinates.length < index) {
      return null;
    }
    return coordinates[index].y;
  }

  double minX() {
    return coordinates.map((e) => e.x).reduce(min);
  }

  double minY() {
    return coordinates.map((e) => e.y).reduce(min);
  }

  double? minZ() {
    return coordinates.map((e) => e.z).reduce(min);
  }

  double maxX() {
    return coordinates.map((e) => e.x).reduce(max);
  }

  double maxY() {
    return coordinates.map((e) => e.y).reduce(max);
  }

  double maxZ() {
    return coordinates.map((e) => e.z).reduce(max);
  }

  /// Function to sort categories with low number of subcategories to the top of the category selection
  ///
  /// When looking at categories within UMAP plots, usually unique features to every point
  /// (such as usually the sequence for proteins) are not as interesting as commonly shared features (such as their
  /// species of origin). That is why this function sorts the common features to the top and returns the categories
  /// as the [ProjectionCategory] data class in a map with category names as keys.
  static Map<String, ProjectionCategory>? sortedUMAPCategoriesFromPointData(List<Map<String, String>>? pointData) {
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

    Set<ProjectionCategory> projectionCategories = Set.from(uniqueMap.entries
        .where((element) => element.value.isNotEmpty)
        .map((entry) => ProjectionCategory(name: entry.key, subCategoriesWithOccurrences: entry.value)));

    // Sort categories with a lot of values (non-unique categories) down in the list
    List<ProjectionCategory> projectionCategoriesSorted = List<ProjectionCategory>.from(projectionCategories)
      ..sort((category1, category2) =>
          category1.subCategoriesWithOccurrences.length.compareTo(category2.subCategoriesWithOccurrences.length));

    return {for (var element in projectionCategoriesSorted) element.name: element};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectionData &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier &&
          coordinates == other.coordinates &&
          pointIDs == other.pointIDs;

  @override
  int get hashCode => identifier.hashCode ^ coordinates.length.hashCode;
}

class ProjectionCategory {
  final String name;
  final Map<String, int> subCategoriesWithOccurrences;

  ProjectionCategory({required this.name, required this.subCategoriesWithOccurrences});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectionCategory &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          subCategoriesWithOccurrences == other.subCategoriesWithOccurrences;

  @override
  int get hashCode => name.hashCode ^ subCategoriesWithOccurrences.hashCode;
}
