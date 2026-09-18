import 'dart:io';
import 'package:quantum_forge/core/utils/win32_file_picker.dart';
import 'file_picker_models.dart';

class FilePickerService {
  Future<PickedFile?> pickStructureFile() async {
    final path = Win32FilePicker.pickFile(title: 'Select Chemical Structure');
    
    if (path == null) return null;
    
    final file = File(path);
    if (!await file.exists()) return null;
    
    final name = path.split('\\').last;
    final size = await file.length();
    final bytes = await file.readAsBytes();

    return PickedFile(
      name: name,
      path: path,
      bytes: bytes,
      size: size,
    );
  }

  Future<PickedFile?> pickAnyFile() async {
    final path = Win32FilePicker.pickFile(title: 'Select File');
    if (path == null) return null;
    
    final file = File(path);
    if (!await file.exists()) return null;
    
    final name = path.split('\\').last;
    final size = await file.length();
    final bytes = await file.readAsBytes();

    return PickedFile(
      name: name,
      path: path,
      bytes: bytes,
      size: size,
    );
  }
}
