import 'package:bio_flutter/bio_flutter.dart';
import 'package:bio_flutter/src/files/bio_file_format.dart';

class ProteinFastaParser extends BioFileParserString<Protein> {
  (List<String>, String) _extractAdheringText(String input, String startDelimiter, String endDelimiter) {
    final String escapedStartDelimiter = RegExp.escape(startDelimiter);
    final String escapedEndDelimiter = RegExp.escape(endDelimiter);

    final RegExp regExp = RegExp('$escapedStartDelimiter(.*?)$escapedEndDelimiter');
    return (
      regExp
          .allMatches(input)
          .map((match) => match.group(0)?.replaceAll(startDelimiter, "").replaceAll(endDelimiter, "") ?? "")
          .toList(),
      input.replaceAll(regExp, "")
    );
  }

  @override
  Future<Map<String, Protein>> readFromString(String? content, BioFileHandlerConfig config, {String? fileName}) async {
    if (content == null) {
      return {};
    }

    Map<String, Protein> proteins = {};
    if (!content.contains(">")) {
      throw Exception("Invalid fasta file: Missing > separator");
    }
    final List<String> entries = content.split("\n>").where((entry) => entry != "" && entry != "\n").toList();

    for (String entry in entries) {
      List<String> lines = entry.split("\n");
      if (lines.length < 2) {
        throw Exception("Invalid fasta file: Too few lines for entry (missing values or sequence) for entry: $entry");
      }
      Map<String, String> attributes = {};
      // Read header
      String header = lines.first;

      // Extract adhering values
      if (header.contains("[") && header.contains("]")) {
        (List<String>, String) extractionResult = _extractAdheringText(header, "[", "]");
        List<String> bracketValues = extractionResult.$1;
        header = extractionResult.$2;
        // Fasta Standard: [Homo sapiens] := organism name
        if (bracketValues.length == 1) {
          attributes["organism"] = bracketValues.first;
        } else {
          for (int i = 0; i < bracketValues.length; i++) {
            attributes["unknown$i"] = bracketValues[i];
          }
        }
      }
      List<String> values = header.split(" ");

      // Read id
      String id = values[0];
      id = id[0] == ">" ? id.substring(1) : id;
      if (id.contains("|")) {
        List<String> ids = id.split("|");
        if (ids.length < 3) {
          throw Exception("Unknown sequence ID format: $id");
        }
        id = ids[1];
      }

      // Read custom attributes
      for (String attribute in values.skip(1)) {
        if (attribute == "") {
          continue;
        }
        List<String> keyValue = attribute.split("=");
        if (!attribute.contains("=") || keyValue.length != 2) {
          // Bad fasta file format, ignore these values
          continue;
        }
        String key = keyValue[0];
        String value = keyValue[1];
        attributes[key] = value;
      }

      // Read sequence
      String sequenceString =
          lines.sublist(1).where((line) => line != "" && line != "\n").map((line) => line.trim()).join("");
      Sequence? sequence = Sequence.buildVerifiedFromString(sequenceString);
      if (sequence == null) {
        throw Exception("Could not read sequence for entry: $entry");
      }

      // Add file name as dataset column
      if (fileName != null && !attributes.containsKey(BioFileParser.datasetColumnName)) {
        attributes[BioFileParser.datasetColumnName] = fileName;
      }

      Protein protein = Protein(id, sequence: sequence).updateFromMap<Protein>(attributes);

      proteins[id] = protein;
    }
    return proteins;
  }

  @override
  Future<String> convertToString(Map<String, Protein> values) async {
    StringBuffer result = StringBuffer();
    for (Protein protein in values.values) {
      result.writeln(protein.toFastaHeader());
      result.writeln(protein.sequence.seq);
    }
    return result.toString();
  }

  @override
  BioFileFormat getFormat() {
    return FastaFormat();
  }

  @override
  Type getType() {
    return Protein;
  }
}
