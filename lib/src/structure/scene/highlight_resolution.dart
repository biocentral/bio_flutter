import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:vector_math/vector_math.dart';

/// Converts a Flutter color to normalized RGBA components.
Vector4 colorToVector4(Color color) =>
    Vector4(color.r, color.g, color.b, color.a);

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
