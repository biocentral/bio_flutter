import 'dart:collection';

import 'package:bio_flutter/src/files/bio_file_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:bio_flutter/bio_flutter.dart';

class PpiFastaParser implements BioFileParserString<ProteinProteinInteraction> {
  /// Reads an interaction fasta file in standardized format
  ///
  /// Each interaction is contained twice (in each direction) to store the
  /// sequences in the fasta file.
  ///
  /// Example:
  /// >Q03001 INTERACTOR=Q99IB8-PRO_0000045603 TARGET=1 SET=train
  /// SEQ
  /// >Q99IB8-PRO_0000045603 INTERACTOR=Q03001 TARGET=1 SET=train
  /// QES
  @override
  Future<Map<String, ProteinProteinInteraction>> readFromString(String? content, BioFileHandlerConfig config,
      {String? fileName}) async {
    if (content == null) {
      return {};
    }

    Stopwatch stopwatch = Stopwatch()..start();

    final List<String> fastaLines = content.split("\n").where((line) => line != "" && line != "\n").toList();

    if (!_verifyFastaLines(fastaLines)) {
      throw Exception("Could not verify fasta file!");
    }

    (Map<String, Protein>, Map<String, (bool, String?)>) rawValues =
        await compute(_readRawValuesFromInteractionFasta, (fastaLines, config));

    Map<String, ProteinProteinInteraction> interactions = await compute(_postprocessInteractionLoading, rawValues);

    if (kDebugMode) {
      print("Read interactions in ${stopwatch.elapsed.inMilliseconds}ms");
    }
    return interactions;
  }

  Future<(Map<String, Protein>, Map<String, (bool, String?)>)> _readRawValuesFromInteractionFasta(
  (List<String>, BioFileHandlerConfig) linesConfigTuple) async {
    final List<String> fastaLines = linesConfigTuple.$1;
    final BioFileHandlerConfig config = linesConfigTuple.$2;

    final Map<String, Protein> proteins = {};
    // interactionID => interacting, set
    final Map<String, (bool, String?)> interactionMap = {};

    for (int i = 0; i < fastaLines.length; i += 2) {
      String line = fastaLines[i];

      if (line.characters.first == ">") {
        List<String> values = line.split(" ");
        String id = values[0];
        id = id.contains(">") ? values[0].substring(1) : id;
        Sequence? sequence;
        if (config.checkFileConsistency) {
          // Relatively slow because each amino acid has to be checked
          sequence = Sequence.buildVerifiedFromString(fastaLines[i + 1]);
          if (sequence == null) {
            throw Exception("Could not read sequence for entry with id: $id!");
          }
        } else {
          sequence = AminoAcidSequence(fastaLines[i + 1]);
        }
        Map<String, String> attributes = {};
        // Read custom attributes and interaction attributes
        String? interactionID;
        bool? interacting;
        String? set;
        for (String attribute in values.skip(1)) {
          if (attribute == "") {
            continue;
          }
          List<String> keyValue = attribute.split("=");
          if (!attribute.contains("=") || keyValue.length != 2) {
            throw Exception("Invalid interaction fasta file at line: $i (attribute: $attribute)");
          }
          String key = keyValue[0];
          String value = keyValue[1];
          if (key == "INTERACTOR") {
            interactionID = ProteinProteinInteraction.getInteractionIDFromStrings(id, value);
          } else if (key == "TARGET") {
            interacting = str2bool(value);
          } else if (key == "SET") {
            set = value;
          } else {
            // Other protein attributes
            attributes[key] = value;
          }
        }

        if (interactionID == null || interacting == null) {
          throw Exception("Invalid interaction fasta file at line: $i");
        }
        interactionMap[interactionID] = (interacting, set);

        Protein protein = Protein(id, sequence: sequence).updateFromMap(attributes);

        Protein? existingProteinWithSameID = proteins[id];
        if (existingProteinWithSameID != null) {
          protein = protein.merge(existingProteinWithSameID, failOnConflict: config.failOnConflict);
        }
        proteins[id] = protein;
      } else {
        throw Exception("Invalid interaction fasta file at line: $i");
      }
    }
    return (proteins, interactionMap);
  }

