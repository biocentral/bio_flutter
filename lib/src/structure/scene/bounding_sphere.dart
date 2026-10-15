import 'package:vector_math/vector_math.dart';

import '../model/molecular_structure.dart';

/// A center + radius sphere containing every atom in a structure, for
/// initial camera framing.
class BoundingSphere {
  const BoundingSphere({required this.center, required this.radius});

  final Vector3 center;
  final double radius;

  /// Radius used when there are no atoms or all atoms coincide.
  static const double fallbackRadius = 50.0;

  factory BoundingSphere.of(MolecularStructure structure) {
    final List<Vector3> positions = [
      for (final atom in structure.atoms) atom.position,
    ];
    if (positions.isEmpty) {
      return BoundingSphere(center: Vector3.zero(), radius: fallbackRadius);
    }

    final Vector3 sum = positions.fold(Vector3.zero(), (acc, p) => acc + p);
    final Vector3 center = sum.scaled(1 / positions.length);

    double radius = 0;
    for (final Vector3 p in positions) {
      final double d = p.distanceTo(center);
      if (d > radius) radius = d;
    }

    return BoundingSphere(
      center: center,
      radius: radius == 0 ? fallbackRadius : radius,
    );
  }
}
