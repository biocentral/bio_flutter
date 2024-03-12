import 'package:bio_flutter/bio_flutter.dart';

class ProteinProteinInteraction {
  static const String interactionIndicator = "&";

  final Protein interactor1;
  final Protein interactor2;

  final bool interacting;

  final double? experimentalConfidenceScore;
  final CustomAttributes attributes;

  ProteinProteinInteraction(this.interactor1, this.interactor2, this.interacting,
      {this.experimentalConfidenceScore, this.attributes = const CustomAttributes.empty()});

  const ProteinProteinInteraction.empty()
      : interactor1 = const Protein.empty(),
        interactor2 = const Protein.empty(),
        interacting = false,
        experimentalConfidenceScore = null,
        attributes = const CustomAttributes.empty();

  static ProteinProteinInteraction? fromMap(Map<String, String> map) {
    // Using ! is safe in this context because null is only returned if type is not found for Extractor
    return CustomAttributes(map).extract(const ProteinProteinInteraction.empty())!.extractAll()!.collect();
  }

  ProteinProteinInteraction updateFromMap(Map<String, String> map) {
    // Using ! is safe in this context because null is only returned if type is not found for Extractor
    return CustomAttributes(map).extract(this)!.extractAll()!.collect();
  }

  ProteinProteinInteraction copyWith({interactor1, interactor2, interacting, experimentalConfidenceScore, attributes}) {
    return ProteinProteinInteraction(
        interactor1 ?? this.interactor1, interactor2 ?? this.interactor2, interacting ?? this.interacting,
        experimentalConfidenceScore: experimentalConfidenceScore ?? this.experimentalConfidenceScore,
        attributes: attributes ?? this.attributes);
  }

  ProteinProteinInteraction merge(ProteinProteinInteraction other, {required bool failOnConflict}) {
    if (getInteractionID() != other.getInteractionID() &&
        getInteractionID() != flipInteractionID(other.getInteractionID())) {
      throw Exception(
          "Merging interactions failed because interaction IDs do not match (${getInteractionID()} != ${other.getInteractionID()})!");
    }
    if (failOnConflict && interacting != other.interacting) {
      throw Exception(
          "Merging interactions failed due to a conflict ($interacting != ${other.interacting} for interacting property)!");
    }
    bool interactingMerged = interacting;

    bool bothExperimentalConfidenceScoresUnavailable =
        experimentalConfidenceScore == null && other.experimentalConfidenceScore == null;
    if (failOnConflict && !bothExperimentalConfidenceScoresUnavailable) {
      if (experimentalConfidenceScore != other.experimentalConfidenceScore) {
        throw Exception("Merging interactions failed due to a conflict in their confidence scores!");
      }
    }
    double? mergedConfidenceScore = experimentalConfidenceScore ?? other.experimentalConfidenceScore;

    CustomAttributes mergedAttributes = attributes.merge(other.attributes, failOnConflict);

    return ProteinProteinInteraction(interactor1, interactor2, interactingMerged,
        experimentalConfidenceScore: mergedConfidenceScore, attributes: mergedAttributes);
  }

  String getInteractionID() {
    return "${interactor1.id}$interactionIndicator${interactor2.id}";
  }

  static String getInteractionIDFromStrings(String protein1, String protein2) {
    return "$protein1$interactionIndicator$protein2";
  }

  String getFlippedInteractionID() {
    return "${interactor2.id}$interactionIndicator${interactor1.id}";
  }

  static String flipInteractionID(String interactionID) {
    if (!interactionID.contains(interactionIndicator)) {
      throw Exception("Invalid interaction ID $interactionID: Does not contain"
          "interaction indicator $interactionIndicator");
    }
    List<String> proteins = interactionID.split(interactionIndicator);
    if (proteins.length != 2) {
      throw Exception("Invalid interaction ID $interactionID: Does not contain"
          "two protein IDs!");
    }
    return "${proteins[1]}$interactionIndicator${proteins[0]}";
  }

  static (String, String) getProteinIDsFromInteractionID(String interactionID) {
    if (!interactionID.contains(interactionIndicator)) {
      throw Exception("Invalid interaction ID $interactionID: Does not contain"
          "interaction indicator $interactionIndicator");
    }
    List<String> proteins = interactionID.split(interactionIndicator);
    if (proteins.length != 2) {
      throw Exception("Invalid interaction ID $interactionID: Does not contain"
          "two protein IDs!");
    }
    return (proteins[0], proteins[1]);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProteinProteinInteraction &&
          runtimeType == other.runtimeType &&
          interacting == other.interacting &&
          (getInteractionID() == other.getInteractionID() ||
              flipInteractionID(getInteractionID()) == flipInteractionID(other.getInteractionID()));

  @override
  int get hashCode => getInteractionID().hashCode;

  @override
  String toString() {
    return 'ProteinProteinInteraction{interactor1: $interactor1, interactor2: $interactor2, interacting: $interacting}';
  }

  Map<String, String> toMap() {
    return {
      "id": getInteractionID(),
      "interactor1": interactor1.id,
      "interactor2": interactor2.id,
      "interacting": interacting.toString(),
      "experimentalConfidenceScore": experimentalConfidenceScore?.toString() ?? "",
    }..addAll(attributes.toMap());
  }
}
