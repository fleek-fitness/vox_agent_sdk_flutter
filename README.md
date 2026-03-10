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
- A vox.ai agent ID and API key

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
    apiKey: 'your-api-key',
  ),
);
```

For text-only sessions:

```dart
await conversation.startSession(
  const StartSessionOptions(
    agentId: 'your-agent-id',
    apiKey: 'your-api-key',
    textOnly: true,
  ),
);
```

### Reactive state

`Conversation` extends `ChangeNotifier`, and also exposes synchronous state getters.

```dart
conversation.status;     // ConversationStatus
conversation.isSpeaking; // bool
conversation.micMuted;   // bool
conversation.messages;   // List<ConversationMessage>
```

### Methods

```dart
await conversation.endSession();

final sessionId = conversation.getId();
final messages = conversation.getMessages();

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
      onModeChange: (_) => setState(() {}),
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
                apiKey: 'your-api-key',
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

- `runtime_context.source.type` is sent as `react-sdk` for parity with the existing vox.ai SDKs.
- `getMessages()` and `messages` expose the same sorted conversation history snapshot.
- `changeInputDevice()` and `changeOutputDevice()` are best-effort. They return `false` on unsupported platforms such as mobile runtimes where device switching is not exposed.
- `getInputByteFrequencyData()` and `getOutputByteFrequencyData()` currently return empty byte arrays because `livekit_client` does not expose analyser frequency buffers.
- `setVolume()` is a best-effort SDK-level setting. Flutter LiveKit does not expose the same per-track playback volume controls available in the web SDK.
