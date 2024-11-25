import 'package:flutter/material.dart';

abstract class Sequence {
  static const Map<String, List<String>> aminoAcidToNucleotides = {
    'A': ['GCT', 'GCC', 'GCA', 'GCG'],
    'R': ['CGT', 'CGC', 'CGA', 'CGG', 'AGA', 'AGG'],
    'N': ['AAT', 'AAC'],
    'D': ['GAT', 'GAC'],
    'C': ['TGT', 'TGC'],
    'Q': ['CAA', 'CAG'], // Glutamine
    'E': ['GAA', 'GAG'], // Glutamic acid
    'G': ['GGT', 'GGC', 'GGA', 'GGG'],
    'H': ['CAT', 'CAC'],
    'I': ['ATT', 'ATC', 'ATA'],
    'L': ['CTT', 'CTC', 'CTA', 'CTG', 'TTA', 'TTG'],
    'K': ['AAA', 'AAG'],
    'M': ['ATG'],
    'F': ['TTT', 'TTC'],
    'P': ['CCT', 'CCC', 'CCA', 'CCG'],
    'S': ['TCT', 'TCC', 'TCA', 'TCG', 'AGT', 'AGC'],
    'T': ['ACT', 'ACC', 'ACA', 'ACG'],
    'W': ['TGG'],
    'Y': ['TAT', 'TAC'],
    'V': ['GTT', 'GTC', 'GTA', 'GTG'],
    '*': ['TAA', 'TGA', 'TAG'],
    'X': ['XXX'], // Masked input values
    'U': ['UGA'], // Selenocysteine
    'Z': ['CAA', 'CAG', 'GAA', 'GAG'] // Placeholder for either Q or E
  };

  final String seq;

  Sequence(String seq) : seq = seq.toUpperCase();

  const Sequence.empty() : seq = "";

  /// Returns either a [AminoAcidSequence] or [NucleotideSequence] based on the given [string]
  ///
  /// Three checks are used to make an educated guess about the sequence:
  /// 1. Characters are compared to valid amino acids or nucleotide identifiers
  /// 2. If a sequence contains both T & U, it is not considered a valid nucleotide sequence
  /// 3. Codons of nucleotides are checked against possible existing combinations
  ///
  /// If a string is still ambiguous, it is only determined to be a [NucleotideSequence] if its length
  /// is a multiple of 3
  static Sequence? buildVerifiedFromString(String string) {
    final Set<String> possibleNucleotideCodons = aminoAcidToNucleotides.values.expand((element) => element).toSet();

    bool isAminoAcid = true;
    bool isNucleotide = true;

    bool containsT = false;
    bool containsU = false;

    String codon = "";

    for (String char in string.toUpperCase().characters) {
      if (!aminoAcidToNucleotides.keys.contains(char)) {
        isAminoAcid = false;
      }
      if (!NucleotideSequence.nucleotides.contains(char)) {
        isNucleotide = false;
      }

      codon += char;
      if (codon.length == 3) {
        if (!possibleNucleotideCodons.contains(codon) &&
            !possibleNucleotideCodons.contains(codon.replaceAll("U", "T"))) {
          isNucleotide = false;
        }
        codon = "";
      }

      if (char == "T") {
        containsT = true;
      }
      if (char == "U") {
        containsU = true;
      }
      if (containsT && containsU) {
        isNucleotide = false;
      }

      // Early exit if both are false
      if (!isAminoAcid && !isNucleotide) {
        return null;
      }
    }

    if (isAminoAcid && isNucleotide) {
      if (string.isNotEmpty && string.length % 3 == 0) {
        return NucleotideSequence(string);
      }
    }

    if (isAminoAcid) return AminoAcidSequence(string);
    if (isNucleotide) return NucleotideSequence(string);
    return null;
  }

  bool isEmpty() {
    return seq == "";
  }

  bool verify();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Sequence && runtimeType == other.runtimeType && seq == other.seq;

  @override
  int get hashCode => seq.hashCode;

  @override
  String toString() {
    return seq;
  }
}

class AminoAcidSequence extends Sequence {

  AminoAcidSequence(super.seq);

  const AminoAcidSequence.empty() : super.empty();

  @override
  bool verify() {
    for (String char in seq.characters) {
      if (!Sequence.aminoAcidToNucleotides.keys.contains(char)) {
        return false;
      }
    }
    return true;
  }
}

class NucleotideSequence extends Sequence {
  static const Set<String> nucleotides = {"G", "A", "C", "T", "U"};

  NucleotideSequence(super.sequence);

  const NucleotideSequence.empty() : super.empty();

  @override
  bool verify() {
    bool containsT = false;
    bool containsU = false;
    for (String char in seq.characters) {
      if (!nucleotides.contains(char)) {
        return false;
      }
      if (char == "T") {
        containsT = true;
      }
      if (char == "U") {
        containsU = true;
      }
      // T and U are mutually exclusive (T is for DNA, U for RNA)
      if (containsT && containsU) {
        return false;
      }
    }
    return true;
  }
}
