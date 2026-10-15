import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/scene/highlight_resolution.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('colorToVector4', () {
    test('converts full-channel RGBA correctly', () {
      // 1e-6, not 1e-9: `Color.r`/`g`/`b`/`a` are float32-precision under
      // the hood, not exact-double.
      final v = colorToVector4(const Color(0xFF804020));
      expect(v.x, closeTo(0x80 / 255.0, 1e-6));
      expect(v.y, closeTo(0x40 / 255.0, 1e-6));
      expect(v.z, closeTo(0x20 / 255.0, 1e-6));
      expect(v.w, closeTo(1.0, 1e-6));
    });

    test('converts a transparent color to zero alpha', () {
      final v = colorToVector4(const Color(0x00FFFFFF));
      expect(v.w, 0.0);
    });
  });

  group('scatterResidueColors', () {
    test('scatters one color per residue out to every vertex tagged with that residue', () {
      final colors = [
        Vector4(1, 0, 0, 1),
        Vector4(0, 1, 0, 1),
        Vector4(0, 0, 1, 1),
      ];
      final residueForVertex = [0, 0, 1, 2, 2, 2];
      final buffer = scatterResidueColors(residueForVertex, colors);
      expect(buffer, hasLength(6 * 4));
      // vertex 0 -> residue 0 -> red
      expect(buffer.sublist(0, 4), [1, 0, 0, 1]);
      // vertex 2 -> residue 1 -> green
      expect(buffer.sublist(8, 12), [0, 1, 0, 1]);
      // vertex 5 -> residue 2 -> blue
      expect(buffer.sublist(20, 24), [0, 0, 1, 1]);
    });

    test('an empty residueForVertex yields an empty buffer', () {
      expect(scatterResidueColors(const [], const []), isEmpty);
    });
  });
}
