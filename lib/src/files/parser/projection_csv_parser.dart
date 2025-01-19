import 'package:bio_flutter/bio_flutter.dart';
import 'package:bio_flutter/src/files/bio_file_format.dart';

class ProjectionCSVParser extends BioFileParserString<ProjectionData> {
  static const List<String> _projectionCSVHeader = ["projectionID", "pointID", "x", "y"];
  static const _delimiter = ",";

  ProjectionData _buildUMAPDataFromParsedValues(String currentUMAPID, List<Map<String, dynamic>> parsedValues) {
    return ProjectionData(
        currentUMAPID,
        List.generate(parsedValues.length, (index) => parsedValues[index][_projectionCSVHeader[1]]),
        List.generate(parsedValues.length,
            (index) => [parsedValues[index][_projectionCSVHeader[2]], parsedValues[index][_projectionCSVHeader[3]]]));
  }

  @override
  Future<Map<String, ProjectionData>> readFromString(String? content, BioFileHandlerConfig config,
      {String? fileName}) async {
    if (content == null) {
      return {};
    }

    Map<String, ProjectionData> result = {};
    final List<String> lines = content.split("\n").where((line) => line != "" && line != "\n").toList();

    String expectedHeader = _projectionCSVHeader.join(_delimiter);
    if (lines.first != expectedHeader) {
      throw Exception("Invalid projection data csv file: Header is not correct (expected: $expectedHeader)");
    }

    int index = 0;
    String currentProjectionID = "";
    final List<Map<String, dynamic>> parsedValues = [];
    for (String line in lines.sublist(1)) {
      List<String> values = line.split(_delimiter);
      if (values.isEmpty) {
        throw Exception("Invalid projection data csv file: Empty line at index $index!");
      }
      if (values.length != _projectionCSVHeader.length) {
        throw Exception(
            "Invalid projection data csv file: Expected ${_projectionCSVHeader.length} values but got ${values.length}!");
      }
      String projectionID = values[0];
      String pointID = values[1];
      double? x = double.tryParse(values[2]);
      double? y = double.tryParse(values[3]);
      if (x == null || y == null) {
        throw Exception("Invalid projection data csv file: Could not parse coordinates at index $index!");
      }
      if (projectionID != currentProjectionID) {
        if (index != 0) {
          result[currentProjectionID] = _buildUMAPDataFromParsedValues(currentProjectionID, parsedValues);
          parsedValues.clear();
        }
        currentProjectionID = projectionID;
      }
      parsedValues.add({
        _projectionCSVHeader[0]: projectionID,
        _projectionCSVHeader[1]: pointID,
        _projectionCSVHeader[2]: x,
        _projectionCSVHeader[3]: y
      });
      index++;
    }
    result[currentProjectionID] = _buildUMAPDataFromParsedValues(currentProjectionID, parsedValues);

    return result;
  }

  @override
  Future<String> convertToString(Map<String, ProjectionData> values) async {
    StringBuffer result = StringBuffer();
    String header = _projectionCSVHeader.join(_delimiter);
    result.writeln(header);

    for (MapEntry<String, ProjectionData> mapEntry in values.entries) {
      String projectionID = mapEntry.key;
      ProjectionData projectionData = mapEntry.value;
      for (int i = 0; i < projectionData.coordinates.length; i++) {
        String line = [
          projectionID,
          projectionData.pointIDs?[i] ?? "",
          projectionData.x(index: i).toString(),
          projectionData.y(index: i).toString()
        ].join(_delimiter);
        result.writeln(line);
      }
    }
    return result.toString();
  }

  @override
  BioFileFormat getFormat() {
    return CSVFormat();
  }

  @override
  Type getType() {
    return ProjectionData;
  }
}
