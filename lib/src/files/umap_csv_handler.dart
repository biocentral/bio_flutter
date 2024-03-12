import 'package:bio_flutter/bio_flutter.dart';

class UMAPCSVFileFormatHandler extends BioFileFormatStrategy<UMAPData> {
  UMAPCSVFileFormatHandler(super.filePath, super.config);

  static const List<String> _umapCSVHeader = ["umapID", "pointID", "x", "y"];
  static const _delimiter = ",";

  UMAPData _buildUMAPDataFromParsedValues(String currentUMAPID, List<Map<String, dynamic>> parsedValues) {
    return UMAPData(
        currentUMAPID,
        List.generate(parsedValues.length, (index) => parsedValues[index][_umapCSVHeader[1]]),
        List.generate(parsedValues.length,
            (index) => (parsedValues[index][_umapCSVHeader[2]], parsedValues[index][_umapCSVHeader[3]])));
  }

  @override
  Future<Map<String, UMAPData>> readFromString(String? content) async {
    if(content == null) {
      return {};
    }

    Map<String, UMAPData> result = {};
    final List<String> lines = content.split("\n").where((line) => line != "" && line != "\n").toList();

    String expectedHeader = _umapCSVHeader.join(_delimiter);
    if (lines.first != expectedHeader) {
      throw Exception("Invalid umap data csv file: Header is not correct (expected: $expectedHeader)");
    }

    int index = 0;
    String currentUMAPID = "";
    final List<Map<String, dynamic>> parsedValues = [];
    for (String line in lines.sublist(1)) {
      List<String> values = line.split(_delimiter);
      if (values.isEmpty) {
        throw Exception("Invalid umap data csv file: Empty line at index $index!");
      }
      if (values.length != _umapCSVHeader.length) {
        throw Exception(
            "Invalid umap data csv file: Expected ${_umapCSVHeader.length} values but got ${values.length}!");
      }
      String umapID = values[0];
      String pointID = values[1];
      double? x = double.tryParse(values[2]);
      double? y = double.tryParse(values[3]);
      if (x == null || y == null) {
        throw Exception("Invalid umap data csv file: Could not parse coordinates at index $index!");
      }
      if (umapID != currentUMAPID) {
        if (index != 0) {
          result[currentUMAPID] = _buildUMAPDataFromParsedValues(currentUMAPID, parsedValues);
          parsedValues.clear();
        }
        currentUMAPID = umapID;
      }
      parsedValues
          .add({_umapCSVHeader[0]: umapID, _umapCSVHeader[1]: pointID, _umapCSVHeader[2]: x, _umapCSVHeader[3]: y});
      index++;
    }
    result[currentUMAPID] = _buildUMAPDataFromParsedValues(currentUMAPID, parsedValues);

    return result;
  }

  @override
  Future<String> convertToString(Map<String, UMAPData> values) async {
    StringBuffer result = StringBuffer();
    String header = _umapCSVHeader.join(_delimiter);
    result.writeln(header);

    for (MapEntry<String, UMAPData> mapEntry in values.entries) {
      String umapID = mapEntry.key;
      UMAPData umapData = mapEntry.value;
      for (int i = 0; i < umapData.coordinates.length; i++) {
        String line = [
          umapID,
          umapData.pointIDs?[i] ?? "",
          umapData.x(index: i).toString(),
          umapData.y(index: i).toString()
        ].join(_delimiter);
        result.writeln(line);
      }
    }
    return result.toString();
  }
}
