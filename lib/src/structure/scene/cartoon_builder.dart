import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../model/molecular_structure.dart';
import 'backbone_orientation.dart';
import 'backbone_segment.dart';
import 'oriented_extrude.dart';
import 'pencil_grain.dart';
import 'ribbon_profile.dart';

/// Default outline expansion in ångströms.
const double defaultOutlineThickness = 0.05;

/// Sampling density sufficient to resolve a two-residue strand arrowhead.
const int _stationsPerResidue = 16;

/// A continuous run's geometry and buffers used for live styling.
class RunMesh {
  const RunMesh({
    required this.run,
    required this.node,
    required this.geometry,
    required this.material,
    required this.outlineNode,
    required this.outlineGeometry,
    required this.outlineMaterial,
    required this.outlineBasePositions,
    required this.outlineBaseNormals,
    required this.baseColors,
    required this.residueForVertex,
  });

  final ContinuousRun run;
  final Node node;
  final MeshGeometry geometry;

  /// This run's own material instance (also reachable via
  /// `node.mesh.primitives.first.material`, but as the base `Material`
  /// type, which would need a downcast) — kept here typed as
  /// [PhysicallyBasedMaterial] so live style toggles (e.g.
  /// [setCartoonPencilTexture]) can set its texture/factor fields
  /// directly, the same way [setCartoonOutlineColor] mutates `node`.
  final PhysicallyBasedMaterial material;

  /// This run's "inverted hull" outline mesh — a child of [node] (so it
  /// rides along with it in the scene graph automatically), hidden
  /// (`visible = false`) until [setCartoonOutlineColor] turns it on. See
  /// [buildCartoonScene]'s build loop for the technique.
  final Node outlineNode;

  /// [outlineNode]'s geometry — `GeometryStorage.updatable` so
  /// [setCartoonOutlineThickness] can recompute and re-upload its inflated
  /// positions without a full mesh rebuild.
  final MeshGeometry outlineGeometry;

  /// [outlineNode]'s material, kept here (like [material]) so
  /// [setCartoonOutlineColor] can set its color without downcasting.
  final UnlitMaterial outlineMaterial;

  /// [outlineGeometry]'s vertex positions/normals *before* the outline
  /// inflation offset — [setCartoonOutlineThickness] recomputes
  /// `outlineBasePositions[i] + outlineBaseNormals[i] * thickness` from
  /// these rather than re-deriving them (or, worse, trying to un-inflate
  /// the geometry's current positions by whatever the previous thickness
  /// was).
  final Float32List outlineBasePositions;
  final Float32List outlineBaseNormals;

  /// One base (un-highlighted) secondary-structure color per residue of
  /// [run], from [ribbonColors] — cached so recoloring always starts from
  /// a known baseline instead of trying to read colors back out of the GPU
  /// buffer.
  final List<Vector4> baseColors;

  /// One residue index (into `run.residues`) per vertex of [geometry], in
  /// the exact order [geometry]'s own color buffer expects — how a
  /// per-residue highlight override gets scattered into a vertex-color
  /// update.
  final List<int> residueForVertex;
}

/// Render meshes for a structure, split only at backbone discontinuities.
class CartoonScene {
  const CartoonScene({required this.runs});

  final List<RunMesh> runs;

  List<Node> get nodes => [for (final r in runs) r.node];
}

// 16 segments (a multiple of 8) so `ribbonUnitProfiles`'s derived
// rectangular profile — the beta-sheet flat-ribbon cross-section — lands
// exactly on its four corners; see that function's doc comment.
final ({List<Vector2> round, List<Vector2> rect}) _unitProfiles =
    ribbonUnitProfiles(segments: 16);

