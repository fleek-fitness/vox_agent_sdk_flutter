import "package:flutter_test/flutter_test.dart";
import "package:vox_ai_flutter/src/client_layers.dart";
import "package:vox_ai_flutter/src/constants.dart";

void main() {
  test("flutter SDK registers before the first app layer", () {
    registerClientLayer(name: "app-shell", version: "1.0.0");

    expect(serializeClientLayers(), "app-shell/1.0.0 flutter-sdk/$sdkVersion");
  });
}
