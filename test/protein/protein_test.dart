import 'package:flutter_test/flutter_test.dart';

import 'package:bio_flutter/bio_flutter.dart';

void main() {
  group('Proteins from custom attributes', () {
    test('Can create protein from attributes map', () async {
      Map<String, String> attributes = {
        "id": "Protein1",
        "seq": "PRTEIN",
        "taxon": "9606",
        "family": "Hominidae"
      };
      Protein protein = Protein.fromMap(attributes);
      expect(protein.id, equals("Protein1"));
      expect(protein.sequence.seq, equals("PRTEIN"));
      expect(protein.taxonomy.id, equals(9606));
      expect(protein.taxonomy.family, equals("Hominidae"));
    });
    test('Can create protein from complicated attribute maps', () async {
      Map<String, String> attributes = {
        "iD": "Protein1",
        "SEQuENCE": "PRTEIN",
        "Taxid": "9606",
        "FamIly": "Hominidae",
        "subcellular_location": "nucleus"
      };
      Protein protein = Protein.fromMap(attributes);
      expect(protein.id, equals("Protein1"));
      expect(protein.sequence.seq, equals("PRTEIN"));
      expect(protein.taxonomy.id, equals(9606));
      expect(protein.taxonomy.family, equals("Hominidae"));
      expect(protein.attributes["subcellular_location"], equals("nucleus"));
      expect(protein.attributes.containsKey("SEQuENCE"), equals(false));
    });
    test('Can extract nucleotide sequence correctly', () async {
      Map<String, String> attributes = {
        "iD": "Protein1",
        "SEQuENCE": "CGTCGC",
      };
      Protein protein = Protein.fromMap(attributes);
      expect(protein.id, equals("Protein1"));
      expect(protein.sequence.seq, equals("CGTCGC"));
      expect(protein.sequence is NucleotideSequence, equals(true));
      expect(protein.sequence.verify(), equals(true));
    });
    test('Can extract amino acid sequence correctly', () async {
      Map<String, String> attributes = {
        "iD": "Protein1",
        "SEQuENCE": "PFMKVV",
      };
      Protein protein = Protein.fromMap(attributes);
      expect(protein.id, equals("Protein1"));
      expect(protein.sequence.seq, equals("PFMKVV"));
      expect(protein.sequence is AminoAcidSequence, equals(true));
      expect(protein.sequence.verify(), equals(true));
    });
  });
  group('Merge proteins', () {
    test('Merge proteins without conflicts', () async {
      bool failOnConflict = true;
      Protein protein = const Protein("Seq1", taxonomy: Taxonomy(id: 9606));
      Protein other = const Protein("Seq1", taxonomy: Taxonomy(id: 9606, name: "Homo sapiens", family: "Hominidae"));

      Protein merged = protein.merge(other, failOnConflict: failOnConflict);
      expect(merged.id, equals("Seq1"));
      expect(merged.taxonomy.id, equals(9606));
      expect(merged.taxonomy.name, equals("Homo sapiens"));
      expect(merged.taxonomy.family, equals("Hominidae"));
    });
    test('Merge proteins with conflicts, not failing', () async {
      bool failOnConflict = false;
      Protein protein = Protein("Seq1", sequence: Sequence.buildVerifiedFromString("SEQ")!);
      Protein other = Protein("Seq1", sequence: Sequence.buildVerifiedFromString("SEQSEQ")!);

      Protein merged = protein.merge(other, failOnConflict: failOnConflict);
      expect(merged.id, equals("Seq1"));
      expect(merged.sequence.seq, equals("SEQ"));
    });
    test('Merge proteins with conflicts, failing', () async {
      bool failOnConflict = true;
      Protein protein = Protein("Seq1", sequence: Sequence.buildVerifiedFromString("SEQ")!);
      Protein other = Protein("Seq1", sequence: Sequence.buildVerifiedFromString("SEQSEQ")!);

      expect(() => protein.merge(other, failOnConflict: failOnConflict), throwsException);
    });
  });
}
