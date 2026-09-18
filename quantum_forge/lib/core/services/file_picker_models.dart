import 'dart:typed_data';

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
