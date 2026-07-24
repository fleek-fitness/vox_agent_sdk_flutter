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
    this.visitorId,
    this.dynamicVariables = const <String, Object?>{},
    this.metadata = const <String, Object?>{},
  });

  final String agentId;
  final String apiKey;
  final String? agentVersion;
  final bool? textOnly;

  /// Stable visitor identifier supplied by the host app.
  ///
  /// The SDK does not generate or persist this value on the device. If omitted,
  /// each session is attributed to a new anonymous Customer and Memory does not
  /// carry over. Pass the same stable value, such as a signed-in user ID or
  /// installation ID, on every session that needs Memory continuity.
  final String? visitorId;

  /// Agent prompt variables. Values must be String, num, or bool.
  ///
  /// Calling [Conversation.startSession] with any other value, including null,
  /// a Map, or a List, throws an [ArgumentError] before the token request.
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
