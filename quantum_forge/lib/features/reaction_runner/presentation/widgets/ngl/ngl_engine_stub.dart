// ============================================================================
// NGL engine — non-web stub
// ----------------------------------------------------------------------------
// Used by `flutter test`, and by any desktop/mobile build. There is no WebGL
// stage, so every call is a no-op and `isSupported` is false — which is what
// makes `NglViewer` render its explanatory fallback instead of a blank hole.
//
// This file exists so the reaction animation stays compilable and testable off
// the web: `ngl_engine_web.dart` is the only file allowed to import
// `dart:ui_web` or `package:web`.
// ============================================================================

import 'ngl_bond_label.dart';
import 'ngl_style.dart';

/// No-op stand-in for the browser NGL bridge.
class NglEngine {
  NglEngine._();

  /// Always false: there is no WebGL stage off the web.
  static bool get isSupported => false;

  /// Platform-view type name. Shared with the web implementation so the
  /// `HtmlElementView` in `ngl_viewer.dart` names the same view on both sides.
  static String get viewType => 'quantum-forge-ngl-viewer';

  /// No factory to register.
  static void ensureViewFactory() {}

  /// No engine is ever created, so no view id resolves to one.
  static NglEngine? forView(int viewId) => null;

  /// Never a usable stage.
  bool get hasStage => false;

  /// Loads a multi-model SDF trajectory for scrubbing. No-op.
  Future<void> loadTrajectory(
    String sdf,
    NglStyle style, {
    bool resetView = true,
  }) async {}

  /// Loads a single-model SDF, replacing the previous structure. No-op.
  Future<void> loadFrame(String sdf, NglStyle style) async {}

  /// Loads a remote PDB/DCD MD trajectory. No-op on non-web targets.
  Future<void> loadRemoteMd(
    String pdbUrl,
    String dcdUrl,
    NglStyle style, {
    bool resetView = true,
  }) async {}

  /// Moves the trajectory to an absolute 0-based frame. No-op.
  void setFrame(int frame) {}

  /// Rebuilds the representation for a new display type or palette. No-op.
  void applyStyle(NglStyle style) {}

  /// Draws numbered badges at bond midpoints. No-op.
  void setBondLabels(List<BondLabel> labels) {}

  /// Fits the camera to the current structure. No-op.
  void resetView() {}

  /// Re-measures the canvas. No-op.
  void handleResize() {}

  /// The viewer orientation matrix, for the axes triad. Always null here.
  List<double>? cameraOrientation() => null;

  void dispose() {}
}
