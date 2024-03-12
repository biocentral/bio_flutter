List<List<T>> splitList<T>(List<T> listToSplit, int numberSplits) {
  /// Returns a list of lists with length numberSplits to perform async
  /// operations on parts of the list, e.g. loading and saving

  final int length = listToSplit.length;
  final int splitSize = length ~/ numberSplits;
  List<List<T>> splits = [];

  int index = 0;
  for (int splitNumber = 0; splitNumber < numberSplits; splitNumber++) {
    int end = (index + splitSize < length) ? index + splitSize : length;
    if (splitNumber == numberSplits - 1 && end < length) {
      end = length;
    }
    splits.add(listToSplit.sublist(index, end));
    index = end;
  }

  return splits;
}

List<List<String>> splitFastaLines(List<String> fastaLinesToSplit, int numberSplits) {
  /// Splits a list of lines from a fasta file for parallel operations
  /// Has to keep header and sequence together

  final int length = fastaLinesToSplit.length;
  final int splitSize = length ~/ numberSplits;
  List<List<String>> splits = [];

  int index = 0;
  for (int splitNumber = 0; splitNumber < numberSplits; splitNumber++) {
    int end = (index + splitSize < length) ? index + splitSize : length;
    if (splitNumber == numberSplits - 1 && end < length) {
      end = length;
    }
    if (end % 2 != 0) {
      end -= 1;
    }
    splits.add(fastaLinesToSplit.sublist(index, end));
    index = end;
  }

  return splits;
}