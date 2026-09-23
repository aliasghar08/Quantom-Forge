// ============================================================================
// NGL engine — platform selector
// ----------------------------------------------------------------------------
// `NglEngine` is the only object in the app that talks to ngl.js. It is swapped
// per platform the same way `avogadro_bridge.dart` and `local_storage_service.dart`
// are: a stub for everything that is not web, and a `dart:js_interop`
// implementation for the browser.
//
// The web implementation is the only file in this folder that may import
// `dart:ui_web` or `package:web`. Keep it that way — a stray web-only import on
// the shared side is what broke the offline builds in the first place.
//
// Contract for implementers, because both branches must agree exactly:
//
//   static bool  isSupported          — can a real WebGL stage be created?
//   static String viewType            — platform-view type name
//   static void  ensureViewFactory()  — register the view factory, idempotent
//   static NglEngine? forView(int)    — adopt the engine created for a view id
//   bool  get hasStage                — stage created and usable
//   void  setGeometry(ReactionFrameGeometry, {bool resetView})
//   void  resetView()
//   void  handleResize()
//   void  dispose()
// ============================================================================

export 'ngl_engine_stub.dart'
    if (dart.library.js_interop) 'ngl_engine_web.dart';
