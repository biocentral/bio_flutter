import 'package:flutter/foundation.dart';
import 'package:bio_flutter/bio_flutter.dart';

import 'measurements.dart';

@immutable
class Cell extends BioEntity {
  final String id;
  final CellMeasurements measurements;
  final CellType cellType;
  final EmbeddingManager embeddings;
  final Taxonomy taxonomy;
  final CustomAttributes attributes;

  const Cell(this.id, {
    required this.measurements,
    this.cellType = CellType.unknown,
    this.embeddings = const EmbeddingManager.empty(),
    this.taxonomy = const Taxonomy.unknown(),
    this.attributes = const CustomAttributes.empty()
  });

  double? getMeasurement(String parameter) => measurements.getMeasurement(parameter);
  bool hasMeasurement(String parameter) => measurements.hasMeasurement(parameter);
  List<String> get measurementParameters => measurements.parameters;

  @override
  CustomAttributes getCustomAttributes() {
    return attributes;
  }

  @override
  EmbeddingManager getEmbeddings() {
    return embeddings;
  }

  @override
  String getID() {
    return id;
  }

  @override
  Cell merge(BioEntity other, {required bool failOnConflict}) {
    // TODO: implement merge
    throw UnimplementedError();
  }

  @override
  Map<String, String> toMap() {
    // TODO: implement toMap
    throw UnimplementedError();
  }

}

enum CellType {
  tCell,
  bCell,
  nkCell,
  monocyte,
  neutrophil,
  // Add more cell types...
  unknown
}
