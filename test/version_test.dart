import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:vox_ai_flutter/src/constants.dart";

void main() {
  test("sdkVersion matches pubspec.yaml", () {
    final pubspec = File("pubspec.yaml").readAsStringSync();
    final match = RegExp(
      r"^version:\s*(\S+)\s*$",
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(sdkVersion, match!.group(1));
  });
}
