import 'package:bio_flutter/bio_flutter.dart';
import 'package:flutter/material.dart';

class CustomAttributesSVFileFormatHandler extends BioFileFormatStrategy<CustomAttributes> {
  final String delimiter = "";

  CustomAttributesSVFileFormatHandler(super.filePath, super.config);

  @override
  Future<Map<String, CustomAttributes>> readFromString(String? content) async {
    if(content == null) {
      return {};
    }

    Map<String, CustomAttributes> result = {};
    final List<String> lines = content.split("\n").where((line) => line != "" && line != "\n").toList();

    List<String> headerAsList = lines.first.toLowerCase().split(delimiter);
    Set<String> headerAsSet = headerAsList.toSet();
    if(headerAsList.length > headerAsSet.length) {
      throw Exception("Header of csv file contains non-unique values!");
    }

    if(!headerAsSet.contains("id")) {
      throw Exception("Expected 'id' in header to associate attributes with some entity!");
    }

    for(String line in lines.sublist(1)) {
      List<String> values = line.split(delimiter);

      int columnIndex = 0;
      String? entityID;
      Map<String, String> attributes = {};
      for(String columnName in headerAsList) {
        if(columnName == "id") {
          entityID = values[columnIndex];
        } else {
          attributes[columnName] = values[columnIndex];
        }
        columnIndex++;
      }

      if(entityID == null || entityID == "") {
        throw Exception("Could not find entity id for line: $line!");
      }

      result[entityID] = CustomAttributes(attributes);
    }

    return result;
  }

  @override
  Future<String> convertToString(Map<String, CustomAttributes> values) async {
    StringBuffer result = StringBuffer();
    List<String> columnNames = values.values.expand((element) => element.keys()).toSet().toList()..insert(0, "id");
    String header = columnNames.join(delimiter);
    result.writeln(header);

    for (MapEntry<String, CustomAttributes> mapEntry in values.entries) {
      String entryID = mapEntry.key;

      List<String> lineValues = [entryID];
      for (String columnName in columnNames) {
        lineValues.add(mapEntry.value[columnName] ?? "");
      }
      result.writeln(lineValues.join(delimiter));
    }
    return result.toString();
  }
}

class CustomAttributesCSVFileFormatHandler extends CustomAttributesSVFileFormatHandler {
  @override
  String get delimiter => ",";

  CustomAttributesCSVFileFormatHandler(super.filePath, super.config);
}

class CustomAttributesTSVFileFormatHandler extends CustomAttributesSVFileFormatHandler {
  // TODO TAB vs. SPACE
  @override
  String get delimiter => " ";

  CustomAttributesTSVFileFormatHandler(super.filePath, super.config);
}
