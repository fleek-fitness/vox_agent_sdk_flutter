import "dart:async";
import "dart:convert";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;
import "package:livekit_client/livekit_client.dart";

import "constants.dart";
import "types.dart";

class _ConnectionDetails {
  const _ConnectionDetails({
    required this.serverUrl,
    required this.roomName,
    required this.participantName,
    required this.participantToken,
  });

  factory _ConnectionDetails.fromJson(Map<String, dynamic> json) {
    return _ConnectionDetails(
      serverUrl: json["serverUrl"] as String,
      roomName: json["roomName"] as String,
      participantName: json["participantName"] as String,
      participantToken: json["participantToken"] as String,
    );
  }

  final String serverUrl;
  final String roomName;
  final String participantName;
  final String participantToken;
}

class _LegacyChatPayload {
  const _LegacyChatPayload({
    required this.id,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final String message;
  final int timestamp;
}

class Conversation extends ChangeNotifier {
  Conversation({
    this.textOnly = false,
    this.onConnect,
    this.onDisconnect,
    this.onError,
    this.onMessage,
    this.onStatusChange,
    this.onModeChange,
  });

  final bool textOnly;
  final ConversationConnectCallback? onConnect;
  final ConversationDisconnectCallback? onDisconnect;
  final ConversationErrorCallback? onError;
  final ConversationMessageCallback? onMessage;
  final ConversationStatusCallback? onStatusChange;
  final ConversationModeCallback? onModeChange;

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  _ConnectionDetails? _connectionDetails;
  bool _textOnlySession = false;
  bool _disconnectEmitted = false;
  bool _disposed = false;
  double _outputVolumeSetting = 1;
  Timer? _audioTimer;

  ConversationStatus _status = ConversationStatus.disconnected;
  ConversationMode _mode = ConversationMode.listening;
  bool _micMuted = true;
  double _inputVolume = 0;
  double _outputVolume = 0;
  Uint8List _inputFrequencyData = Uint8List(0);
  Uint8List _outputFrequencyData = Uint8List(0);
  final Map<String, ConversationMessage> _messageMap =
      <String, ConversationMessage>{};
  List<ConversationMessage> _messages = const <ConversationMessage>[];

  ConversationStatus get status => _status;
  ConversationMode get mode => _mode;
  bool get isSpeaking => _mode == ConversationMode.speaking;
  bool get micMuted => _micMuted;
  List<ConversationMessage> get messages =>
      List<ConversationMessage>.unmodifiable(_messages);

  Future<String> startSession(StartSessionOptions options) async {
    if (_room != null) {
      await endSession();
    }

    _textOnlySession = options.textOnly ?? textOnly;
    _disconnectEmitted = false;
    _messageMap.clear();
    _messages = const <ConversationMessage>[];
    _inputVolume = 0;
    _outputVolume = 0;
    _inputFrequencyData = Uint8List(0);
    _outputFrequencyData = Uint8List(0);
    _outputVolumeSetting = 1;
    _micMuted = true;
    _updateMode(ConversationMode.listening);
    _updateStatus(ConversationStatus.connecting);

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ),
    );
    final listener = room.createListener();
    _room = room;
    _listener = listener;

    try {
      _connectionDetails = await _fetchConnectionDetails(options);
      _bindRoomEvents(room, listener);

      await room.connect(
        _connectionDetails!.serverUrl,
        _connectionDetails!.participantToken,
      );

      if (_textOnlySession) {
        _micMuted = true;
      } else {
        await room.localParticipant?.setMicrophoneEnabled(true);
        _micMuted = false;
      }

      _startAudioSampling();
      _updateStatus(ConversationStatus.connected);
      _emitConnect();

      return _connectionDetails!.roomName;
    } catch (error) {
      await _teardownRoom(emitDisconnect: false, preserveConnectionDetails: false);
      _emitError(error);
      rethrow;
    }
  }

  Future<void> endSession() async {
    if (_room == null) {
      _updateStatus(ConversationStatus.disconnected);
      return;
    }

    await _teardownRoom(emitDisconnect: true, preserveConnectionDetails: true);
  }

