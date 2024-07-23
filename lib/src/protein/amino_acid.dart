import 'package:vector_math/vector_math.dart';

/// This class is a draft and work in progress
class AminoAcid {
  final String name;
  final String threeLetterCode;
  final String oneLetterCode;

  final List<String>? nucleotides;
  final List<Atom>? atoms;

  const AminoAcid(
      {required this.name, required this.threeLetterCode, required this.oneLetterCode, this.nucleotides, this.atoms});

  factory AminoAcid.fromLetter(String letter) {
    return _AminoAcidContainer.aminoAcidToNucleotides[letter] ??
        AminoAcid(name: "", threeLetterCode: "", oneLetterCode: letter);
  }

  AminoAcid copyWith(
      {String? name, String? threeLetterCode, String? oneLetterCode, List<String>? nucleotides, List<Atom>? atoms}) {
    return AminoAcid(
        name: name ?? this.name,
        threeLetterCode: threeLetterCode ?? this.threeLetterCode,
        oneLetterCode: oneLetterCode ?? this.oneLetterCode,
        nucleotides: nucleotides ?? this.nucleotides,
        atoms: atoms ?? this.atoms);
  }
}

/// This class is a draft and work in progress
class Atom {
  final String name;
  final String element;

  final Vector3 coordinates;

  final double occupancy;
  final double temperatureFactor;

  Atom(
      {required this.name,
      required this.element,
      required this.coordinates,
      required this.occupancy,
      required this.temperatureFactor});
}

/// This class is a draft and work in progress
class _AminoAcidContainer {
  static const Map<String, AminoAcid> aminoAcidToNucleotides = {
    'A': AminoAcid(
        name: "Alanine", oneLetterCode: "A", threeLetterCode: "Ala", nucleotides: ['GCT', 'GCC', 'GCA', 'GCG']),
    'R': AminoAcid(
        name: "Arginine",
        oneLetterCode: "R",
        threeLetterCode: "Arg",
        nucleotides: ['CGT', 'CGC', 'CGA', 'CGG', 'AGA', 'AGG']),
    'N': AminoAcid(name: "Asparagine", oneLetterCode: "N", threeLetterCode: "Asn", nucleotides: ['AAT', 'AAC']),
    'D': AminoAcid(name: "Aspartic acid", oneLetterCode: "D", threeLetterCode: "Asp", nucleotides: ['GAT', 'GAC']),
    'C': AminoAcid(name: "Cysteine", oneLetterCode: "C", threeLetterCode: "Cys", nucleotides: ['TGT', 'TGC']),
    'Q': AminoAcid(name: "Glutamine", oneLetterCode: "Q", threeLetterCode: "Gln", nucleotides: ['CAA', 'CAG']),
    'E': AminoAcid(name: "Glutamic acid", oneLetterCode: "E", threeLetterCode: "Glu", nucleotides: ['GAA', 'GAG']),
    'G': AminoAcid(
        name: "Glycine", oneLetterCode: "G", threeLetterCode: "Gly", nucleotides: ['GGT', 'GGC', 'GGA', 'GGG']),
    'H': AminoAcid(name: "Histidine", oneLetterCode: "H", threeLetterCode: "His", nucleotides: ['CAT', 'CAC']),
    'I': AminoAcid(name: "Isoleucine", oneLetterCode: "I", threeLetterCode: "Ile", nucleotides: ['ATT', 'ATC', 'ATA']),
    'L': AminoAcid(
        name: "Leucine",
        oneLetterCode: "L",
        threeLetterCode: "Leu",
        nucleotides: ['CTT', 'CTC', 'CTA', 'CTG', 'TTA', 'TTG']),
    'K': AminoAcid(name: "Lysine", oneLetterCode: "K", threeLetterCode: "Lys", nucleotides: ['AAA', 'AAG']),
    'M': AminoAcid(name: "Methionine", oneLetterCode: "M", threeLetterCode: "Met", nucleotides: ['ATG']),
    'F': AminoAcid(name: "Phenylalanine", oneLetterCode: "F", threeLetterCode: "Phe", nucleotides: ['TTT', 'TTC']),
    'P': AminoAcid(
        name: "Proline", oneLetterCode: "P", threeLetterCode: "Pro", nucleotides: ['CCT', 'CCC', 'CCA', 'CCG']),
    'S': AminoAcid(
        name: "Serine",
        oneLetterCode: "S",
        threeLetterCode: "Ser",
        nucleotides: ['TCT', 'TCC', 'TCA', 'TCG', 'AGT', 'AGC']),
    'T': AminoAcid(
        name: "Threonine", oneLetterCode: "T", threeLetterCode: "Thr", nucleotides: ['ACT', 'ACC', 'ACA', 'ACG']),
    'W': AminoAcid(name: "Tryptophan", oneLetterCode: "W", threeLetterCode: "Trp", nucleotides: ['TGG']),
    'Y': AminoAcid(name: "Tyrosine", oneLetterCode: "Y", threeLetterCode: "Tyr", nucleotides: ['TAT', 'TAC']),
    'V': AminoAcid(
        name: "Valine", oneLetterCode: "V", threeLetterCode: "Val", nucleotides: ['GTT', 'GTC', 'GTA', 'GTG']),
    '*': AminoAcid(name: "Stop codon", oneLetterCode: "*", threeLetterCode: "", nucleotides: ['TAA', 'TGA', 'TAG']),
    'X': AminoAcid(name: "Unknown", oneLetterCode: "X", threeLetterCode: "Xaa", nucleotides: ['XXX']),
    // Masked input values
    'U': AminoAcid(name: "Selenocysteine", oneLetterCode: "U", threeLetterCode: "Sec", nucleotides: ['UGA']),
    'Z': AminoAcid(
        name: "Glutamine or Glutamic acid",
        oneLetterCode: "Z",
        threeLetterCode: "Glx",
        nucleotides: ['CAA', 'CAG', 'GAA', 'GAG']),
    // Placeholder for either Q or E
  };
}
