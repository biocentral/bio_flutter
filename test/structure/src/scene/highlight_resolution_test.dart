import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/residue_key.dart';
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

  group('resolveResidueColor', () {
    const key = ResidueKey('A', ResidueId(1, ''));
    const other = ResidueKey('A', ResidueId(2, ''));
    final baseColor = Vector4(0.1, 0.2, 0.3, 1.0);
    const hoverColor = Color(0xFFFF0000);
    const selectedColor = Color(0xFF00FF00);
    const setColor = Color(0xFF0000FF);

    Vector4 resolve({
      ResidueKey? hovered,
      ResidueKey? selected,
      Map<ResidueKey, Color> set = const {},
    }) => resolveResidueColor(
      key: key,
      baseColor: baseColor,
      hoveredResidue: hovered,
      selectedResidue: selected,
      highlightSet: set,
      hoverColor: hoverColor,
      selectedColor: selectedColor,
    );

    test('falls back to the base color when nothing is highlighted', () {
      expect(resolve(), baseColor);
    });

    test('a key in the highlight set takes that key\'s own color', () {
      expect(resolve(set: {key: setColor}), colorToVector4(setColor));
    });

    test('a set entry for a different residue does not affect this one', () {
      expect(resolve(set: {other: setColor}), baseColor);
    });

    test('selected beats a set entry', () {
      expect(
        resolve(selected: key, set: {key: setColor}),
        colorToVector4(selectedColor),
      );
    });

    test('hovered beats selected', () {
      expect(
        resolve(hovered: key, selected: key, set: {key: setColor}),
        colorToVector4(hoverColor),
      );
    });

    test('being selected/hovered as a *different* residue has no effect', () {
      expect(resolve(hovered: other, selected: other), baseColor);
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
