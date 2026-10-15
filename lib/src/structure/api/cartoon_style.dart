import 'package:flutter/painting.dart';

/// Colors and surface effects for a protein cartoon.
///
/// Color precedence is hover, selection, highlight, then secondary structure.
/// Changing this style preserves geometry and camera position.
class CartoonStyle {
  const CartoonStyle({
    this.helixColor = const Color(0xFFD94040),
    this.sheetColor = const Color(0xFFE6CC33),
    this.loopColor = const Color(0xFFCCCCCC),
    this.hoverColor = const Color(0xFF00E5FF),
    this.selectionColor = const Color(0xFFFF6D00),
    this.outlineColor,
    this.outlineThickness = 0.05,
    this.pencilTexture = false,
  }) : assert(outlineThickness >= 0 && outlineThickness < double.infinity);

  final Color helixColor;
  final Color sheetColor;
  final Color loopColor;
  final Color hoverColor;
  final Color selectionColor;

  /// Null disables outlines.
  final Color? outlineColor;

  /// Outline expansion in ångströms. Must be finite and nonnegative.
  final double outlineThickness;
  final bool pencilTexture;

  @override
  bool operator ==(Object other) =>
      other is CartoonStyle &&
      helixColor == other.helixColor &&
      sheetColor == other.sheetColor &&
      loopColor == other.loopColor &&
      hoverColor == other.hoverColor &&
      selectionColor == other.selectionColor &&
      outlineColor == other.outlineColor &&
      outlineThickness == other.outlineThickness &&
      pencilTexture == other.pencilTexture;

  @override
  int get hashCode => Object.hash(
    helixColor,
    sheetColor,
    loopColor,
    hoverColor,
    selectionColor,
    outlineColor,
    outlineThickness,
    pencilTexture,
  );
}
