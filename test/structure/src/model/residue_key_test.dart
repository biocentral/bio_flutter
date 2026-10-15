import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/src/structure/model/residue.dart';
import 'package:bio_flutter/src/structure/model/residue_key.dart';

void main() {
  group('ResidueKey', () {
    test('two keys with the same chain and residue id are equal', () {
      expect(
        const ResidueKey('A', ResidueId(12, '')),
        const ResidueKey('A', ResidueId(12, '')),
      );
      expect(
        const ResidueKey('A', ResidueId(12, '')).hashCode,
        const ResidueKey('A', ResidueId(12, '')).hashCode,
      );
    });

    test(
      'a different chain makes keys unequal even with the same residue id',
      () {
        expect(
          const ResidueKey('A', ResidueId(12, '')),
          isNot(const ResidueKey('B', ResidueId(12, ''))),
        );
      },
    );

    test(
      'a different residue id makes keys unequal even with the same chain',
      () {
        expect(
          const ResidueKey('A', ResidueId(12, '')),
          isNot(const ResidueKey('A', ResidueId(13, ''))),
        );
        expect(
          const ResidueKey('A', ResidueId(12, '')),
          isNot(const ResidueKey('A', ResidueId(12, 'A'))),
        );
      },
    );

    test('usable as a Map key', () {
      final map = {const ResidueKey('A', ResidueId(1, '')): 'first'};
      expect(map[const ResidueKey('A', ResidueId(1, ''))], 'first');
    });
  });
}
