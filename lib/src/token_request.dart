import "constants.dart";
import "types.dart";

Map<String, dynamic> buildTokenRequestBody(
  StartSessionOptions options,
  String mode,
) {
  return <String, dynamic>{
    "agent_id": options.agentId,
    "agent_version": options.agentVersion ?? "current",
    "mode": mode,
    "dynamic_variables": options.dynamicVariables,
    if (options.visitorId != null) "visitor_id": options.visitorId,
    "metadata": <String, dynamic>{
      "runtime_context": <String, dynamic>{
        "source": <String, dynamic>{"type": "react-sdk", "version": sdkVersion},
        "mode": mode,
      },
      "call_web": <String, dynamic>{
        "dynamic_variables": options.dynamicVariables,
        "metadata": options.metadata,
      },
    },
  };
}
