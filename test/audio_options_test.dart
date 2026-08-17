import "package:flutter_test/flutter_test.dart";
import "package:livekit_client/livekit_client.dart";
import "package:vox_ai_flutter/vox_ai_flutter.dart";
import "package:vox_ai_flutter/src/audio_options.dart";

void main() {
  test("omitted audio options preserve default-on capture behavior", () {
    const sessionOptions = StartSessionOptions(
      agentId: "agent-1",
      apiKey: "sk_test",
    );
    final options = toAudioCaptureOptions(sessionOptions.audio);

    expect(options.echoCancellation, isTrue);
    expect(options.noiseSuppression, isTrue);
    expect(options.autoGainControl, isTrue);
  });

  test("maps a partially customized AudioOptions", () {
    final options = toAudioCaptureOptions(
      const AudioOptions(echoCancellation: false),
    );

    expect(options.echoCancellation, isFalse);
    expect(options.noiseSuppression, isTrue);
    expect(options.autoGainControl, isTrue);
  });

  test("maps all disabled audio processing options", () {
    final options = toAudioCaptureOptions(
      const AudioOptions(
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
      ),
    );

    expect(options.echoCancellation, isFalse);
    expect(options.noiseSuppression, isFalse);
    expect(options.autoGainControl, isFalse);
  });

  test("leaves unrelated LiveKit capture options at their defaults", () {
    final options = toAudioCaptureOptions(const AudioOptions());
    const defaults = AudioCaptureOptions();

    expect(options.deviceId, defaults.deviceId);
    expect(options.highPassFilter, defaults.highPassFilter);
    expect(options.echoCancellationMode, defaults.echoCancellationMode);
    expect(options.noiseSuppressionMode, defaults.noiseSuppressionMode);
    expect(options.autoGainControlMode, defaults.autoGainControlMode);
    expect(options.highPassFilterMode, defaults.highPassFilterMode);
    expect(options.voiceIsolation, defaults.voiceIsolation);
    expect(options.typingNoiseDetection, defaults.typingNoiseDetection);
    expect(options.stopAudioCaptureOnMute, defaults.stopAudioCaptureOnMute);
    expect(options.processor, defaults.processor);
  });
}
