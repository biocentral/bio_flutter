import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bio_flutter/bio_flutter.dart';

void main() {
  group('Protein-Fasta', () {
    String fastaPath = "test/test_files/sequences.fasta";
    File temp = File(fastaPath);
    test(
        'Protein fasta file can be loaded and contains 4 proteins with sequences, '
        'then can be converted back to string', () async {
      try {
        BioFileHandlerContext<Protein>? handler = BioFileHandler<Protein>().create(temp.absolute.path);
        Map<String, Protein> proteins = await handler.read();
        expect(proteins.length, equals(4));
        String fastaString = await handler.convertToString(proteins);
        expect(fastaString.contains(">"), equals(true));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
    });
  });
  group('Interaction-Fasta', () {
    String fastaPath = "test/test_files/interactions_complete.fasta";
    File temp = File(fastaPath);
    test(
        'Interaction fasta file can be loaded and contains 2 interactions and 4 proteins with sequences, '
        'then can be converted back to string', () async {
      Map<String, ProteinProteinInteraction>? interactions;
      try {
        BioFileHandlerContext<ProteinProteinInteraction>? handler =
            BioFileHandler<ProteinProteinInteraction>().create(temp.absolute.path);
        interactions = await handler.read();
        String fastaString = await handler.convertToString(interactions);
        expect(fastaString.contains(">"), equals(true));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
      expect(interactions.length, equals(2));
      for (ProteinProteinInteraction interaction in interactions.values) {
        expect(interaction.interactor1.sequence.isEmpty(), equals(false));
        expect(interaction.interactor1.sequence is AminoAcidSequence, equals(true));
        expect(interaction.interactor1.sequence.verify(), equals(true));

        expect(interaction.interactor2.sequence.isEmpty(), equals(false));
        expect(interaction.interactor2.sequence is AminoAcidSequence, equals(true));
        expect(interaction.interactor2.sequence.verify(), equals(true));

        String interactionID = interaction.getID();
        (String, String) proteinIDs = ProteinProteinInteraction.getProteinIDsFromInteractionID(interactionID);
        expect(interaction.interactor1.id, equals(proteinIDs.$1));
        expect(interaction.interactor2.id, equals(proteinIDs.$2));

        String interactionIDFlipped = ProteinProteinInteraction.flipInteractionID(interactionID);
        (String, String) proteinIDsFlipped =
            ProteinProteinInteraction.getProteinIDsFromInteractionID(interactionIDFlipped);
        expect(interaction.interactor1.id, equals(proteinIDsFlipped.$2));
        expect(interaction.interactor2.id, equals(proteinIDsFlipped.$1));
      }
    });
  });
  group('Embedding-Json', () {
    String jsonPathPerSequence = "test/test_files/embeddings_per_sequence.json";
    String jsonPathPerResidue = "test/test_files/embeddings_per_residue.json";
    File tempSequence = File(jsonPathPerSequence);
    File tempResidue = File(jsonPathPerResidue);
    test('Read per-sequence embeddings', () async {
      try {
        BioFileHandlerContext<Embedding>? handler = BioFileHandler<Embedding>().create(tempSequence.absolute.path);
        Map<String, Embedding> embeddings = await handler.read();
        expect(embeddings.values.length, equals(3));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
    });
    test('Read per-residue embeddings', () async {
      try {
        BioFileHandlerContext<Embedding>? handler = BioFileHandler<Embedding>().create(tempResidue.absolute.path);
        Map<String, Embedding> embeddings = await handler.read();
        expect(embeddings.values.length, equals(3));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
    });
  });
  group('UMAPData-CSV', () {
    String csvPathSingle = "test/test_files/umap_data_single.csv";
    String csvPathMultiple = "test/test_files/umap_data_multiple.csv";
    String csvPathMultipleWithPointIDs = "test/test_files/umap_data_multiple_with_point_ids.csv";
    File tempSingle = File(csvPathSingle);
    File tempMultiple = File(csvPathMultiple);
    File tempMultipleWithPointIDs = File(csvPathMultipleWithPointIDs);
    test('Read file with single umap data', () async {
      try {
        BioFileHandlerContext<UMAPData>? handler = BioFileHandler<UMAPData>().create(tempSingle.absolute.path);
        Map<String, UMAPData> embeddings = await handler.read();
        expect(embeddings.keys.length, equals(1));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
    });
    test('Read file with multiple umap data', () async {
      try {
        BioFileHandlerContext<UMAPData>? handler = BioFileHandler<UMAPData>().create(tempMultiple.absolute.path);
        Map<String, UMAPData> embeddings = await handler.read();
        expect(embeddings.keys.length, equals(3));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
    });
    test('Read file with multiple umap data with point ids', () async {
      try {
        BioFileHandlerContext<UMAPData>? handler =
            BioFileHandler<UMAPData>().create(tempMultipleWithPointIDs.absolute.path);
        Map<String, UMAPData> embeddings = await handler.read();
        expect(embeddings.keys.length, equals(3));
        expect(embeddings.values.last.pointIDs!.length, equals(embeddings.values.last.coordinates.length));
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
    });
  });
  group('CustomAttributes-CSV', () {
    String csvPath = "test/test_files/custom_attributes_for_sequences.csv";
    File tempCSV = File(csvPath);
    test('Read custom attributes file and assign attributes to proteins', () async {
      Map<String, CustomAttributes> attributes = {};
      try {
        BioFileHandlerContext<CustomAttributes>? handler =
            BioFileHandler<CustomAttributes>().create(tempCSV.absolute.path);
        attributes = await handler.read();
      } catch (e) {
        fail("Error was thrown during handler creation! (Error: ${e.toString()})");
      }
      expect(attributes.keys.length, equals(4));
      expect(attributes.values.length, equals(4));
      expect(attributes.values.expand((element) => element.keys()).toSet().length, equals(1));

      // Assign to plain proteins
      Protein protein1 = const Protein("Seq1").updateFromCustomAttributes(attributes["Seq1"]!);
      Protein protein2 = const Protein("Seq2").updateFromCustomAttributes(attributes["Seq2"]!);
      Protein protein3 = const Protein("Seq3").updateFromCustomAttributes(attributes["Seq3"]!);
      Protein protein4 = const Protein("Seq4").updateFromCustomAttributes(attributes["Seq4"]!);
      expect(protein1.attributes["subcellular_location"], equals("nucleus"));
      expect(protein2.attributes["subcellular_location"], equals("membrane"));
      expect(protein3.attributes["subcellular_location"], equals("cytoplasm"));
      expect(protein4.attributes["subcellular_location"], equals("nucleus"));

      Protein protein1WithAttributes = const Protein("Seq1", attributes: CustomAttributes({"test": "test"}))
          .updateFromCustomAttributes(attributes["Seq1"]!);
      expect(protein1WithAttributes.attributes["subcellular_location"], equals("nucleus"));
      expect(protein1WithAttributes.attributes.keys().length, equals(2));
    });
  });
}
