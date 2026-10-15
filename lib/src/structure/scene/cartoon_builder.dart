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
    required this.residueForVertex,
  });

  final ContinuousRun run;
  final Node node;
  final MeshGeometry geometry;

  /// This run's material, typed for live texture changes.
  final PhysicallyBasedMaterial material;

  /// Inverted-hull outline, a hidden child of [node] until an outline color
  /// is set.
  final Node outlineNode;

  /// [outlineNode]'s geometry, updatable so thickness changes need no rebuild.
  final MeshGeometry outlineGeometry;

  /// [outlineNode]'s material, typed for live color changes.
  final UnlitMaterial outlineMaterial;

  /// Outline positions and normals before inflation, so thickness can be
  /// reapplied.
  final Float32List outlineBasePositions;
  final Float32List outlineBaseNormals;

  /// The `run.residues` index of each vertex of [geometry], for per-residue
  /// recoloring.
  final List<int> residueForVertex;
}

/// Render meshes for a structure, split only at backbone discontinuities.
class CartoonScene {
  const CartoonScene({required this.runs});

  final List<RunMesh> runs;

  List<Node> get nodes => [for (final r in runs) r.node];
}

// A multiple of 8 so the rectangular profile has exact corners.
final ({List<Vector2> round, List<Vector2> rect}) _unitProfiles =
    ribbonUnitProfiles(segments: 16);

/// Builds a continuous cartoon mesh for each drawable backbone run.
///
/// Requires initialized Scene resources. Runs with fewer than two points
/// are omitted. Secondary-structure transitions share a continuous surface.
CartoonScene buildCartoonScene(MolecularStructure structure) {
  final List<ContinuousRun> runs = buildContinuousRuns(structure);

  final List<RunMesh> runMeshes = [];

  for (final ContinuousRun run in runs) {
    final List<Vector3> points = run.residues
        .map((r) => r.alphaCarbon!.position)
        .toList();
    // A lone residue between breaks cannot form a ribbon.
    if (points.length < 2) continue;

    final List<ProfileSizeSample> sizes = ribbonProfileSizes(run);
    final List<Vector4> colors = ribbonColors(run);
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
      // White, so vertex colors show unmodified.
      ..baseColorFactor = Vector4(1.0, 1.0, 1.0, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.65
      // Run ends and twisted caps must not appear as holes.
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
      storage: GeometryStorage.updatable,
    );
    final UnlitMaterial outlineMaterial = UnlitMaterial()
      ..vertexColorWeight = 0.0;
    final Node outlineNode = Node(mesh: Mesh(outlineGeometry, outlineMaterial))
      ..raycastable = false
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
