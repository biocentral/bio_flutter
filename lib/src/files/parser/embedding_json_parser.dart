import 'dart:convert';

import 'package:bio_flutter/bio_flutter.dart';
import 'package:bio_flutter/src/files/bio_file_format.dart';

class EmbeddingJsonParser implements BioFileParserString<Embedding> {
  @override
  Future<Map<String, Embedding>> readFromString(String? content, BioFileHandlerConfig config,
      {String? fileName}) async {
    if (content == null) {
      return {};
    }

    Map<String, Embedding> result = {};
    final Map decodedJsonValues = jsonDecode(content);
    if (decodedJsonValues.keys.length > 1) {
      throw const FormatException("The provided json file does not seem to provide embeddings "
          "in the correct format: More than one embedder provided.");
    }

    final String? embedderName = decodedJsonValues.keys.firstOrNull;
    if (embedderName == null) {
      throw const FormatException("The provided json file does not seem to provide embeddings "
          "in the correct format: No embedder name provided.");
    }

    final Map<String, dynamic> proteinIDsToEmbedding = decodedJsonValues[embedderName]!;
    for (MapEntry<String, dynamic> proteinIDToEmbedding in proteinIDsToEmbedding.entries) {
      dynamic embedding = proteinIDToEmbedding.value;
      if (embedding is List<dynamic> && embedding.first is double) {
        // Per-Sequence Embeddings
        result[proteinIDToEmbedding.key] =
            PerSequenceEmbedding(List<double>.from(embedding), embedderName: embedderName);
      } else if (embedding.first is List<dynamic>) {
        // Per-Residue Embeddings
        result[proteinIDToEmbedding.key] = PerResidueEmbedding(
            List.generate(embedding.length, (index) => List<double>.from(embedding[index])),
            embedderName: embedderName);
      } else {
        throw const FormatException("The provided json file does not seem to provide embeddings in the correct format: "
            "Unknown embeddings type.");
      }
    }
    return result;
  }

  @override
  Future<String> convertToString(Map<String, Embedding> values) async {
    Map<String, Map<String, List>> result = {};
    for (MapEntry<String, Embedding> proteinIDToEmbedding in values.entries) {
      Embedding embedding = proteinIDToEmbedding.value;
      if (!result.containsKey(embedding.embedderName)) {
        result[embedding.embedderName] = {};
      }
      result[embedding.embedderName]![proteinIDToEmbedding.key] = embedding.rawValues();
    }
    return jsonEncode(result);
  }

  @override
  BioFileFormat getFormat() {
    return JSONFormat();
  }

  @override
  Type getType() {
    return Embedding;
  }
}
