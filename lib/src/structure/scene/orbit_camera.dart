import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

// The constructor deliberately assigns public-named params to private
// fields in its body rather than via `this._target` initializing formals:
// an initializing formal's external argument name has to match the field
// name exactly, which would force callers to write the private name
// (`_target:`) — not usable outside this library.
// ignore_for_file: prefer_initializing_formals

/// An orbit camera with rotation, zoom, and camera-relative panning.
class OrbitCameraController extends ChangeNotifier {
  OrbitCameraController({
    required Vector3 target,
    double distance = 30,
    double yaw = 0,
    double pitch = 0.3,
  }) : _target = target,
       _distance = distance,
       _yaw = yaw,
       _pitch = pitch;

  Vector3 _target;
  double _distance;
  double _yaw;
  double _pitch;

  static const double _minDistance = 2.0;
  static const double _maxDistance = 100000.0;
  static const double _maxPitch = math.pi / 2 - 0.01;

  void orbit(double deltaYaw, double deltaPitch) {
    _yaw += deltaYaw;
    _pitch = _pitch.clamp(-_maxPitch, _maxPitch) + deltaPitch;
    _pitch = _pitch.clamp(-_maxPitch, _maxPitch);
    notifyListeners();
  }

  void zoom(double factor) {
    if (!factor.isFinite || factor <= 0) return;
    _distance = (_distance * factor).clamp(_minDistance, _maxDistance);
    notifyListeners();
  }

  void reset({required Vector3 target, required double distance}) {
    _yaw = 0;
    _pitch = 0.3;
    focusOn(target: target, distance: distance);
  }

  void pan(double dx, double dy, double viewportHeight) {
    if (viewportHeight <= 0) return;
    final right = Vector3(math.cos(_yaw), 0, -math.sin(_yaw));
    final up = Vector3(
      -math.sin(_pitch) * math.sin(_yaw),
      math.cos(_pitch),
      -math.sin(_pitch) * math.cos(_yaw),
    );
    _target += (right * -dx + up * dy) * (_distance / viewportHeight);
    notifyListeners();
  }

  /// Re-centers the camera on a new [target]/[distance] — used when a new
  /// structure is loaded, so the view frames it rather than wherever the
  /// previous structure happened to leave the camera.
  void focusOn({required Vector3 target, required double distance}) {
    _target = target;
    _distance = distance.clamp(_minDistance, _maxDistance);
    notifyListeners();
  }

  PerspectiveCamera buildCamera() {
    final double cosPitch = math.cos(_pitch);
    final Vector3 offset = Vector3(
      _distance * cosPitch * math.sin(_yaw),
      _distance * math.sin(_pitch),
      _distance * cosPitch * math.cos(_yaw),
    );
    return PerspectiveCamera(position: _target + offset, target: _target);
  }
}
