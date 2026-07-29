import "dart:convert";

import "package:flutter/foundation.dart";

import "constants.dart";

const int _maxClientLayers = 8;
const int _maxClientHeaderBytes = 256;

final RegExp _clientLayerNamePattern = RegExp(r"[a-z0-9-]{1,32}");
final RegExp _clientLayerVersionPattern = RegExp(r"[A-Za-z0-9.+-]{1,32}");
final List<_ClientLayer> _clientLayers = <_ClientLayer>[
  const _ClientLayer(name: "flutter-sdk", version: sdkVersion),
];

class _ClientLayer {
  const _ClientLayer({required this.name, required this.version});

  final String name;
  final String version;
}

void registerClientLayer({required String name, required String version}) {
  try {
    final alreadyRegistered = _clientLayers.any(
      (layer) => layer.name == name && layer.version == version,
    );
    if (alreadyRegistered) return;

    _clientLayers.add(_ClientLayer(name: name, version: version));
  } catch (_) {
    // Client provenance must never prevent a call.
  }
}

String? serializeClientLayers() {
  try {
    final seenNames = <String>{};
    final layers = <_ClientLayer>[];

    for (final layer in _clientLayers) {
      if (!_isFullMatch(_clientLayerNamePattern, layer.name) ||
          !_isFullMatch(_clientLayerVersionPattern, layer.version)) {
        continue;
      }
      if (!seenNames.add(layer.name)) continue;
      layers.add(layer);
    }

    final serialized = layers.reversed
        .map((layer) => "${layer.name}/${layer.version}")
        .toList();

    if (serialized.length > _maxClientLayers) {
      serialized.removeRange(0, serialized.length - _maxClientLayers);
    }

    while (serialized.isNotEmpty &&
        utf8.encode(serialized.join(" ")).length > _maxClientHeaderBytes) {
      serialized.removeAt(0);
    }

    return serialized.isEmpty ? null : serialized.join(" ");
  } catch (_) {
    return null;
  }
}

void ensureFlutterSdkClientLayerRegistered() {
  registerClientLayer(name: "flutter-sdk", version: sdkVersion);
}

@visibleForTesting
void resetClientLayersForTesting() {
  _clientLayers.clear();
}

bool _isFullMatch(RegExp pattern, String value) {
  final match = pattern.firstMatch(value);
  return match != null && match.start == 0 && match.end == value.length;
}
