import 'package:bio_flutter/bio_flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class CustomAttributes extends Equatable {
  final Map<String, String> _attributes;

  const CustomAttributes(this._attributes);

  const CustomAttributes.empty() : _attributes = const {};

  CustomAttributes.from(CustomAttributes existing) : _attributes = Map<String, String>.from(existing._attributes);

  CustomAttributes merge(CustomAttributes other, bool failOnConflict) {
    CustomAttributes mergedAttributes = CustomAttributes.from(this);
    if (!failOnConflict) {
      mergedAttributes.addAll(other._attributes);
    } else {
      for (MapEntry<String, String> entry in other._attributes.entries) {
        if (mergedAttributes.containsKey(entry.key)) {
          if (mergedAttributes[entry.key] != "" && entry.value != "") {
            throw Exception("Merging attributes failed due to a conflict in (${entry.key})!");
          }
        }
        mergedAttributes.add(entry.key, entry.value);
      }
    }
    return mergedAttributes;
  }

  CustomAttributes add(String key, String value) {
    if (_attributes.containsKey(key)) {
      throw Exception("Key $key already exists, use update(key, value) instead.");
    }
    return CustomAttributes(Map.from(_attributes)..putIfAbsent(key, () => value));
  }

  CustomAttributes addAll(Map<String, String> other) {
    return CustomAttributes(Map.from(_attributes)..addAll(other));
  }

  CustomAttributes update(String key, String value) {
    if (!_attributes.containsKey(key)) {
      throw Exception("Key $key does not exist, use add(key, value) instead.");
    }
    return CustomAttributes(Map.from(_attributes)..update(key, (_) => value));
  }

  CustomAttributes remove(String key) {
    if (!_attributes.containsKey(key)) {
      return this;
    }
    return CustomAttributes(Map.from(_attributes)..remove(key));
  }

  bool containsKey(String? key) {
    return _attributes.containsKey(key);
  }

  String? getKeyWithIgnoredCase(String? key) {
    if(key == null) {
      return null;
    }
    for (String attributeKey in _attributes.keys) {
      if (attributeKey.toLowerCase() == key.toLowerCase()) {
        return attributeKey;
      }
    }
    return null;
  }

  String? operator [](String? key) {
    return _attributes[key];
  }

  CustomAttributesExtractor<BiologicalEntity>? extract(BiologicalEntity target) {
    switch (target.runtimeType) {
      case Protein:
        return CustomAttributesExtractor.protein(this, target as Protein);
      case ProteinProteinInteraction:
        return CustomAttributesExtractor.interaction(this, target as ProteinProteinInteraction);
    }
    return null;
  }

  Map<String, String> toMap() {
    return Map<String, String>.from(_attributes);
  }

  Set<String> keys() {
    return _attributes.keys.toSet();
  }

  List<String> values() {
    return _attributes.values.toList();
  }

  @override
  List<Object?> get props => [_attributes];
}

class CustomAttributesExtractor<T extends BiologicalEntity> {
  final CustomAttributes _customAttributes;
  final Protein? _protein;
  final ProteinProteinInteraction? _interaction;

  static const List<String> _commonProteinIdentifiers = ["id", "uniprot", "uniprot_id", "uniprot-id", "pdb", "name"];
  static const List<String> _commonSequenceIdentifiers = ["sequence", "seq"];
  static const List<String> _commonTaxonIdentifiers = ["taxonid", "taxid", "taxonomy", "taxon", "OX"];
  static const List<String> _commonFamilyIdentifiers = ["family", "viral_family", "Family virus"];

  static const List<String> _commonConfidenceScoreIdentifiers = [
    "miscore",
    "intact-miscore",
    "virhostnet-miscore",
    "score",
    "confidence",
    "Confidence value(s)",
  ];

  CustomAttributesExtractor._internal(this._customAttributes, this._protein, this._interaction);

  CustomAttributesExtractor.protein(this._customAttributes, this._protein) : _interaction = null;

  CustomAttributesExtractor.interaction(this._customAttributes, this._interaction) : _protein = null;

  B? collect<B>() {
    switch (B) {
      case Protein:
        return _protein!.copyWith(attributes: _customAttributes.addAll(_protein.attributes.toMap())) as B;
      case ProteinProteinInteraction:
        return _interaction!.copyWith(attributes: _customAttributes.addAll(_interaction.attributes.toMap())) as B;
    }
    return null;
  }

  CustomAttributesExtractor? extractAll() {
    if(_protein != null) {
      return this.extractProteinID().extractSequence().extractTaxonomyID().extractFamilyName();
    }
    if(_interaction != null) {
      return this.extractExperimentalConfidenceScore();
    }
    return this;
  }

  CustomAttributesExtractor<T> _extractorFunction<B>(
      List<String> commonKeys, T? Function(B) updateFunction, B? Function(String) valueConversionFunction) {
    CustomAttributes? newAttributes;
    T? updatedEntity;
    String commonIdentifier;

    for (int i = 0; i < commonKeys.length; i++) {
      commonIdentifier = commonKeys[i];
      String? attributesKey = _customAttributes.getKeyWithIgnoredCase(commonIdentifier);

      if (attributesKey != null) {
        B? convertedValue = valueConversionFunction(_customAttributes[attributesKey] ?? "");
        if (convertedValue != null) {
          newAttributes = _customAttributes.remove(attributesKey);
          updatedEntity = updateFunction(convertedValue);

          return CustomAttributesExtractor<T>._internal(
              newAttributes,
              updatedEntity is Protein ? updatedEntity : _protein,
              updatedEntity is ProteinProteinInteraction ? updatedEntity : _interaction);
        }
        break;
      }
    }

    // Nothing extracted
    return CustomAttributesExtractor<T>._internal(_customAttributes, _protein, _interaction);
  }

  CustomAttributesExtractor<T> extractProteinID() {
    return _extractorFunction<String>(
        _commonProteinIdentifiers,
            (extractedID) => _protein?.copyWith(id: extractedID) as T?,
            (rawValue) => rawValue);
  }

  CustomAttributesExtractor<T> extractSequence() {
    return _extractorFunction<Sequence>(
        _commonSequenceIdentifiers,
        (extractedSequence) => _protein?.copyWith(sequence: extractedSequence) as T?,
        (rawValue) => Sequence.buildVerifiedFromString(rawValue));
  }

  CustomAttributesExtractor<T> extractTaxonomyID() {
    return _extractorFunction<int>(
        _commonTaxonIdentifiers,
        (extractedID) => _protein?.copyWith(taxonomy: _protein.taxonomy.copyWith(id: extractedID)) as T?,
        (rawValue) => int.tryParse(rawValue));
  }

  CustomAttributesExtractor<T> extractFamilyName() {
    return _extractorFunction<String>(
        _commonFamilyIdentifiers,
        (extractedFamily) => _protein?.copyWith(taxonomy: _protein.taxonomy.copyWith(family: extractedFamily)) as T?,
        (rawValue) => Taxonomy.isValidFamilyTaxon(rawValue) ? rawValue : null);
  }

  CustomAttributesExtractor<T> extractExperimentalConfidenceScore() {
    return _extractorFunction<double>(
        _commonConfidenceScoreIdentifiers,
        (extractedScore) => _interaction?.copyWith(experimentalConfidenceScore: extractedScore) as T?,
        (rawValue) => double.tryParse(rawValue));
  }
}
