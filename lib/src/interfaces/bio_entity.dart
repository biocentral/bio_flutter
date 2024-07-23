import 'package:bio_flutter/bio_flutter.dart';

abstract class BioEntity {

  const BioEntity();

  String getID();

  T updateFromMap<T extends BioEntity>(Map<String, String> map) {
    // Using ! is safe in this context because null is only returned if type is not found for Extractor
    return (CustomAttributes(map).extract(this)!.extractAll()!.collect<T>() ?? this) as T;
  }

  T updateFromCustomAttributes<T extends BioEntity>(CustomAttributes newAttributes) {
    // Using ! is safe in this context because null is only returned if type is not found for Extractor
    return (newAttributes.extract(this)!.extractAll()!.collect<T>() ?? this) as T;
  }

  BioEntity merge(BioEntity other, {required bool failOnConflict});

  CustomAttributes getCustomAttributes();

  Map<String, String> toMap();

  EmbeddingManager getEmbeddings();
}
