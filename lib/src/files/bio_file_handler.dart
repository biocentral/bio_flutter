import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:bio_flutter/bio_flutter.dart';
import 'package:universal_io/io.dart' show File;

abstract class BioFileFormatStrategy<T> {
  final String filePath;
  final BioFileHandlerConfig config;

  BioFileFormatStrategy(this.filePath, this.config);

  Future<Map<String, T>> read() async {
    File file = File(filePath);
    final String content = await file.readAsString();
    return readFromString(content);
  }

  Future<Map<String, T>> readFromString(String? content);

  Future<String> convertToString(Map<String, T> values);

  Future<void> write(Map<String, T> values) async {
    String converted = await compute(convertToString, values);
    if(kIsWeb) {
      String fileName = "$T.${filePath.split(".").last}";
      await triggerFileDownload(utf8.encode(converted), fileName);
    } else {
      final File outputFile = File(filePath);
      await outputFile.writeAsString(converted);
    }
  }
}

class BioFileHandlerConfig {
  final bool failOnConflict;
  final bool checkFileConsistency;

  final bool allowParallelExecution;
  final int parallelExecutionThreshold;
  final int numberThreads;

  BioFileHandlerConfig(
      {required this.failOnConflict,
        required this.checkFileConsistency,
        required this.allowParallelExecution,
        required this.parallelExecutionThreshold,
        required this.numberThreads});

  BioFileHandlerConfig.serialDefaultConfig()
      : failOnConflict = false,
        checkFileConsistency = true,
        allowParallelExecution = false,
        parallelExecutionThreshold = 0,
        numberThreads = 1;

  BioFileHandlerConfig.parallelDefaultConfig()
      : failOnConflict = false,
        checkFileConsistency = true,
        allowParallelExecution = true,
        parallelExecutionThreshold = 50000,
        numberThreads = 5;

  BioFileHandlerConfig copyWith(
      {failOnConflict,
        checkFileConsistency,
        removeDuplicates,
        allowParallelExecution,
        parallelExecutionThreshold,
        numberThreads}) {
    return BioFileHandlerConfig(
        failOnConflict: failOnConflict ?? this.failOnConflict,
        checkFileConsistency: checkFileConsistency ?? this.checkFileConsistency,
        allowParallelExecution: allowParallelExecution ?? this.allowParallelExecution,
        parallelExecutionThreshold: parallelExecutionThreshold ?? this.parallelExecutionThreshold,
        numberThreads: numberThreads ?? this.numberThreads);
  }
}

class BioFileHandlerContext<T> {
  final BioFileFormatStrategy<T> _strategy;

  BioFileHandlerContext(this._strategy);

  Future<Map<String, T>> read() async {
    return _strategy.read();
  }

  Future<Map<String, T>> readFromString(String? content) async {
    return _strategy.readFromString(content);
  }

  Future<String> convertToString(Map<String, T> values) async {
    String converted = await compute(_strategy.convertToString, values);
    return converted;
  }

  Future<void> write(Map<String, T> values) async {
    _strategy.write(values);
  }
}

class BioFileHandler<T> {
  BioFileHandlerContext<T> create(String filePath, {BioFileHandlerConfig? config}) {
    String fileEnding = filePath; // Supports plain file formats (fasta) for converting to String only
    if (filePath.contains(".")) {
      fileEnding = filePath.split(".").last;
    }
    SupportedFormat? format = SupportedFormat.values.asNameMap()[fileEnding];
    if (format == null) {
      throw UnimplementedError("File format $fileEnding not supported!");
    }

    BioFileFormatStrategy<T>? bioFileFormatStrategy;
    switch (format) {
      case SupportedFormat.fasta:
        {
          switch (T) {
            case Protein:
              bioFileFormatStrategy =
              ProteinFastaFileFormatHandler(filePath, config ?? BioFileHandlerConfig.serialDefaultConfig())
              as BioFileFormatStrategy<T>;
              break;
            case ProteinProteinInteraction:
              bioFileFormatStrategy =
              InteractionFastaFileFormatHandler(filePath, config ?? BioFileHandlerConfig.serialDefaultConfig())
              as BioFileFormatStrategy<T>;
              break;
          }
        }
      case SupportedFormat.json:
        {
          switch (T) {
            case Embedding:
              bioFileFormatStrategy =
              EmbeddingJsonFileFormatHandler(filePath, config ?? BioFileHandlerConfig.serialDefaultConfig())
              as BioFileFormatStrategy<T>;
              break;
          }
        }
      case SupportedFormat.csv:
        {
          switch (T) {
            case UMAPData:
              bioFileFormatStrategy =
              UMAPCSVFileFormatHandler(filePath, config ?? BioFileHandlerConfig.serialDefaultConfig())
              as BioFileFormatStrategy<T>;
              break;
            case CustomAttributes:
              bioFileFormatStrategy =
              CustomAttributesCSVFileFormatHandler(filePath, config ?? BioFileHandlerConfig.serialDefaultConfig())
              as BioFileFormatStrategy<T>;
              break;
          }
        }
    }
    if (bioFileFormatStrategy != null) {
      return BioFileHandlerContext(bioFileFormatStrategy);
    }
    throw UnimplementedError("The combination of given file format and type is not implemented!");
  }
}

enum SupportedFormat { fasta, json, csv }
