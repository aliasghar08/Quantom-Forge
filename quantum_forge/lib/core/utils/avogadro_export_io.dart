import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AvogadroExporter {
  static Future<void> exportForAvogadro(String filename, String xyzData) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(xyzData);
  }
}
