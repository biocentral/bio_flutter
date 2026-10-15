import 'package:flutter/foundation.dart';

import '../model/residue_key.dart';

/// Selection ownership independent of rendering and pointer handling.
class SelectionState {
  Set<ResidueKey> _internal = const {};
  Set<ResidueKey>? _controlled;
  Set<ResidueKey> _available = const {};

  Set<ResidueKey> get value => _controlled ?? _internal;

  void update({
    required Set<ResidueKey>? selected,
    required Set<ResidueKey> available,
    bool reset = false,
  }) {
    final previous = value;
    _available = available;
    _controlled = selected == null
        ? null
        : Set.unmodifiable(selected.intersection(available));
    if (reset) {
      _internal = const {};
    } else if (_controlled == null) {
      _internal = Set.unmodifiable(previous.intersection(available));
    }
  }

  /// Returns a proposed change, or null if selection would stay the same.
  Set<ResidueKey>? tap(ResidueKey? key, {required bool additive}) {
    if (key != null && !_available.contains(key)) return null;
    final next = <ResidueKey>{};
    if (key != null) {
      if (additive) next.addAll(value);
      if (!next.remove(key)) next.add(key);
    }
    if (setEquals(next, value)) return null;
    final result = Set<ResidueKey>.unmodifiable(next);
    if (_controlled == null) _internal = result;
    return result;
  }
}
