bool str2bool(String string) {
  if (["yes", "y", "true", "1", "t"].contains(string.toLowerCase())) {
    return true;
  } else {
    return false;
  }
}

/// Compares two nullable values of same type for merge conflicts
///
/// If exactly one of [t1] and [t2] is null, returns the other value
/// If [failOnConflict] is true and [t1] and [t2] are not equal, raises Exception with [exceptionMessage]
/// Otherwise, the first value, i.e. [t1] is returned
T? nullableMerge<T>(T? t1, T? t2, String exceptionMessage, bool failOnConflict) {
  if(t1 == null && t2 == null) {
    return null;
  }
  if(t1 != null && t2 == null) {
    return t1;
  }
  if(t1 == null && t2 != null) {
    return t2;
  }
  if(t1 is Comparable && t2 is Comparable) {
    if (failOnConflict && t1.compareTo(t2) != 0) {
      throw Exception(exceptionMessage);
    }
  } else {
    if (failOnConflict && t1.toString().compareTo(t2.toString()) != 0) {
      throw Exception(exceptionMessage);
    }
  }
  return t1;
}

/// Mixin to get the type name, i.e. class name of this class
///
/// Necessary because flutter web optimizer changes type names
mixin TypeNameMixin {
  String get typeName;
}