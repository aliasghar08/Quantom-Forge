// Platform-selected file picker.
//
// The real implementation uses `dart:js_interop` (a hidden file input plus
// FileReader), which only exists in the browser. It sits behind a conditional
// export so VM builds — `flutter test` — get the stub instead of failing to
// compile. Keep the class members in sync with `file_picker_service_stub.dart`,
// the same convention `web_services.dart` uses.
export 'file_picker_models.dart';
export 'file_picker_service_stub.dart'
    if (dart.library.js_interop) 'file_picker_service_web.dart';
