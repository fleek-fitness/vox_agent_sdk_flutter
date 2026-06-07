import "dart:typed_data";

enum ConversationStatus {
  disconnected,
  connecting,
  connected,
}

enum AgentState {
  initializing("initializing"),
  idle("idle"),
  listening("listening"),
  thinking("thinking"),
  speaking("speaking");

  const AgentState(this.value);

  final String value;

  static AgentState? fromValue(String? value) {
    if (value == null) return null;
    for (final state in AgentState.values) {
      if (state.value == value) return state;
    }
    return null;
  }
}

enum ConversationSource {
  agent,
  user,
  system,
}

class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.source,
    required this.text,
    required this.timestamp,
    required this.isFinal,
  });

  final String id;
  final ConversationSource source;
  final String text;
  final int timestamp;
  final bool isFinal;

  ConversationMessage copyWith({
    String? id,
    ConversationSource? source,
    String? text,
    int? timestamp,
    bool? isFinal,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      source: source ?? this.source,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
    );
  }
}

class StartSessionOptions {
  const StartSessionOptions({
    required this.agentId,
    required this.apiKey,
    this.agentVersion,
    this.textOnly,
    this.dynamicVariables = const <String, Object?>{},
    this.metadata = const <String, Object?>{},
  });

  final String agentId;
  final String apiKey;
  final String? agentVersion;
  final bool? textOnly;
  final Map<String, Object?> dynamicVariables;
  final Map<String, Object?> metadata;
}

class InputDeviceConfig {
  const InputDeviceConfig({
    required this.inputDeviceId,
  });

  final String inputDeviceId;
}

class OutputDeviceConfig {
  const OutputDeviceConfig({
    required this.outputDeviceId,
  });

  final String outputDeviceId;
}

class SetVolumeParams {
  const SetVolumeParams({
    required this.volume,
  });

  final double volume;
}

typedef ConversationConnectCallback = void Function();
typedef ConversationDisconnectCallback = void Function();
typedef ConversationErrorCallback = void Function(Exception error);
typedef ConversationMessageCallback = void Function(ConversationMessage message);
typedef ConversationStatusCallback = void Function(ConversationStatus status);
typedef ConversationAgentStateCallback = void Function(AgentState agentState);

typedef FrequencyData = Uint8List;
