import 'package:bio_flutter/bio_flutter.dart';
import 'package:ml_linalg/linalg.dart';

class OneHotEncodingEmbedder {
  static const String name = 'one_hot_encoding';

  static const String _aminoAcids = 'ACDEFGHIKLMNPQRSTVWXY';
  static final String _nucleotides = NucleotideSequence.nucleotides.join();

  final Map<String, int> _indices;
  final int embeddingDimension;
  final Matrix _eyeMatrix;

  OneHotEncodingEmbedder._internal(this._indices, this.embeddingDimension)
      : _eyeMatrix = Matrix.identity(embeddingDimension);

  factory OneHotEncodingEmbedder.aminoAcids() {
    final indicesAA = Map.fromIterables(
      _aminoAcids.split(''),
      List.generate(_aminoAcids.length, (i) => i),
    );
    return OneHotEncodingEmbedder._internal(indicesAA, _aminoAcids.length);
  }

  factory OneHotEncodingEmbedder.nucleotides() {
    final indicesNT = Map.fromIterables(
      _nucleotides.split(''),
      List.generate(_aminoAcids.length, (i) => i),
    );
    return OneHotEncodingEmbedder._internal(indicesNT, _nucleotides.length);
  }

  static OneHotEncodingEmbedder? fromSequenceType(Sequence seq) {
    return switch (seq) {
      final AminoAcidSequence _ => OneHotEncodingEmbedder.aminoAcids(),
      final NucleotideSequence _ => OneHotEncodingEmbedder.nucleotides(),
      _ => null,
    };
  }

  Matrix embedSingle(Sequence sequence) {
    // TODO Test
    final List<int> indices = sequence.seq
        .split('')
        .map((token) => _indices[token] ?? _indices['X'] ?? -1)
        .where((index) => index != -1)
        .toList();

    return Matrix.fromRows(
      indices.map((index) => _eyeMatrix.getRow(index)).toList(),
    );
  }

  Vector reduce(Matrix embedding) {
    return embedding.mean();
  }
}
