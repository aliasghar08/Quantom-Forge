// Non-web implementation of the file picker.
//
// `flutter test` runs on the Dart VM, where there is no `document`/`FileReader`.
// `file_picker_service.dart` previously exported the web implementation
// unconditionally, so ANY file that imported it — even transitively — failed to
// compile off-web. That is why a widget test could not import a widget that used
// the picker. This stub keeps every screen testable; a real pick needs a browser.
import 'file_picker_models.dart';

class FilePickerService {
  /// No file system dialog off the web.
  Future<PickedFile?> pickStructureFile() async => null;

  /// No file system dialog off the web.
  Future<PickedFile?> pickAnyFile() async => null;
}
