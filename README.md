# vox.ai Flutter SDK

Deploy customized, interactive voice agents in minutes for Flutter apps.

## Installation

Add the package to your Flutter project with a git dependency.

```yaml
dependencies:
  vox_ai_flutter:
    git:
      url: https://github.com/fleek-fitness/vox_agent_sdk_flutter
```

Then install dependencies:

```shell
flutter pub get
```

## Requirements

- Flutter app
- Microphone permissions configured for your target platform
- A vox.ai agent ID and a client key (`pk_…`), created in the dashboard under Settings > API keys with the "client" purpose

## Setup

Create a `Conversation` instance where you want to manage the session lifecycle.

```dart
import 'package:vox_ai_flutter/vox_ai_flutter.dart';

final conversation = Conversation(
  onConnect: () => print('Connected'),
  onDisconnect: () => print('Disconnected'),
  onMessage: (message) => print('Message: ${message.text}'),
  onError: (error) => print('Error: $error'),
);
```

## Usage

### Start a session

```dart
await conversation.startSession(
  const StartSessionOptions(
    agentId: 'your-agent-id',
    apiKey: 'pk_your_client_key',
    visitorId: 'your-stable-visitor-id',
  ),
);
```

`audio`(`AudioOptions`)는 마이크 처리인 `echoCancellation`, `noiseSuppression`,
`autoGainControl`을 설정하는 선택 필드다. 세 값 모두 기본값이 `true`라서 생략하면
현재 동작이 유지된다. 스피커폰에서 `echoCancellation`을 끄면 에이전트 음성이 마이크로
다시 들어가 스스로 끼어들 수 있으므로 헤드셋·이어폰 환경이나 자체 오디오 파이프라인에서만
끈다. 세 값은 LiveKit `AudioCaptureOptions`로 전달되고, `textOnly` 세션에서는 마이크를
열지 않아 적용되지 않는다.

```dart
const StartSessionOptions(
  agentId: 'your-agent-id',
  apiKey: 'pk_your_client_key',
  audio: AudioOptions(echoCancellation: false),
);
```

`visitorId`는 같은 앱 사용자의 세션을 하나의 customer로 이어 붙일 때 사용하는
선택 필드다. Flutter SDK는 `visitorId`를 자동으로 생성하거나 기기에 저장하지
않는다. 생략하면 세션마다 새로운 익명 Customer에 귀속되어 Memory 연속성이
없다. Memory 연속성이 필요하면 로그인 사용자 ID나 설치 ID처럼 안정적인
`visitorId`를 매 세션 동일하게 전달해야 한다. vox.ai 내부 Customer UUID를
입력하는 필드가 아니다. 에이전트의 Memory가 켜져 있으면 첫 응답 전에 해당
Customer와 에이전트 범위의 Memory를 자동으로 불러온다. 전달한 값은 앞뒤
공백을 제거해 사용하며, 그 결과가 빈 문자열이면 요청 전에 `ArgumentError`가
발생한다.

For text-only sessions:

```dart
await conversation.startSession(
  const StartSessionOptions(
    agentId: 'your-agent-id',
    apiKey: 'pk_your_client_key',
    textOnly: true,
  ),
);
```

### Reactive state

`Conversation` extends `ChangeNotifier`, and also exposes synchronous state getters.

```dart
conversation.status;     // ConversationStatus
conversation.agentState; // AgentState?
conversation.isSpeaking; // bool
conversation.micMuted;   // bool
conversation.messages;   // List<ConversationMessage>
```

### Methods

```dart
await conversation.endSession();

final sessionId = conversation.getId();
final messages = conversation.getMessages();
final agentState = conversation.getAgentState();

conversation.setVolume(const SetVolumeParams(volume: 0.5));
await conversation.setMicMuted(true);
await conversation.sendUserMessage('Hello');

await conversation.changeInputDevice(
  const InputDeviceConfig(inputDeviceId: 'device-id'),
);
await conversation.changeOutputDevice(
  const OutputDeviceConfig(outputDeviceId: 'device-id'),
);

final inputLevel = conversation.getInputVolume();
final outputLevel = conversation.getOutputVolume();

final inputFrequency = conversation.getInputByteFrequencyData();
final outputFrequency = conversation.getOutputByteFrequencyData();
```

## Example

```dart
import 'package:flutter/material.dart';
import 'package:vox_ai_flutter/vox_ai_flutter.dart';

class ConversationController extends StatefulWidget {
  const ConversationController({super.key});

  @override
  State<ConversationController> createState() => _ConversationControllerState();
}

class _ConversationControllerState extends State<ConversationController> {
  late final Conversation conversation;

  @override
  void initState() {
    super.initState();
    conversation = Conversation(
      onConnect: () => setState(() {}),
      onDisconnect: () => setState(() {}),
      onMessage: (_) => setState(() {}),
      onStatusChange: (_) => setState(() {}),
      onAgentStateChange: (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    conversation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Status: ${conversation.status.name}'),
        Text('Speaking: ${conversation.isSpeaking}'),
        ElevatedButton(
          onPressed: () async {
            await conversation.startSession(
              const StartSessionOptions(
                agentId: 'your-agent-id',
                apiKey: 'pk_your_client_key',
              ),
            );
          },
          child: const Text('Start Session'),
        ),
        ElevatedButton(
          onPressed: () => conversation.endSession(),
          child: const Text('End Session'),
        ),
      ],
    );
  }
}
```

## Platform-Specific Considerations

### iOS

Add microphone usage text to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to enable voice conversations with AI agents.</string>
```

### Android

Add microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

If your app requests runtime permissions manually, ask for microphone access before starting a voice session.

## Notes

- `source_type` and `runtime_context.source.type` are sent as `flutter-sdk`; their version fields match the Flutter SDK version.
- `dynamicVariables` values must be `String`, `num`, or `bool`. `null`, maps, lists, and other values cause `startSession()` to throw `ArgumentError` before requesting a token.
- `getMessages()` and `messages` expose the same sorted conversation history snapshot.
- `changeInputDevice()` and `changeOutputDevice()` are best-effort. They return `false` on unsupported platforms such as mobile runtimes where device switching is not exposed.
- `getInputByteFrequencyData()` and `getOutputByteFrequencyData()` currently return empty byte arrays because `livekit_client` does not expose analyser frequency buffers.
- `setVolume()` is a best-effort SDK-level setting. Flutter LiveKit does not expose the same per-track playback volume controls available in the web SDK.

## API Key Security

- Use a **client key** (`pk_…`) in your app. Create it in the vox.ai dashboard under Settings > API keys with the "client" purpose.
- A client key can only start sessions. It cannot be used to read data or change settings through the REST API.
- Client keys can optionally be restricted to allowed domains. Native apps send no `Origin`, so leave the field empty for native-only keys.
- Client keys are limited to 30 session starts per minute per key and IP.
- Secret keys (`sk_…`) are for servers. Secret keys created after client keys were introduced cannot start sessions from browsers or mobile apps. Existing secret keys keep working.
- If a key is exposed, delete it and create a new one.
