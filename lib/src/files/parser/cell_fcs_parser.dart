import 'dart:typed_data';

import 'package:bio_flutter/bio_flutter.dart';
import 'package:bio_flutter/src/files/bio_file_format.dart';

import '../../cell/cell.dart';

class CellFCSParser implements BioFileParserBinary<Cell> {

  @override
  Future<Map<String, Cell>> readFromBytes(Uint8List? content, BioFileHandlerConfig config, {String? fileName}) {
    // TODO: implement readFromBytes
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> convertToBytes(Map<String, Cell> values) {
    // TODO: implement convertToBytes
    throw UnimplementedError();
  }

  @override
  BioFileFormat getFormat() {
    return FCSFormat();
  }

  @override
  Type getType() {
    return Cell;
  }

}
