import 'package:vector_math/vector_math.dart';

/// Estimates a local helix axis from a smoothed Cα trace.
///
/// Returns one vector per position. A zero vector indicates insufficient
/// local curvature. Keep [smoothingWindow] small relative to the helix pitch.
List<Vector3> helixAxisDirectionVectors(
  List<Vector3> positions, {
  int smoothingWindow = 1,
}) {
  final int n = positions.length;
  if (n < 2) return [for (final _ in positions) Vector3.zero()];

  // A light moving-average pass first, so the curvature vector tracks the
  // helix's overall coil rather than per-residue positional noise/wobble.
  final List<Vector3> smoothed = [
    for (int i = 0; i < n; i++) _windowAverage(positions, i, smoothingWindow),
  ];

  final List<Vector3> directions = [];
  for (int i = 0; i < n; i++) {
    final Vector3 prev = smoothed[i == 0 ? 0 : i - 1];
    final Vector3 next = smoothed[i == n - 1 ? n - 1 : i + 1];
    final Vector3 raw = (prev + next) * 0.5 - smoothed[i];
    directions.add(raw.length2 > 1e-10 ? raw.normalized() : Vector3.zero());
  }
  return directions;
}

Vector3 _windowAverage(List<Vector3> positions, int center, int window) {
  final int n = positions.length;
  final int lo = (center - window).clamp(0, n - 1);
  final int hi = (center + window).clamp(0, n - 1);
  final Vector3 sum = Vector3.zero();
  int count = 0;
  for (int i = lo; i <= hi; i++) {
    sum.add(positions[i]);
    count++;
  }
  return sum * (1.0 / count);
}
