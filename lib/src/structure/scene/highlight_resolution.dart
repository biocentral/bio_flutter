import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

import '../model/residue_key.dart';

/// Converts a Flutter color to normalized RGBA components.
Vector4 colorToVector4(Color color) =>
    Vector4(color.r, color.g, color.b, color.a);

/// Resolves hover, selection, annotation, and base colors in that order.
Vector4 resolveResidueColor({
  required ResidueKey key,
  required Vector4 baseColor,
  required ResidueKey? hoveredResidue,
  required ResidueKey? selectedResidue,
  required Map<ResidueKey, Color> highlightSet,
  required Color hoverColor,
  required Color selectedColor,
}) {
  if (key == hoveredResidue) return colorToVector4(hoverColor);
  if (key == selectedResidue) return colorToVector4(selectedColor);
  final Color? setColor = highlightSet[key];
  if (setColor != null) return colorToVector4(setColor);
  return baseColor;
}

/// Expands residue colors into the mesh's vertex-color buffer.
Float32List scatterResidueColors(
  List<int> residueForVertex,
  List<Vector4> perResidueColors,
) {
  final Float32List colors = Float32List(residueForVertex.length * 4);
  for (int v = 0; v < residueForVertex.length; v++) {
    final Vector4 c = perResidueColors[residueForVertex[v]];
    colors[v * 4] = c.x;
    colors[v * 4 + 1] = c.y;
    colors[v * 4 + 2] = c.z;
    colors[v * 4 + 3] = c.w;
  }
  return colors;
}
