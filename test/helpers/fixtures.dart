import 'dart:convert';
import 'dart:io';

/// Reads a fixture file's raw text content from `test/fixtures/`.
///
/// [name] is the file name only, e.g. `overpass_beaches_response.json`.
String loadFixtureString(String name) {
  return File('test/fixtures/$name').readAsStringSync();
}

/// Reads and JSON-decodes a fixture file from `test/fixtures/`.
dynamic loadFixtureJson(String name) {
  return json.decode(loadFixtureString(name));
}
