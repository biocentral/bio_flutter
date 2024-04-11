import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:bio_flutter/src/util/type_util.dart';

@immutable
class Taxonomy extends Equatable {
  /// List of valid taxonomy family suffixes, old botanical names like "Compositae" are not covered
  static const List<String> validFamilySuffixes = ["aceae", "idae"];

  final int id;
  final String? name;
  final String? family;

  const Taxonomy({required this.id, this.name, this.family});

  const Taxonomy.unknown()
      : id = -1,
        name = "",
        family = "";

  Taxonomy copyWith({id, name, family}) {
    return Taxonomy(id: id ?? this.id, name: name ?? this.name, family: family ?? this.family);
  }

  Taxonomy merge(Taxonomy other, {required bool failOnConflict}) {
    if (failOnConflict && id != other.id) {
      throw Exception("Merging taxonomies failed due to a conflict in their ids!");
    }
    int mergedID = id;

    String? mergedName = nullableMerge<String>(
        name, other.name, "Merging taxonomies failed due to a conflict in their names!", failOnConflict);
    String? mergedFamily = nullableMerge<String>(
        family, other.family, "Merging taxonomies failed due to a conflict in their families!", failOnConflict);
    return Taxonomy(id: mergedID, name: mergedName, family: mergedFamily);
  }

  static bool isValidSpeciesTaxon(String speciesName) {
    // Trim leading and trailing spaces
    String trimmedName = speciesName.trim();
    List<String> parts = trimmedName.split(RegExp(r'\s+'));

    // Check for exactly two parts for genus and species, and allow three for subspecies
    return parts.length == 2 || parts.length == 3;
  }

  static bool isValidFamilyTaxon(String familyName) {
    for (String suffix in validFamilySuffixes) {
      if (familyName.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }

  bool isUnknown() {
    return id == -1;
  }

  bool isHuman() {
    return id == 9606;
  }

  bool isViral() {
    return family?.endsWith("viridae") ?? false;
  }

  @override
  List<Object?> get props => [id];
}
