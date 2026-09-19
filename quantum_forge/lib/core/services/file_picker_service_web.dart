import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'file_picker_models.dart';

@JS('document')
external JSObject get _document;

@JS('FileReader')
external JSFunction get _fileReaderConstructor;

@JS()
@staticInterop
class FileReader {}

extension FileReaderExt on FileReader {
  @JS('readAsArrayBuffer')
  external void readAsArrayBuffer(JSObject blob);

  @JS('addEventListener')
  external void addEventListener(JSString type, JSExportedDartFunction listener);

  @JS('result')
  external JSArrayBuffer get result;
}

class FilePickerService {
  Future<PickedFile?> pickStructureFile() async {
    final uploadInput = _document.callMethod('createElement'.toJS, 'input'.toJS) as JSObject;
    uploadInput.setProperty('type'.toJS, 'file'.toJS);
    // CJSON is Avogadro 2's native format — offer it alongside the classics.
    uploadInput.setProperty('accept'.toJS, '.xyz,.cjson,.mol,.sdf,.cml'.toJS);
    uploadInput.callMethod('click'.toJS);

    return _getFileFromInput(uploadInput);
  }

  Future<PickedFile?> pickAnyFile() async {
    final uploadInput = _document.callMethod('createElement'.toJS, 'input'.toJS) as JSObject;
    uploadInput.setProperty('type'.toJS, 'file'.toJS);
    uploadInput.callMethod('click'.toJS);
    return _getFileFromInput(uploadInput);
  }
  
  Future<PickedFile?> _getFileFromInput(JSObject uploadInput) async {
    final completer = Completer<PickedFile?>();
    
    final onChange = (JSAny event) {
      final files = uploadInput.getProperty('files'.toJS) as JSObject?;
      final length = files?.getProperty('length'.toJS) as JSNumber?;
      
      if (length != null && length.toDartInt > 0) {
        final file = files!.callMethod('item'.toJS, 0.toJS) as JSObject;
        final name = (file.getProperty('name'.toJS) as JSString).toDart;
        final size = (file.getProperty('size'.toJS) as JSNumber).toDartInt;
        
        final reader = _fileReaderConstructor.callAsConstructor<FileReader>();
        
        final onLoadEnd = (JSAny event) {
          final buffer = reader.result.toDart;
          completer.complete(PickedFile(name: name, size: size, bytes: buffer.asUint8List()));
        }.toJS;

        reader.addEventListener('loadend'.toJS, onLoadEnd);
        reader.readAsArrayBuffer(file);
      } else {
        completer.complete(null);
      }
    }.toJS;

    uploadInput.callMethod('addEventListener'.toJS, 'change'.toJS, onChange);
    
    return completer.future;
  }
}
