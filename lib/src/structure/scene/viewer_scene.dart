import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import '../api/cartoon_style.dart';
import '../model/molecular_structure.dart';
import '../model/residue_key.dart';
import '../model/secondary_structure.dart';
import 'cartoon_builder.dart';
import 'highlight_resolution.dart';
import 'orbit_camera.dart';
import 'picking_proxy.dart';

/// Boundary between widget lifecycle and GPU operations.
abstract class ViewerScene {
  Widget view(OrbitCameraController camera);
  ResidueKey? pick(Offset position, Size size, OrbitCameraController camera);
  void updateAppearance(
    CartoonStyle style,
    Set<ResidueKey> selection,
    Map<ResidueKey, Color> highlights,
    ResidueKey? hover,
  );
  void dispose();
}

typedef ViewerSceneFactory = Future<ViewerScene> Function(
  MolecularStructure structure,
);

/// Internal override for lifecycle tests without a GPU context.
class ViewerSceneScope extends InheritedWidget {
  const ViewerSceneScope({
    super.key,
    required this.create,
    required super.child,
  });
  final ViewerSceneFactory create;

  static ViewerSceneFactory of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ViewerSceneScope>()?.create ??
      createViewerScene;

  @override
  bool updateShouldNotify(ViewerSceneScope oldWidget) =>
      create != oldWidget.create;
}

Future<ViewerScene> createViewerScene(MolecularStructure structure) async {
  await Scene.initializeStaticResources();
  return _CartoonViewerScene(buildCartoonScene(structure));
}

class _CartoonViewerScene implements ViewerScene {
  _CartoonViewerScene(this.cartoon) {
    scene.directionalLight = DirectionalLight(
      direction: Vector3(-0.3, -1, -0.4),
    );
    for (final run in cartoon.runs) {
      scene.add(run.node);
      final proxy = buildPickingProxyNode(run.run);
      if (proxy != null) {
        scene.add(proxy);
        _proxies[proxy] = run;
      }
    }
  }

  final CartoonScene cartoon;
  final Scene scene = Scene();
  final Map<Node, RunMesh> _proxies = {};
  final Map<RunMesh, List<Color>> _colors = {};
  CartoonStyle? _style;

  @override
  Widget view(OrbitCameraController camera) =>
      SceneView(scene, cameraBuilder: (_) => camera.buildCamera());

  @override
  ResidueKey? pick(Offset position, Size size, OrbitCameraController camera) {
    if (size.isEmpty) return null;
    final hit = scene.raycast(
      camera.buildCamera().screenPointToRay(position, size),
      includeInvisible: true,
    );
    if (hit == null) return null;
    final run = _proxies[hit.node];
    if (run == null) return null;
    final index = residueIndexForProxyTriangle(hit.triangleIndex);
    if (index < 0 || index >= run.run.residues.length) return null;
    return ResidueKey(run.run.chainId, run.run.residues[index].id);
  }

  @override
  void updateAppearance(
    CartoonStyle style,
    Set<ResidueKey> selection,
    Map<ResidueKey, Color> highlights,
    ResidueKey? hover,
  ) {
    if (style.outlineThickness < 0 || !style.outlineThickness.isFinite) {
      throw ArgumentError.value(style.outlineThickness, 'outlineThickness');
    }
    for (final run in cartoon.runs) {
      final colors = <Color>[];
      for (final residue in run.run.residues) {
        final key = ResidueKey(run.run.chainId, residue.id);
        final base = switch (residue.secondaryStructure) {
          SecondaryStructureType.helix => style.helixColor,
          SecondaryStructureType.sheet => style.sheetColor,
          SecondaryStructureType.loop => style.loopColor,
        };
        colors.add(
          key == hover
              ? style.hoverColor
              : selection.contains(key)
              ? style.selectionColor
              : highlights[key] ?? base,
        );
      }
      final previous = _colors[run];
      if (previous == null || !_sameColors(previous, colors)) {
        run.geometry.updateColors(
          scatterResidueColors(
            run.residueForVertex,
            colors.map(colorToVector4).toList(),
          ),
        );
        _colors[run] = colors;
      }
    }
    if (_style?.outlineColor != style.outlineColor) {
      setCartoonOutlineColor(
        cartoon,
        style.outlineColor == null ? null : colorToVector4(style.outlineColor!),
      );
    }
    if (_style?.outlineThickness != style.outlineThickness) {
      setCartoonOutlineThickness(cartoon, style.outlineThickness);
    }
    if (_style?.pencilTexture != style.pencilTexture) {
      setCartoonPencilTexture(cartoon, style.pencilTexture);
    }
    _style = style;
  }

  @override
  void dispose() {
    // Scene 0.20 owns GPU resources through managed objects, without a public
    // dispose API. Removing SceneView stops its ticker; release our indexes.
    _proxies.clear();
    _colors.clear();
  }
}

bool _sameColors(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
