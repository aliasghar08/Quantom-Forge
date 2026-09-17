// ============================================================================
// FilePickerService — Clean wrapper around the file_picker package.
//
// Why wrap file_picker?
//  • UI code never imports file_picker directly → easy to stub in tests
//  • Returns a typed [PickedFile] instead of exposing PlatformFile internals
//  • Centralises allowed extensions and error handling
// ============================================================================

import 'dart:typed_data';
import 'dart:io';
import 'package:quantum_forge/core/utils/win32_file_picker.dart';

/// Represents a user-selected file, decoupled from PlatformFile.
class PickedFile {
  final String name;
  final String? path;
  final Uint8List? bytes;
  final int size;

  const PickedFile({
    required this.name,
    this.path,
    this.bytes,
    required this.size,
  });

  bool get hasData => bytes != null || path != null;
}

class FilePickerService {


  /// Pick a single molecular structure file (.xyz / .pdb / .mol / .sdf / .cif).
  /// Returns null if the user cancels.
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

  /// Pick any file (for export / import of settings or results).
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
