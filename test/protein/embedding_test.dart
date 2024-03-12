import 'package:flutter_test/flutter_test.dart';

import 'package:bio_flutter/bio_flutter.dart';

void main() {
  group('Embeddings', () {
    test('Per-residue embeddings can be reduced to per-sequence embeddings with correct dimensionality', () async {
      int embeddingDimension = 21;
      PerResidueEmbedding perResidueEmbedding =
          PerResidueEmbedding.random(numberResidues: 30, embeddingDimension: embeddingDimension);

      PerSequenceEmbedding perSequenceEmbedding = perResidueEmbedding.reduce();
      expect(perSequenceEmbedding.getEmbeddingDimension(), equals(embeddingDimension));

      perResidueEmbedding = PerResidueEmbedding.random(numberResidues: 1, embeddingDimension: embeddingDimension);
      perSequenceEmbedding = perResidueEmbedding.reduce();
      expect(perSequenceEmbedding.getEmbeddingDimension(), equals(embeddingDimension));
    });
  });
}
