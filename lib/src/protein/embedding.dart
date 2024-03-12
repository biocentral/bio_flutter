import 'dart:math';

import 'package:equatable/equatable.dart';

enum EmbeddingType { perSequence, perResidue }

class EmbeddingManager {
  final Map<String, Map<EmbeddingType, Embedding>> _embeddings; // Embedder Name -> (Type (Per S/Per R) -> Embedding)

  EmbeddingManager(this._embeddings);

  const EmbeddingManager.empty() : _embeddings = const {};

  EmbeddingManager addEmbedding({required Embedding embedding}) {
    final Map<String, Map<EmbeddingType, Embedding>> embeddingsNew = Map.from(_embeddings);

    if (!embeddingsNew.containsKey(embedding.embedderName)) {
      embeddingsNew[embedding.embedderName] = {};
    }
    EmbeddingType embeddingType = embedding.isReduced() ? EmbeddingType.perSequence : EmbeddingType.perResidue;
    embeddingsNew[embedding.embedderName]![embeddingType] = embedding;

    return EmbeddingManager(embeddingsNew);
  }

  Embedding? getEmbedding(EmbeddingType embeddingType, {String? embedderName}) {
    if (embedderName == null || embedderName == "") {
      return _embeddings.isEmpty
          ? null
          : _embeddings.entries.first.value[embeddingType];
    }
    return _embeddings[embedderName]?[embeddingType];
  }

  PerResidueEmbedding? perResidue({String? embedderName}) {
    return getEmbedding(EmbeddingType.perResidue, embedderName: embedderName) as PerResidueEmbedding?;
  }

  PerSequenceEmbedding? perSequence({String? embedderName}) {
    return getEmbedding(EmbeddingType.perSequence, embedderName: embedderName) as PerSequenceEmbedding?;

  }

  Set<String> getEmbedderNames() {
    return _embeddings.keys.toSet();
  }

  EmbeddingManager merge(EmbeddingManager other, {required bool failOnConflict}) {
    Map<String, Map<EmbeddingType, Embedding>> mergedEmbeddings = {};

    _embeddings.forEach((embedderName, embeddings) {
      mergedEmbeddings[embedderName] = Map.from(embeddings);
    });

    other._embeddings.forEach((embedderName, embeddings) {
      embeddings.forEach((embeddingType, otherEmbedding) {
        if (failOnConflict && mergedEmbeddings[embedderName]?.containsKey(embeddingType) == true) {
          Embedding thisEmbedding = mergedEmbeddings[embedderName]![embeddingType]!;
          if (thisEmbedding != otherEmbedding) {
            throw Exception('Merging embedding managers failed for a conflict in $embedderName with $embeddingType!');
          }
        }
        mergedEmbeddings.putIfAbsent(embedderName, () => {})[embeddingType] = otherEmbedding;
      });
    });

    return EmbeddingManager(mergedEmbeddings);
  }

  bool isEmpty() {
    return _embeddings.isEmpty;
  }

  String information() {
    if (isEmpty()) {
      return "";
    }
    StringBuffer stringBuffer = StringBuffer();
    for (MapEntry<String, Map<EmbeddingType, Embedding>> embedderNameToEmbeddings in _embeddings.entries) {
      String embedderName = embedderNameToEmbeddings.key;
      if (embedderNameToEmbeddings.value.keys.contains(EmbeddingType.perResidue)) {
        stringBuffer.writeln("$embedderName(PerResidue)");
      } else if (embedderNameToEmbeddings.value.keys.contains(EmbeddingType.perSequence)) {
        stringBuffer.writeln("$embedderName(PerSequence)");
      }
    }
    return stringBuffer.toString();
  }
}

abstract class Embedding extends Equatable {
  final String embedderName;

  const Embedding(this.embedderName);

  EmbeddingType getType();

  bool isReduced();

  bool isEmpty();

  int getEmbeddingDimension();

  dynamic rawValues();
}

class PerResidueEmbedding extends Embedding {
  final List<List<double>> _embeddings;

  const PerResidueEmbedding(this._embeddings, {required String embedderName}) : super(embedderName);

  PerResidueEmbedding.empty({required int numberResidues, required int embeddingDimension, String embedderName = ""})
      : _embeddings = List.generate(numberResidues, (index) => List.filled(embeddingDimension, 0.0)),
        super(embedderName);

  PerResidueEmbedding.random({required int numberResidues, required int embeddingDimension})
      : _embeddings =
            List.generate(numberResidues, (index) => List.generate(embeddingDimension, (_) => Random().nextDouble())),
        super("RandomEmbeddings");

  PerSequenceEmbedding reduce() {
    // Calculate mean
    List<double> summedEmbeddingValues = List.filled(getEmbeddingDimension(), 0.0);
    for (List<double> embedding in _embeddings) {
      for (int i = 0; i < embedding.length; i++) {
        summedEmbeddingValues[i] += embedding[i];
      }
    }
    int numberResidues = getNumberResidues();
    return PerSequenceEmbedding(summedEmbeddingValues.map((sum) => sum / numberResidues).toList(),
        embedderName: embedderName);
  }

  @override
  EmbeddingType getType() {
    return EmbeddingType.perResidue;
  }

  int getNumberResidues() {
    return _embeddings.length;
  }

  @override
  int getEmbeddingDimension() {
    return _embeddings.first.length;
  }

  @override
  bool isEmpty() {
    return !_embeddings.any((embedding) => embedding.any((value) => value != 0.0));
  }

  @override
  bool isReduced() {
    return false;
  }

  @override
  List<List<double>> rawValues() {
    return List.from(_embeddings);
  }

  @override
  List<Object?> get props => [embedderName, _embeddings];
}

class PerSequenceEmbedding extends Embedding {
  final List<double> _embedding;

  const PerSequenceEmbedding(this._embedding, {required String embedderName}) : super(embedderName);

  PerSequenceEmbedding.empty({required int embeddingDimension, String embedderName = ""})
      : _embedding = List.filled(embeddingDimension, 0.0),
        super(embedderName);

  PerSequenceEmbedding.random({required int embeddingDimension})
      : _embedding = List.generate(embeddingDimension, (_) => Random().nextDouble()),
        super("RandomEmbeddings");

  @override
  EmbeddingType getType() {
    return EmbeddingType.perSequence;
  }

  @override
  bool isEmpty() {
    return !_embedding.any((value) => value != 0.0);
  }

  @override
  bool isReduced() {
    return true;
  }

  @override
  int getEmbeddingDimension() {
    return _embedding.length;
  }

  @override
  List<double> rawValues() {
    return List.from(_embedding);
  }

  @override
  List<Object?> get props => [embedderName, _embedding];
}