  bool _verifyFastaLines(List<String> fastaLines) {
    return fastaLines.length % 2 == 0;
  }

  Future<Map<String, ProteinProteinInteraction>> _postprocessInteractionLoading(
      (Map<String, Protein>, Map<String, (bool, String?)>) rawValues) async {
    Map<String, ProteinProteinInteraction> interactions = {};
    // id => Protein
    Map<String, Protein> proteins = rawValues.$1;
    // interactionID => interacting, set
    Map<String, (bool, String?)> interactionMap = rawValues.$2;

    // interactionID => skip for flipped interactions for sequence reading
    Set<String> skipInteractions = {};

    int i = 0;
    final int numberReadInteractions = interactionMap.keys.length;
    for (MapEntry<String, (bool, String?)> interactionEntry in interactionMap.entries) {
      if (kDebugMode) {
        print("Processing interaction $i of $numberReadInteractions..");
      }
      i++;
      String interactionID = interactionEntry.key;
      if (skipInteractions.contains(interactionID)) {
        continue;
      }

      (String, String) interactingProteins = ProteinProteinInteraction.getProteinIDsFromInteractionID(interactionID);

      Protein? interactor1 = proteins[interactingProteins.$1];
      Protein? interactor2 = proteins[interactingProteins.$2];
      if (interactor1 == null || interactor2 == null) {
        throw Exception("Missing protein for interaction $interactionID!");
      }
      ProteinProteinInteraction ppi = ProteinProteinInteraction(interactor1, interactor2, interactionEntry.value.$1,
          attributes: CustomAttributes({"SET": interactionEntry.value.$2 ?? ""}));
      interactions[interactionID] = ppi;

      // Check if flipped interaction exists and can be skipped
      String flippedInteractionID = ppi.getFlippedInteractionID();
      (bool, String?)? flippedRecord = interactionMap[flippedInteractionID];
      if (flippedRecord != null) {
        if (interactionEntry.value != flippedRecord) {
          throw Exception("Interaction multiple times present in fasta file, "
              "but attributes are different for interaction id: $interactionID!");
        }
        skipInteractions.add(flippedInteractionID);
      }
    }
    if (kDebugMode) {
      print("Number skipped interactions: ${skipInteractions.length}");
    }
    return interactions;
  }

  @override
  Future<String> convertToString(Map<String, ProteinProteinInteraction> values) async {
    StringBuffer result = StringBuffer();
    HashSet<String> writtenProteins = HashSet();

    int index = 0;
    for (ProteinProteinInteraction interaction in values.values) {
      String targetString = "TARGET=${interaction.interacting ? "1" : "0"}";
      String interactorString = "INTERACTOR=${interaction.interactor2.id}";
      String setValue = interaction.attributes["SET"] ?? "";
      String setString = "SET=$setValue";

      // Interactor 1
      result.writeln("${interaction.interactor1.toFastaHeader()} $interactorString $targetString $setString");
      result.writeln(interaction.interactor1.sequence.seq);
      writtenProteins.add(interaction.interactor1.id);

      // Interactor 2
      // Not necessary to duplicate interaction in fasta file, if values of second interactor are already present
      bool interactor2IDNotWrittenYet = !writtenProteins.contains(interaction.interactor2.id);
      if (interactor2IDNotWrittenYet) {
        String reverseInteractorString = "INTERACTOR=${interaction.interactor1.id}";
        result.writeln("${interaction.interactor2.toFastaHeader()} $reverseInteractorString $targetString $setString");

        result.writeln(interaction.interactor2.sequence.seq);
        writtenProteins.add(interaction.interactor2.id);
      }
      index++;
      if (kDebugMode) {
        print("Wrote interaction $index/${values.length}");
      }
    }
    return result.toString();
  }

  @override
  BioFileFormat getFormat() {
    return FastaFormat();
  }

  @override
  Type getType() {
    return ProteinProteinInteraction;
  }
}
