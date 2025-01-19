import 'dart:convert';

import 'package:bio_flutter/src/files/parser/cell_fcs_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:bio_flutter/bio_flutter.dart';
import 'package:universal_io/io.dart' show File;

import 'bio_file_format.dart';
import 'parser/custom_attributes_csv_parser.dart';
import 'parser/embedding_json_parser.dart';
import 'parser/interaction_fasta_parser.dart';
import 'parser/protein_fasta_parser.dart';
import 'parser/projection_csv_parser.dart';

final class _BioFileParserFactory<T> {
  final Set<BioFileParser> _availableParsers = {
    ProteinFastaParser(),
    PpiFastaParser(),
    EmbeddingJsonParser(),
    ProjectionCSVParser(),
    CellFCSParser(),
    CustomAttributesCSVParser(),
    CustomAttributesTSVParser(),
  };

  BioFileParser<T> fromTypeAndFormat(BioFileFormat format) {
    for (var parser in _availableParsers) {
      if (parser.getType() == T && parser.getFormat().runtimeType == format.runtimeType) {
        return parser as BioFileParser<T>;
      }
    }
    throw UnimplementedError("No parser available for the combination of ${format.runtimeType} and $T!");
  }
}

abstract class BioFileParser<T> {
  static const String datasetColumnName = "ExtractedDataset";

  const BioFileParser();

  Type getType();

  BioFileFormat getFormat();
}

abstract class BioFileParserString<T> extends BioFileParser<T> {
  Future<Map<String, T>> readFromString(String? content, BioFileHandlerConfig config, {String? fileName});

  Future<String> convertToString(Map<String, T> values);
}

abstract class BioFileParserBinary<T> extends BioFileParser<T> {
  Future<Map<String, T>> readFromBytes(Uint8List? content, BioFileHandlerConfig config, {String? fileName});

  Future<Uint8List> convertToBytes(Map<String, T> values);
}

final class BioFileFormatStrategy<T> {
  final String filePath;
  final BioFileFormat format;
  final BioFileParser<T> parser;
  final BioFileHandlerConfig config;

  BioFileFormatStrategy(this.filePath, this.format, this.parser, this.config);

  Future<Map<String, T>> read() async {
    File file = File(filePath);
    final String fileName = _extractFileName();
    if (format.isBinary()) {
      final Uint8List content = await file.readAsBytes();
      return (parser as BioFileParserBinary<T>).readFromBytes(content, config, fileName: fileName);
    } else {
      final String content = await file.readAsString();
      return (parser as BioFileParserString<T>).readFromString(content, config, fileName: fileName);
    }
  }

  Future<void> write(Map<String, T> values) async {
    if (format.isBinary()) {
      await _writeBytes(values);
    } else {
      await _writeString(values);
    }
  }

  Future<void> _writeString(Map<String, T> values) async {
    String converted = await compute((parser as BioFileParserString<T>).convertToString, values);
    if (kIsWeb) {
      String fileName = "$T.${filePath.split(".").last}";
      await triggerFileDownload(utf8.encode(converted), fileName);
    } else {
      final File outputFile = File(filePath);
      await outputFile.writeAsString(converted);
    }
  }

  Future<void> _writeBytes(Map<String, T> values) async {
    final Uint8List converted = await compute((parser as BioFileParserBinary<T>).convertToBytes, values);
    if (kIsWeb) {
      String fileName = "$T.${filePath.split(".").last}";
      await triggerFileDownload(converted, fileName);
    } else {
      final File outputFile = File(filePath);
      await outputFile.writeAsBytes(converted);
    }
  }

  String _extractFileName() {
    return filePath.split("/").last.split(".").first;
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
  final String filePath;
  final BioFileFormat format;
  final BioFileParser<T> parser;
  final BioFileHandlerConfig config;

  BioFileHandlerContext(this.filePath, this.format, this.parser, this.config);

  Future<Map<String, T>> read() async {
    File file = File(filePath);
    final String fileName = _extractFileName();
    if (format.isBinary()) {
      final Uint8List content = await file.readAsBytes();
      return (parser as BioFileParserBinary<T>).readFromBytes(content, config, fileName: fileName);
    } else {
      final String content = await file.readAsString();
      return (parser as BioFileParserString<T>).readFromString(content, config, fileName: fileName);
    }
  }

  Future<Map<String, T>?> readFromString(String? content, {String? fileName}) async {
    if (format.isBinary()) {
      return null;
    }
    final Map<String, T> result =
        await (parser as BioFileParserString<T>).readFromString(content, config, fileName: fileName);
    return result;
  }

  Future<String?> convertToString(Map<String, T> values) async {
    if (format.isBinary()) {
      return null;
    }
    String converted = await compute((parser as BioFileParserString<T>).convertToString, values);
    return converted;
  }

  Future<void> write(Map<String, T> values) async {
    if (format.isBinary()) {
      await _writeBytes(values);
    } else {
      await _writeString(values);
    }
  }

  Future<void> _writeString(Map<String, T> values) async {
    String converted = await compute((parser as BioFileParserString<T>).convertToString, values);
    if (kIsWeb) {
      String fileName = "$T.${filePath.split(".").last}";
      await triggerFileDownload(utf8.encode(converted), fileName);
    } else {
      final File outputFile = File(filePath);
      await outputFile.writeAsString(converted);
    }
  }

  Future<void> _writeBytes(Map<String, T> values) async {
    final Uint8List converted = await compute((parser as BioFileParserBinary<T>).convertToBytes, values);
    if (kIsWeb) {
      String fileName = "$T.${filePath.split(".").last}";
      await triggerFileDownload(converted, fileName);
    } else {
      final File outputFile = File(filePath);
      await outputFile.writeAsBytes(converted);
    }
  }

  String _extractFileName() {
    return filePath.split("/").last.split(".").first;
  }
}

class BioFileHandler<T> {
  BioFileHandlerContext<T> create(String filePath, {BioFileHandlerConfig? config}) {
    String fileEnding = filePath; // Supports plain file formats (fasta) for converting to String only
    if (filePath.contains(".")) {
      fileEnding = filePath.split(".").last;
    }

    final BioFileFormat format = BioFileFormat.fromName(fileEnding);

    final BioFileParser<T> parser = _BioFileParserFactory<T>().fromTypeAndFormat(format);

    final BioFileHandlerConfig fileHandlerConfig = config ?? BioFileHandlerConfig.serialDefaultConfig();

    return BioFileHandlerContext<T>(filePath, format, parser, fileHandlerConfig);
  }
}