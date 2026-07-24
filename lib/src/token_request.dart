import "constants.dart";
import "types.dart";

Map<String, dynamic> buildTokenRequestBody(
  StartSessionOptions options,
  String mode,
) {
  const sourceType = "flutter-sdk";
  final visitorId = options.visitorId?.trim();

  if (visitorId != null && visitorId.isEmpty) {
    throw ArgumentError.value(
      options.visitorId,
      "visitorId",
      "must be a non-empty string when provided",
    );
  }

  for (final entry in options.dynamicVariables.entries) {
    final value = entry.value;
    if (value is! String && value is! num && value is! bool) {
      throw ArgumentError.value(
        value,
        "dynamicVariables['${entry.key}']",
        "must be a String, num, or bool",
      );
    }
  }

  return <String, dynamic>{
    "agent_id": options.agentId,
    "agent_version": options.agentVersion ?? "current",
    "mode": mode,
    "dynamic_variables": options.dynamicVariables,
    "visitor_id": ?visitorId,
    "source_type": sourceType,
    "version": sdkVersion,
    "metadata": <String, dynamic>{
      "runtime_context": <String, dynamic>{
        "source": <String, dynamic>{"type": sourceType, "version": sdkVersion},
        "mode": mode,
      },
      "call_web": <String, dynamic>{
        "dynamic_variables": options.dynamicVariables,
        "metadata": options.metadata,
      },
    },
  };
}
