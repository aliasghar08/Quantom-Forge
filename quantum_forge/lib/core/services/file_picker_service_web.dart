// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'file_picker_models.dart';

class FilePickerService {
  Future<PickedFile?> pickStructureFile() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.xyz,.mol,.sdf,.cml';
    uploadInput.click();

    return _getFileFromInput(uploadInput);
  }

  Future<PickedFile?> pickAnyFile() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.click();
    return _getFileFromInput(uploadInput);
  }
  
  Future<PickedFile?> _getFileFromInput(html.FileUploadInputElement uploadInput) async {
    final completer = Completer<PickedFile?>();
    
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        
        reader.onLoadEnd.listen((e) {
          final result = reader.result;
          if (result != null) {
            Uint8List bytes;
            if (result is String) {
               bytes = Uint8List.fromList(result.codeUnits);
            } else {
               bytes = result as Uint8List;
            }
            completer.complete(PickedFile(name: file.name, size: file.size, bytes: bytes));
          } else {
            completer.complete(null);
          }
        });
        reader.readAsArrayBuffer(file);
      } else {
        completer.complete(null);
      }
    });
    
    return completer.future;
  }
}
