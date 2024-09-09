sealed class BioFileFormat {
  bool isBinary() => false;

  const BioFileFormat();

  factory BioFileFormat.fromName(String fileEnding) {
    switch(fileEnding) {
      case "fasta": return FastaFormat();
      case "json": return JSONFormat();
      case "csv": return CSVFormat();
      case "tsv": return TSVFormat();
      case "fcs": return FCSFormat();
      default: throw UnimplementedError("File format $fileEnding not supported!");
    }
  }
}

class FastaFormat extends BioFileFormat {}
class JSONFormat extends BioFileFormat {}
class CSVFormat extends BioFileFormat {}
class TSVFormat extends BioFileFormat {}
class FCSFormat extends BioFileFormat {
  @override
  bool isBinary() => true;
}