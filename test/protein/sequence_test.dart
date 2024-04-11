import 'package:bio_flutter/bio_flutter.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sequences', () {
    test('Builds from nucleotide sequence correctly', () async {
      final List<String> validNTSequences = ["CGTCGC", "CGU", "GTTAGTTGGGGGGTGACTGTT"];
      for (String sequenceString in validNTSequences) {
        Sequence? sequence = Sequence.buildVerifiedFromString(sequenceString);
        if (sequence == null) {
          fail("Sequence was not built!");
        }
        expect(sequence.seq, equals(sequenceString.toUpperCase()));
        expect(sequence is NucleotideSequence, equals(true));
        expect(sequence.verify(), equals(true));
      }
    });
    test('Builds from amino acid sequence correctly', () async {
      final List<String> validAASequences = [
        "",
        "P",
        "prtein",
        "aaappp",
        "MAAPVDLELKKAFTELQAKVIDTQQKVKLADIQIEQLNRTKKHAHLTDTEIMTLVDETNMYEGVGRMFILQSKEAIHSQLLEKQKIAEEKIKELEQKKSYLERSVKEAEDNIREMLMARRAQ"
        // uniprot O60925
      ];
      for (String sequenceString in validAASequences) {
        Sequence? sequence = Sequence.buildVerifiedFromString(sequenceString);
        if (sequence == null) {
          fail("Sequence was not built!");
        }
        expect(sequence.seq, equals(sequenceString.toUpperCase()));
        expect(sequence is AminoAcidSequence, equals(true));
        expect(sequence.verify(), equals(true));
      }
    });
    test('Handles ambiguous sequences correctly', () async {
      String sequenceString = "ATAGCGGCAT";
      Sequence? sequence = Sequence.buildVerifiedFromString(sequenceString);
      if (sequence == null) {
        fail("Sequence was not built!");
      }
      expect(sequence is AminoAcidSequence, equals(true));
      expect(sequence.verify(), equals(true));

      sequenceString = "CGT";
      sequence = Sequence.buildVerifiedFromString(sequenceString);
      if (sequence == null) {
        fail("Sequence was not built!");
      }
      expect(sequence is NucleotideSequence, equals(true));
      expect(sequence.verify(), equals(true));

      sequenceString = "A";
      sequence = Sequence.buildVerifiedFromString(sequenceString);
      if (sequence == null) {
        fail("Sequence was not built!");
      }
      expect(sequence is AminoAcidSequence, equals(true));
      expect(sequence.verify(), equals(true));
    });
    test('Handles incorrect sequences correctly', () async {
      final List<String> invalidSequences = ["üäasdsd", "CGUUUUUUUUUUUU-", "PRTEIN!!!", "1234", "&!09aBM"];
      for (String sequenceString in invalidSequences) {
        Sequence? sequence = Sequence.buildVerifiedFromString(sequenceString);
        if (sequence != null) {
          fail("Sequence was built for an invalid string!");
        }
      }
    });
  });
}
