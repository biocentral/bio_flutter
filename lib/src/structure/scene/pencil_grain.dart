import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

/// Resolution of the generated tileable texture.
const int _grainSize = 256;

/// Value-noise frequencies, from coarse to fine.
const List<int> _octaveFrequencies = [4, 8, 16, 32, 64];

/// Integer wavevectors for the two hatch layers.
const (int kx, int ky) _primaryHatch = (48, 40);
const (int kx, int ky) _crossHatch = (40, -48);

/// Warp amplitude for hatch coordinates, in texels.
const double _warpAmplitude = 7.0;

/// Cached texture shared by all cartoon meshes in this isolate.
Texture2D? _cached;

/// Creates a cached tileable grayscale texture from noise, hatching, and speckles.
///
/// Requires initialized Scene resources.
Texture2D pencilGrainTexture() {
  final Texture2D? cached = _cached;
  if (cached != null) return cached;

  final math.Random rng = math.Random(
    1337,
  ); // fixed seed: a stable look across runs, not a fresh grain every launch
  final Map<int, List<List<double>>> octaveGrids = {
    for (final freq in _octaveFrequencies) freq: _randomGrid(freq, rng),
  };

  // Independent grids for the warp/fade/speckle layers -- deliberately not
  // reused from `octaveGrids`, so none of these layers visibly lines up
  // with the base grain or with each other (shared grids would correlate
  // them, reintroducing a different kind of regularity).
  const int warpFreq = 16;
  final List<List<double>> warpXGrid = _randomGrid(warpFreq, rng);
  final List<List<double>> warpYGrid = _randomGrid(warpFreq, rng);
  const int fadeFreq = 4;
  final List<List<double>> primaryFadeGrid = _randomGrid(fadeFreq, rng);
  final List<List<double>> crossFadeGrid = _randomGrid(fadeFreq, rng);
  const int speckleFreq = 64;
  final List<List<double>> speckleGrid = _randomGrid(speckleFreq, rng);

  final Uint8List pixels = Uint8List(_grainSize * _grainSize * 4);
  for (int y = 0; y < _grainSize; y++) {
    for (int x = 0; x < _grainSize; x++) {
      final double noise = _tileableNoise(x, y, octaveGrids);

      final double warpX =
          (_sampleGrid(
                warpXGrid,
                warpFreq,
                x * warpFreq / _grainSize,
                y * warpFreq / _grainSize,
              ) -
              0.5) *
          2 *
          _warpAmplitude;
      final double warpY =
          (_sampleGrid(
                warpYGrid,
                warpFreq,
                x * warpFreq / _grainSize,
                y * warpFreq / _grainSize,
              ) -
              0.5) *
          2 *
          _warpAmplitude;
      final double wx = x + warpX;
      final double wy = y + warpY;

      final double primaryFade = _sampleGrid(
        primaryFadeGrid,
        fadeFreq,
        x * fadeFreq / _grainSize,
        y * fadeFreq / _grainSize,
      );
      final double crossFade = _sampleGrid(
        crossFadeGrid,
        fadeFreq,
        x * fadeFreq / _grainSize,
        y * fadeFreq / _grainSize,
      );
      final double primaryLine =
          _hatchLine(wx, wy, _primaryHatch.$1, _primaryHatch.$2) * primaryFade;
      final double crossLine =
          _hatchLine(wx, wy, _crossHatch.$1, _crossHatch.$2) * crossFade;

      final double speckleRaw = _sampleGrid(
        speckleGrid,
        speckleFreq,
        x * speckleFreq / _grainSize,
        y * speckleFreq / _grainSize,
      );
      final double speckle = ((speckleRaw - 0.8) / 0.2).clamp(0.0, 1.0);

      double lum =
          0.90 +
          (noise - 0.5) * 0.14 -
          primaryLine * 0.10 -
          crossLine * 0.05 -
          speckle * 0.15;
      lum = lum.clamp(0.0, 1.0);

      final int value = (lum * 255).round();
      final int i = (y * _grainSize + x) * 4;
      pixels[i] = value;
      pixels[i + 1] = value;
      pixels[i + 2] = value;
      pixels[i + 3] = 255;
    }
  }

  final Texture2D texture = Texture2D.fromPixels(
    pixels,
    _grainSize,
    _grainSize,
  );
  _cached = texture;
  return texture;
}

/// One octave's random grid: [freq] x [freq] independent samples in
/// `[0, 1)`, bilinearly sampled (with wraparound) by [_sampleGrid].
List<List<double>> _randomGrid(int freq, math.Random rng) =>
    List.generate(freq, (_) => List.generate(freq, (_) => rng.nextDouble()));

/// Bilinear lookup into [grid] (a [freq] x [freq] [_randomGrid]) at
/// fractional grid coordinates ([gx], [gy]), wrapping at the grid's own
/// edges — the wraparound (not a clamp) is what makes the *sampled* noise
/// tile seamlessly once [gx]/[gy] complete a full cycle of the texture.
double _sampleGrid(List<List<double>> grid, int freq, double gx, double gy) {
  final int x0 = gx.floor() % freq;
  final int y0 = gy.floor() % freq;
  final int x1 = (x0 + 1) % freq;
  final int y1 = (y0 + 1) % freq;
  final double fx = gx - gx.floor();
  final double fy = gy - gy.floor();
  final double top = grid[y0][x0] * (1 - fx) + grid[y0][x1] * fx;
  final double bottom = grid[y1][x0] * (1 - fx) + grid[y1][x1] * fx;
  return top * (1 - fy) + bottom * fy;
}

/// Multi-octave (coarse-to-fine, halving amplitude each step) tileable
/// value noise at pixel ([x], [y]), normalized back to `[0, 1]`.
double _tileableNoise(int x, int y, Map<int, List<List<double>>> grids) {
  double sum = 0;
  double amplitude = 0.5;
  double totalAmplitude = 0;
  for (final freq in _octaveFrequencies) {
    final double gx = x * freq / _grainSize;
    final double gy = y * freq / _grainSize;
    sum += _sampleGrid(grids[freq]!, freq, gx, gy) * amplitude;
    totalAmplitude += amplitude;
    amplitude *= 0.5;
  }
  return sum / totalAmplitude;
}

/// A thin bright ridge (`~1.0`) along evenly-spaced parallel lines running
/// perpendicular to wavevector `(kx, ky)`, `~0.0` everywhere else, sampled
/// at ([x], [y]) — pass warped (non-integer, noise-perturbed) coordinates,
/// not raw pixel indices, to bend the lines off dead-straight (see
/// [pencilGrainTexture]'s [_warpAmplitude] use). [kx]/[ky] are whole
/// cycles across the texture, so the *un-warped* pattern this perturbs
/// tiles exactly at the texture's edges regardless of [_grainSize].
/// Raising the raised-cosine to a high power narrows the bright band from
/// a smooth wave into a crisp stroke, closer to a single pencil line than
/// a soft sinusoidal band.
double _hatchLine(double x, double y, int kx, int ky) {
  final double phase =
      2 * math.pi * (kx * x / _grainSize + ky * y / _grainSize);
  final double raised = 0.5 + 0.5 * math.sin(phase);
  return math.pow(raised, 24).toDouble();
}
