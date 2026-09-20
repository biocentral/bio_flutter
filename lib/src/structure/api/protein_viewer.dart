import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../interaction/selection_state.dart';
import '../model/chain.dart';
import '../model/molecular_structure.dart';
import '../model/residue.dart';
import '../model/residue_key.dart';
import '../scene/bounding_sphere.dart';
import '../scene/orbit_camera.dart';
import '../scene/viewer_scene.dart';
import 'cartoon_style.dart';
import 'protein_viewer_controller.dart';

/// A residue hit, including its unique key and author-facing chain metadata.
class ResidueHit {
  const ResidueHit({
    required this.key,
    required this.chain,
    required this.residue,
  });
  final ResidueKey key;
  final Chain chain;
  final Residue residue;
  String get name => residue.name;
}

/// An embeddable cartoon viewer for one parsed amino acid structure.
///
/// Provide bounded width and height. Drag to rotate, scroll or pinch to zoom,
/// and shift-drag or use two fingers to pan. Shift/control/meta-click toggles
/// a residue within the selection; an ordinary click replaces the selection.
/// Clicking the background clears it.
class ProteinViewer extends StatefulWidget {
  const ProteinViewer({
    super.key,
    required this.structure,
    this.style = const CartoonStyle(),
    this.controller,
    this.selectedResidues,
    this.highlights = const {},
    this.onSelectionChanged,
    this.onResidueTap,
    this.onResidueHover,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  });

  final MolecularStructure structure;
  final CartoonStyle style;
  final ProteinViewerController? controller;

  /// Null enables internal selection. An empty set controls it as unselected.
  ///
  /// In controlled mode, interactions propose [onSelectionChanged] values;
  /// visible selection changes only when the parent supplies new values.
  /// Unknown keys are ignored. Replace collections rather than mutating them.
  /// Releasing control retains the last selection. Changing structure clears
  /// internal selection; controlled selection is intersected with the new IDs.
  final Set<ResidueKey>? selectedResidues;

  /// External color annotations, independent of selection. Unknown keys are ignored.
  final Map<ResidueKey, Color> highlights;

  /// User-proposed selection changes. Property updates never fire this callback.
  final ValueChanged<Set<ResidueKey>>? onSelectionChanged;
  final ValueChanged<ResidueHit?>? onResidueTap;

  /// Pointer hover changes; null indicates a miss or pointer exit.
  final ValueChanged<ResidueHit?>? onResidueHover;

  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final WidgetBuilder? emptyBuilder;

  @override
  State<ProteinViewer> createState() => _ProteinViewerState();
}

