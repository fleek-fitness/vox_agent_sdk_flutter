import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:vox_ai_flutter/src/client_layers.dart";

void main() {
  final vectors =
      jsonDecode(
            File("conformance/x-vox-client.vectors.json").readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = vectors["cases"] as List<dynamic>;

  for (final rawCase in cases) {
    final testCase = rawCase as Map<String, dynamic>;

    test("X-Vox-Client conformance: ${testCase["name"]}", () {
      resetClientLayersForTesting();

      for (final rawLayer in testCase["register"] as List<dynamic>) {
        final layer = rawLayer as Map<String, dynamic>;
        registerClientLayer(
          name: layer["name"] as String,
          version: layer["version"] as String,
        );
      }

      expect(serializeClientLayers(), testCase["header"]);
    });
  }
}