  String? getId() {
    return _connectionDetails?.roomName;
  }

  List<ConversationMessage> getMessages() {
    return List<ConversationMessage>.unmodifiable(_messages);
  }

  void setVolume(SetVolumeParams params) {
    if (_textOnlySession) return;
    _outputVolumeSetting = params.volume.clamp(0, 1).toDouble();
  }

  Future<void> setMicMuted(bool isMuted) async {
    if (_textOnlySession) {
      _micMuted = true;
      _notifyListeners();
      return;
    }

    final room = _room;
    if (room == null) return;

    final previous = _micMuted;
    _micMuted = isMuted;
    _notifyListeners();

    try {
      await room.localParticipant?.setMicrophoneEnabled(!isMuted);
    } catch (error) {
      _micMuted = previous;
      _notifyListeners();
      rethrow;
    }
  }

  Future<void> sendUserMessage(String text) async {
    final room = _room;
    final participant = room?.localParticipant;
    final trimmed = text.trim();
    if (room == null || participant == null || trimmed.isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final messageId = "user-$timestamp";

    await participant.sendText(
      trimmed,
      options: SendTextOptions(topic: liveKitChatTopic),
    );

    try {
      await participant.publishData(
        utf8.encode(
          jsonEncode(<String, Object?>{
            "id": messageId,
            "timestamp": timestamp,
            "message": trimmed,
            "ignoreLegacy": true,
          }),
        ),
        reliable: true,
        topic: liveKitLegacyChatTopic,
      );
    } catch (_) {
      // Text stream delivery is the primary path.
    }

    _pushMessage(
      ConversationMessage(
        id: messageId,
        source: ConversationSource.user,
        text: trimmed,
        timestamp: timestamp,
        isFinal: true,
      ),
    );
  }

  Future<bool> changeInputDevice(InputDeviceConfig config) async {
    final room = _room;
    if (_textOnlySession || room == null || lkPlatformIsMobile()) {
      return false;
    }

    final devices = await Hardware.instance.audioInputs();
    final device = devices
        .where((item) => item.deviceId == config.inputDeviceId)
        .cast<MediaDevice?>()
        .firstOrNull;

    if (device == null) return false;

    try {
      await room.setAudioInputDevice(device);
      return room.selectedAudioInputDeviceId == device.deviceId;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeOutputDevice(OutputDeviceConfig config) async {
    final room = _room;
    if (_textOnlySession || room == null || lkPlatformIsMobile()) {
      return false;
    }

    final devices = await Hardware.instance.audioOutputs();
    final device = devices
        .where((item) => item.deviceId == config.outputDeviceId)
        .cast<MediaDevice?>()
        .firstOrNull;

    if (device == null) return false;

    try {
      await room.setAudioOutputDevice(device);
      return room.selectedAudioOutputDeviceId == device.deviceId;
    } catch (_) {
      return false;
    }
  }

  double getInputVolume() {
    return _inputVolume;
  }

  double getOutputVolume() {
    return (_outputVolume * _outputVolumeSetting).clamp(0, 1).toDouble();
  }

  Uint8List getInputByteFrequencyData() {
    return Uint8List.fromList(_inputFrequencyData);
  }

  Uint8List getOutputByteFrequencyData() {
    return Uint8List.fromList(_outputFrequencyData);
  }

  Future<_ConnectionDetails> _fetchConnectionDetails(
    StartSessionOptions options,
  ) async {
    final mode = _textOnlySession ? "chat" : "call";
    final payload = <String, dynamic>{
      "agent_id": options.agentId,
      "agent_version": options.agentVersion ?? "current",
      "mode": mode,
      "dynamic_variables": options.dynamicVariables,
      "metadata": <String, dynamic>{
        "runtime_context": <String, dynamic>{
          "source": <String, dynamic>{
            "type": "react-sdk",
            "version": sdkVersion,
          },
          "mode": mode,
        },
        "call_web": <String, dynamic>{
          "dynamic_variables": options.dynamicVariables,
          "metadata": options.metadata,
        },
      },
    };

    final response = await http.post(
      Uri.parse(liveKitTokenEndpoint),
      headers: <String, String>{
        "Authorization": "Bearer ${options.apiKey}",
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        "Session initialization failed (${response.statusCode}): ${response.body}",
      );
    }

    return _ConnectionDetails.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _bindRoomEvents(Room room, EventsListener<RoomEvent> listener) {
    if (_textOnlySession) {
      room.registerTextStreamHandler(
        liveKitTranscriptionTopic,
        (reader, participantIdentity) {
          unawaited(
            _handleTextOnlyTranscription(reader, participantIdentity),
          );
        },
      );
    }

    listener
      ..on<RoomConnectedEvent>((_) {
        _updateStatus(ConversationStatus.connected);
      })
      ..on<RoomReconnectingEvent>((_) {
        _updateStatus(ConversationStatus.connecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        _updateStatus(ConversationStatus.connected);
      })
      ..on<RoomDisconnectedEvent>((_) {
        unawaited(
          _teardownRoom(
            emitDisconnect: true,
            preserveConnectionDetails: true,
          ),
        );
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        if (_textOnlySession) return;
        final hasRemoteSpeaker =
            event.speakers.any((speaker) => speaker is! LocalParticipant);
        _updateMode(
          hasRemoteSpeaker
              ? ConversationMode.speaking
              : ConversationMode.listening,
        );
      })
      ..on<TranscriptionEvent>((event) {
        final source = event.participant is LocalParticipant
            ? ConversationSource.user
            : ConversationSource.agent;

        for (final segment in event.segments) {
          _pushMessage(
            ConversationMessage(
              id: segment.id,
              source: source,
              text: segment.text,
              timestamp: segment.lastReceivedTime.millisecondsSinceEpoch,
              isFinal: segment.isFinal,
            ),
          );
        }
      })
      ..on<DataReceivedEvent>((event) {
        final payload = _decodeLegacyChatPayload(event.data);
        if (payload == null) return;

        _pushMessage(
          ConversationMessage(
            id: payload.id,
            source: ConversationSource.agent,
            text: payload.message,
            timestamp: payload.timestamp,
            isFinal: true,
          ),
        );
      });
  }

  Future<void> _handleTextOnlyTranscription(
    TextStreamReader reader,
    String participantIdentity,
  ) async {
    final info = reader.info;
    final source = participantIdentity == _room?.localParticipant?.identity
        ? ConversationSource.user
        : ConversationSource.agent;
    final messageId = info?.attributes["lk.segment_id"] ??
        info?.id ??
        "segment-${DateTime.now().microsecondsSinceEpoch}";
    final timestamp =
        info?.timestamp ?? DateTime.now().millisecondsSinceEpoch;
    var latestText = "";

    if (source == ConversationSource.agent) {
      _updateMode(ConversationMode.speaking);
    }

    try {
      await for (final chunk
          in reader.map((item) => utf8.decode(item.content, allowMalformed: true))) {
        latestText = chunk;
        _pushMessage(
          ConversationMessage(
            id: messageId,
            source: source,
            text: chunk,
            timestamp: timestamp,
            isFinal: false,
          ),
        );
      }

      if (latestText.isNotEmpty) {
        _pushMessage(
          ConversationMessage(
            id: messageId,
            source: source,
            text: latestText,
            timestamp: timestamp,
            isFinal: true,
          ),
        );
      }
    } catch (error) {
      _emitError(error);
    } finally {
      if (source == ConversationSource.agent) {
        _updateMode(ConversationMode.listening);
      }
    }
  }

  void _startAudioSampling() {
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final room = _room;
      if (room == null) return;

      final localLevel = room.localParticipant?.audioLevel ?? 0;
      final remoteLevel = room.remoteParticipants.values.fold<double>(
        0,
        (current, participant) => math.max(current, participant.audioLevel),
      );

      if ((_inputVolume - localLevel).abs() <= 0.001 &&
          (_outputVolume - remoteLevel).abs() <= 0.001) {
        return;
      }

      _inputVolume = localLevel;
      _outputVolume = remoteLevel;
      _notifyListeners();
    });
  }

  Future<void> _teardownRoom({
    required bool emitDisconnect,
    required bool preserveConnectionDetails,
  }) async {
    _audioTimer?.cancel();
    _audioTimer = null;

    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;

    if (room != null && _textOnlySession) {
      room.unregisterTextStreamHandler(liveKitTranscriptionTopic);
    }

    await listener?.dispose();

    if (room != null) {
      try {
        await room.disconnect();
      } catch (_) {
        // Room disconnect can race with remote teardown.
      }
      await room.dispose();
    }

    if (!preserveConnectionDetails) {
      _connectionDetails = null;
    }

    _textOnlySession = textOnly;
    _inputVolume = 0;
    _outputVolume = 0;
    _inputFrequencyData = Uint8List(0);
    _outputFrequencyData = Uint8List(0);
    _micMuted = true;
    _updateMode(ConversationMode.listening);
    _updateStatus(ConversationStatus.disconnected);
    _notifyListeners();

    if (emitDisconnect) {
      _emitDisconnect();
    }
  }

  void _pushMessage(ConversationMessage message) {
    final previous = _messageMap[message.id];
    if (previous != null &&
        previous.text == message.text &&
        previous.isFinal == message.isFinal &&
        previous.timestamp == message.timestamp &&
        previous.source == message.source) {
      return;
    }

    _messageMap[message.id] = message;
    _messages = _messageMap.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _notifyListeners();
    onMessage?.call(message);
  }

  void _updateStatus(ConversationStatus next) {
    if (_status == next) return;
    _status = next;
    _notifyListeners();
    onStatusChange?.call(next);
  }

  void _updateMode(ConversationMode next) {
    if (_mode == next) return;
    _mode = next;
    _notifyListeners();
    onModeChange?.call(next);
  }

  void _emitConnect() {
    onConnect?.call();
  }

  void _emitDisconnect() {
    if (_disconnectEmitted) return;
    _disconnectEmitted = true;
    onDisconnect?.call();
  }

  void _emitError(Object error) {
    onError?.call(
      error is Exception ? error : Exception(error.toString()),
    );
  }

  _LegacyChatPayload? _decodeLegacyChatPayload(List<int> bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      if (decoded.isEmpty) return null;

      final jsonValue = jsonDecode(decoded);
      if (jsonValue is Map<String, dynamic>) {
        final message = jsonValue["message"];
        if (message is! String || message.isEmpty) {
          return null;
        }

        final id = jsonValue["id"] as String? ??
            "agent-${DateTime.now().microsecondsSinceEpoch}";
        final timestamp = switch (jsonValue["timestamp"]) {
          int value => value,
          num value => value.toInt(),
          _ => DateTime.now().millisecondsSinceEpoch,
        };

        return _LegacyChatPayload(
          id: id,
          message: message,
          timestamp: timestamp,
        );
      }

      if (jsonValue is String && jsonValue.isNotEmpty) {
        return _LegacyChatPayload(
          id: "agent-${DateTime.now().microsecondsSinceEpoch}",
          message: jsonValue,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      final decoded = utf8.decode(bytes, allowMalformed: true).trim();
      if (decoded.isEmpty) return null;

      return _LegacyChatPayload(
        id: "agent-${DateTime.now().microsecondsSinceEpoch}",
        message: decoded,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
    }

    return null;
  }

  void _notifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _audioTimer?.cancel();
    _audioTimer = null;

    final room = _room;
    final listener = _listener;
    _room = null;
    _listener = null;

    if (room != null && _textOnlySession) {
      room.unregisterTextStreamHandler(liveKitTranscriptionTopic);
    }

    if (listener != null) {
      unawaited(listener.dispose());
    }
    if (room != null) {
      unawaited(room.disconnect());
      unawaited(room.dispose());
    }

    super.dispose();
  }
}