/// Builds a continuous cartoon mesh for each drawable backbone run.
///
/// Requires initialized Scene resources. Runs with fewer than two points
/// are omitted. Secondary-structure transitions share a continuous surface.
CartoonScene buildCartoonScene(
  MolecularStructure structure, {
  SecondaryStructureColorScheme? colorScheme,
}) {
  final List<ContinuousRun> runs = buildContinuousRuns(structure);

  final List<RunMesh> runMeshes = [];

  for (final ContinuousRun run in runs) {
    final List<Vector3> points = run.residues
        .map((r) => r.alphaCarbon!.position)
        .toList();
    // A path needs at least two distinct control points; a lone residue
    // between two breaks can't be drawn as a ribbon and is simply
    // skipped — it still exists in `runs` for anything that only needs
    // residue metadata, just not for rendering/picking.
    if (points.length < 2) continue;

    final List<ProfileSizeSample> sizes = ribbonProfileSizes(run);
    final List<Vector4> colors = ribbonColors(run, scheme: colorScheme);
    final CatmullRomPath path = CatmullRomPath(points);
    // Use the same C=O orientation signal for every secondary-structure type.
    final List<Vector3> directions = backboneOrientationVectors(run.residues);

    final OrientedExtrudeArrays arrays = buildOrientedExtrudeArrays(
      path: path,
      residueDirectionVectors: directions,
      roundProfile: _unitProfiles.round,
      rectProfile: _unitProfiles.rect,
      sizeAt: (t) => profileSizeAtParameter(sizes, t),
      colorAt: (t) => colorAtParameter(colors, t),
      residueIndexAt: (t) => residueIndexAtParameter(colors.length, t),
      stations: (points.length - 1) * _stationsPerResidue + 1,
    );
    final MeshGeometry geometry = MeshGeometry.fromArrays(
      positions: arrays.positions,
      normals: arrays.normals,
      texCoords: arrays.texCoords,
      colors: arrays.colors,
      indices: arrays.indices,
      // Live coloring requires writable GPU buffers.
      storage: GeometryStorage.updatable,
    );

    final PhysicallyBasedMaterial material = PhysicallyBasedMaterial()
      // White so the per-vertex secondary-structure color (see
      // `ribbon_profile.dart`) shows through unmodified; `vertexColorWeight`
      // defaults to 1.0, so it's already multiplied in.
      ..baseColorFactor = Vector4(1.0, 1.0, 1.0, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.65
      // Guarantees every surface renders from either side, so a run end
      // (or a cap whose winding flips at a sharp spline twist) never
      // reads as an open, see-through hole.
      ..doubleSided = true;
    final Node node = Node(mesh: Mesh(geometry, material))
      // Picking uses low-resolution proxies to avoid scanning ribbon triangles.
      ..raycastable = false;

    // An expanded hull exposes a depth-tested border around each run.
    // Parenting it to the ribbon keeps both surfaces in the same transform.
    final Float32List outlinePositions = Float32List(arrays.positions.length);
    for (int i = 0; i < outlinePositions.length; i++) {
      outlinePositions[i] =
          arrays.positions[i] + arrays.normals[i] * defaultOutlineThickness;
    }
    final MeshGeometry outlineGeometry = MeshGeometry.fromArrays(
      positions: outlinePositions,
      normals: arrays.normals,
      texCoords: arrays.texCoords,
      colors: arrays.colors,
      // This generator's winding exposes the inward hull under default culling.
      indices: arrays.indices,
      // `setCartoonOutlineThickness` re-inflates and re-uploads positions
      // in place after construction, which needs updatable storage (like
      // `geometry` above needs it for highlighting).
      storage: GeometryStorage.updatable,
    );
    final UnlitMaterial outlineMaterial = UnlitMaterial()
      ..vertexColorWeight = 0.0;
    final Node outlineNode = Node(mesh: Mesh(outlineGeometry, outlineMaterial))
      ..raycastable = false
      // Hidden until `setCartoonOutlineColor` turns outlines on, matching
      // `setCartoonPencilTexture`'s off-by-default-on-a-fresh-build shape.
      ..visible = false;
    node.add(outlineNode);

    runMeshes.add(
      RunMesh(
        run: run,
        node: node,
        geometry: geometry,
        material: material,
        outlineNode: outlineNode,
        outlineGeometry: outlineGeometry,
        outlineMaterial: outlineMaterial,
        outlineBasePositions: arrays.positions,
        outlineBaseNormals: arrays.normals,
        baseColors: colors,
        residueForVertex: arrays.residueForVertex,
      ),
    );
  }

  return CartoonScene(runs: runMeshes);
}

/// Sets the depth-tested outline color. Null hides outlines.
void setCartoonOutlineColor(CartoonScene cartoon, Vector4? color) {
  for (final RunMesh runMesh in cartoon.runs) {
    runMesh.outlineNode.visible = color != null;
    if (color != null) runMesh.outlineMaterial.baseColorFactor = color;
  }
}

/// Updates outline positions from cached normals, without rebuilding meshes.
void setCartoonOutlineThickness(CartoonScene cartoon, double thickness) {
  for (final RunMesh runMesh in cartoon.runs) {
    final Float32List positions = runMesh.outlineBasePositions;
    final Float32List normals = runMesh.outlineBaseNormals;
    final Float32List inflated = Float32List(positions.length);
    for (int i = 0; i < inflated.length; i++) {
      inflated[i] = positions[i] + normals[i] * thickness;
    }
    runMesh.outlineGeometry.updatePositions(inflated);
  }
}

/// Enables or disables the pencil-grain material texture.
void setCartoonPencilTexture(CartoonScene cartoon, bool enabled) {
  final Texture2D? texture = enabled ? pencilGrainTexture() : null;
  for (final RunMesh runMesh in cartoon.runs) {
    runMesh.material.baseColorTexture = texture;
  }
}
