import "package:livekit_client/livekit_client.dart";

import "types.dart";

AudioCaptureOptions toAudioCaptureOptions(AudioOptions audio) {
  return AudioCaptureOptions(
    echoCancellation: audio.echoCancellation,
    noiseSuppression: audio.noiseSuppression,
    autoGainControl: audio.autoGainControl,
  );
}
