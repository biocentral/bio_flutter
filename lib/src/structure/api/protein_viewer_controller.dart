import '../model/residue_key.dart';

/// Camera commands for one attached protein viewer.
///
/// Create once and dispose when its owner is removed. Commands return false
/// until a viewer is ready, or when a requested chain/residue does not exist.
/// A controller cannot be attached to multiple viewers at the same time.
class ProteinViewerController {
  bool _disposed = false;
  Object? _owner;
  bool Function()? _reset;
  bool Function(ResidueKey)? _residue;
  bool Function(String)? _chain;

  bool get isAttached => _owner != null;

  bool resetCamera() => _reset?.call() ?? false;
  bool focusResidue(ResidueKey key) => _residue?.call(key) ?? false;

  /// Focuses the chain identified by mmCIF `label_asym_id`.
  bool focusChain(String chainId) => _chain?.call(chainId) ?? false;

  void dispose() {
    _disposed = true;
    _owner = null;
    _reset = null;
    _residue = null;
    _chain = null;
  }
}

void attachViewerController(
  ProteinViewerController controller,
  Object owner, {
  required bool Function() reset,
  required bool Function(ResidueKey) residue,
  required bool Function(String) chain,
}) {
  if (controller._disposed) {
    throw StateError('The controller has been disposed.');
  }
  if (controller._owner != null && !identical(controller._owner, owner)) {
    throw StateError('A controller can only be attached to one ProteinViewer.');
  }
  controller._owner = owner;
  controller._reset = reset;
  controller._residue = residue;
  controller._chain = chain;
}

void detachViewerController(ProteinViewerController controller, Object owner) {
  if (!identical(controller._owner, owner)) return;
  controller._owner = null;
  controller._reset = null;
  controller._residue = null;
  controller._chain = null;
}