class _ProteinViewerState extends State<ProteinViewer> {
  final _selection = SelectionState();
  final _camera = OrbitCameraController(target: Vector3.zero());
  final Map<ResidueKey, ResidueHit> _residues = {};
  ViewerSceneFactory? _factory; // testing
  ViewerScene? _scene;
  Object? _error;
  int _generation = 0;
  Size _size = Size.zero;
  ResidueKey? _hover;
  Offset? _hoverPosition;
  bool _hoverScheduled = false;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _camera.addListener(_cameraChanged);
    _indexStructure();
    _attach();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final factory = ViewerSceneScope.of(context);
    if (_factory != factory) {
      _factory = factory;
      _load();
    }
  }

  @override
  void didUpdateWidget(ProteinViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller != null) {
        detachViewerController(oldWidget.controller!, this);
      }
      _attach();
    }
    if (!identical(oldWidget.structure, widget.structure)) {
      _indexStructure();
      _load();
    } else {
      _selection.update(
        selected: widget.selectedResidues,
        available: _residues.keys.toSet(),
      );
      _updateAppearance();
    }
  }

  void _indexStructure() {
    _residues.clear();
    for (final chain in widget.structure.chains) {
      for (final residue in chain.residues) {
        final key = ResidueKey(chain.id, residue.id);
        _residues[key] = ResidueHit(key: key, chain: chain, residue: residue);
      }
    }
    _selection.update(
      selected: widget.selectedResidues,
      available: _residues.keys.toSet(),
      reset: true,
    );
    _hover = null;
    _hoverPosition = null;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _scene?.dispose();
    _scene = null;
    _error = null;
    if (widget.structure.atoms.isEmpty) return;
    try {
      final scene = await _factory!(widget.structure);
      if (!mounted || generation != _generation) {
        scene.dispose();
        return;
      }
      _scene = scene;
      _updateAppearance();
      _resetCamera();
      setState(() {});
    } catch (error) {
      if (!mounted || generation != _generation) return;
      _scene?.dispose();
      setState(() {
        _scene = null;
        _error = error;
      });
    }
  }

  void _attach() {
    final controller = widget.controller;
    if (controller == null) return;
    attachViewerController(
      controller,
      this,
      reset: _resetCamera,
      residue: _focusResidue,
      chain: _focusChain,
    );
  }

  bool _resetCamera() {
    if (_scene == null) return false;
    final sphere = BoundingSphere.of(widget.structure);
    _camera.reset(
      target: sphere.center,
      distance: _framingDistance(sphere.radius),
    );
    return true;
  }

  double _framingDistance(double radius) => math.max(
    4,
    radius * 2.8 / math.min(1, _size.isEmpty ? 1 : _size.aspectRatio),
  );

  bool _focusResidue(ResidueKey key) {
    final hit = _residues[key];
    if (_scene == null || hit == null || hit.residue.atoms.isEmpty) {
      return false;
    }
    final atoms = hit.residue.atoms;
    final center =
        atoms.fold(Vector3.zero(), (sum, atom) => sum + atom.position) /
        atoms.length.toDouble();
    _camera.focusOn(target: center, distance: 15);
    return true;
  }

  bool _focusChain(String id) {
    if (_scene == null) return false;
    for (final chain in widget.structure.chains) {
      if (chain.id != id || chain.residues.every((r) => r.atoms.isEmpty)) {
        continue;
      }
      final sphere = BoundingSphere.of(MolecularStructure(chains: [chain]));
      _camera.focusOn(
        target: sphere.center,
        distance: _framingDistance(sphere.radius),
      );
      return true;
    }
    return false;
  }

  void _updateAppearance() => _scene?.updateAppearance(
    widget.style,
    _selection.value,
    widget.highlights,
    _hover,
  );

  void _cameraChanged() {
    if (!mounted) return;
    setState(() {});
    if (_hoverPosition != null) _scheduleHover();
  }

  void _scheduleHover() {
    if (_hoverScheduled) return;
    _hoverScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _hoverScheduled = false;
      if (!mounted) return;
      final position = _hoverPosition;
      final key = position == null
          ? null
          : _scene?.pick(position, _size, _camera);
      if (key == _hover) return;
      _hover = key;
      _updateAppearance();
      widget.onResidueHover?.call(_residues[key]);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _tap(TapUpDetails details) {
    final key = _scene?.pick(details.localPosition, _size, _camera);
    final keyboard = HardwareKeyboard.instance;
    final next = _selection.tap(
      key,
      additive:
          keyboard.isShiftPressed ||
          keyboard.isControlPressed ||
          keyboard.isMetaPressed,
    );
    _updateAppearance();
    if (next != null) widget.onSelectionChanged?.call(next);
    widget.onResidueTap?.call(_residues[key]);
  }

  @override
  void dispose() {
    ++_generation;
    if (widget.controller != null) {
      detachViewerController(widget.controller!, this);
    }
    _scene?.dispose();
    _camera.removeListener(_cameraChanged);
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
        throw FlutterError(
          'ProteinViewer requires bounded width and height. Use Expanded or SizedBox.',
        );
      }
      _size = constraints.biggest;
      if (widget.structure.atoms.isEmpty) {
        return widget.emptyBuilder?.call(context) ??
            const Center(child: Text('No amino acid coordinates.'));
      }
      if (_error != null) {
        return widget.errorBuilder?.call(context, _error!) ??
            const Center(
              child: Text('The protein viewer could not initialize.'),
            );
      }
      final scene = _scene;
      if (scene == null) {
        return widget.loadingBuilder?.call(context) ??
            const Center(child: CircularProgressIndicator());
      }
      return Semantics(
        label: 'Protein structure. Drag to rotate, scroll to zoom. Click a residue to select it.',
        child: ClipRect(
          child: MouseRegion(
            onHover: (event) {
              _hoverPosition = event.localPosition;
              _scheduleHover();
            },
            onExit: (_) {
              _hoverPosition = null;
              _scheduleHover();
            },
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  GestureBinding.instance.pointerSignalResolver.register(
                    event,
                    (_) {
                      _camera.zoom(
                        math.exp(
                          event.scrollDelta.dy.clamp(-500, 500) * 0.0015,
                        ),
                      );
                    },
                  );
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _tap,
                onScaleStart: (_) {
                  _scale = 1;
                  _hoverPosition = null;
                  _scheduleHover();
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount > 1 ||
                      HardwareKeyboard.instance.isShiftPressed) {
                    _camera.pan(
                      details.focalPointDelta.dx,
                      details.focalPointDelta.dy,
                      _size.height,
                    );
                  } else {
                    _camera.orbit(
                      -details.focalPointDelta.dx * 0.01,
                      -details.focalPointDelta.dy * 0.01,
                    );
                  }
                  if (details.scale > 0) _camera.zoom(_scale / details.scale);
                  _scale = details.scale;
                },
                child: scene.view(_camera),
              ),
            ),
          ),
        ),
      );
    },
  );
}
