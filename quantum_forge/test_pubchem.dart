import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  final q = 'caff';
  final uri = 'https://pubchem.ncbi.nlm.nih.gov/rest/autocomplete/compound/$q/json?limit=8';
  final request = await HttpClient().getUrl(Uri.parse(uri));
  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  debugPrint(responseBody);
}
