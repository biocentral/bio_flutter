import 'package:flutter/foundation.dart';
import 'package:bio_flutter/bio_flutter.dart';

/// Representation of a biological protein
///
/// The [id] is a unique string identifier for the protein, it can for example be a refseq, pdb or uniprot id.
/// The [sequence] can be either amino acids or nucleotides.
/// The [embeddings], i.e. representations of the proteins, are encapsulated in the separate [EmbeddingManager] class.
/// The [taxonomy] represents the most important information to classify the protein's species of origin.
/// The [attributes] are other generic attributes that are not represented by the features above.
@immutable
class Protein extends BiologicalEntity {
  final String id;
  final Sequence sequence;
  final EmbeddingManager embeddings;
  final Taxonomy taxonomy;
  final CustomAttributes attributes;

  const Protein(this.id,
      {this.sequence = const AminoAcidSequence.empty(),
      this.embeddings = const EmbeddingManager.empty(),
      this.taxonomy = const Taxonomy.unknown(),
      this.attributes = const CustomAttributes.empty()});

  const Protein.empty()
      : id = "",
        sequence = const AminoAcidSequence.empty(),
        embeddings = const EmbeddingManager.empty(),
        taxonomy = const Taxonomy.unknown(),
        attributes = const CustomAttributes.empty();

  static Protein fromMap(Map<String, String> map) {
    // Using ! is safe in this context because null is only returned if type is not found for Extractor
    return (CustomAttributes(map).extract(const Protein.empty())!.extractAll()!.collect<Protein>() ??
        const Protein.empty());
  }

  Protein copyWith({id, sequence, embeddings, taxonomy, attributes}) {
    return Protein(id ?? this.id,
        sequence: sequence ?? this.sequence,
        embeddings: embeddings ?? this.embeddings,
        taxonomy: taxonomy ?? this.taxonomy,
        attributes: attributes ?? this.attributes);
  }

  /// Merge the values and attributes of this protein with another protein
  ///
  /// Merging is only allowed if both proteins have the same [id].
  /// If [failOnConflict] is false, the value of this protein will be preferred over the other,
  /// if the value is not empty.
  @override
  Protein merge(BiologicalEntity other, {required bool failOnConflict}) {
    if (other is! Protein) {
      throw Exception("Can only merge two objects of type Protein!");
    }

    if (id != other.id) {
      throw Exception("Merging proteins only allowed if they have the same ID!");
    }

    bool bothSequencesEmpty = sequence.isEmpty() && other.sequence.isEmpty();
    if (failOnConflict && !bothSequencesEmpty) {
      if (sequence != other.sequence) {
        throw Exception("Merging proteins failed due to a conflict in their sequences!");
      }
    }
    Sequence mergedSequence = sequence.isEmpty() ? other.sequence : sequence;

    EmbeddingManager mergedEmbeddings = embeddings.merge(other.embeddings, failOnConflict: failOnConflict);

    Taxonomy mergedTaxonomy = taxonomy.merge(other.taxonomy, failOnConflict: failOnConflict);

    CustomAttributes mergedAttributes = attributes.merge(other.attributes, failOnConflict);

    return Protein(id,
        sequence: mergedSequence, embeddings: mergedEmbeddings, taxonomy: mergedTaxonomy, attributes: mergedAttributes);
  }

  @override
  String toString() {
    return "Protein: $id, Sequence: ${sequence.seq}, Taxonomy: $taxonomy, Attributes: $attributes";
  }

  /// Create a fasta-type header for this protein
  ///
  /// Example:
  ///
  /// \>Seq1 OX=9606 SET=test
  String toFastaHeader() {
    StringBuffer attributesBuffer = StringBuffer();
    for (MapEntry<String, String> entry in attributes.toMap().entries) {
      attributesBuffer.write(" ${entry.key}=${entry.value}");
    }
    if (!taxonomy.isUnknown()) {
      attributesBuffer.write(" OX=${taxonomy.id.toString()}");
    }
    return ">$id${attributesBuffer.toString()}";
  }

  @override
  Map<String, String> toMap() {
    return {
      "id": id,
      "sequence": sequence.seq,
      "taxonomyID": taxonomy.id.toString(),
      "speciesName": taxonomy.name ?? "",
      "familyName": taxonomy.family ?? "",
    }..addAll(attributes.toMap());
  }

  @override
  CustomAttributes getCustomAttributes() {
    return attributes;
  }

  @override
  String getID() {
    return id;
  }

  @override
  EmbeddingManager getEmbeddings() {
    return embeddings;
  }
}
