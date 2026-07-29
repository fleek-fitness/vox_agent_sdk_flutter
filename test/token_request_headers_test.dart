import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:vox_ai_flutter/src/constants.dart";
import "package:vox_ai_flutter/src/token_request.dart";
import "package:vox_ai_flutter/src/types.dart";

void main() {
  test("token request sends X-Vox-Client without changing the body", () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response("{}", 200);
    });
    const options = StartSessionOptions(
      agentId: "agent-1",
      apiKey: "sk_test",
      visitorId: "  flutter-user-42  ",
      dynamicVariables: <String, Object?>{
        "name": "Ada",
        "attempts": 2,
        "enabled": true,
      },
      metadata: <String, Object?>{"campaign": "summer"},
    );
    final payload = buildTokenRequestBody(options, "call");

    await http.runWithClient(
      () => postTokenRequest(options, payload),
      () => client,
    );

    final request = capturedRequest;
    expect(request, isNotNull);
    expect(request!.headers["X-Vox-Client"], "flutter-sdk/$sdkVersion");
    expect(request.headers["Authorization"], "Bearer sk_test");
    expect(request.headers["Content-Type"], "application/json");
    expect(jsonDecode(request.body), <String, dynamic>{
      "agent_id": "agent-1",
      "agent_version": "current",
      "mode": "call",
      "dynamic_variables": <String, Object?>{
        "name": "Ada",
        "attempts": 2,
        "enabled": true,
      },
      "visitor_id": "flutter-user-42",
      "source_type": "flutter-sdk",
      "version": sdkVersion,
      "metadata": <String, dynamic>{
        "runtime_context": <String, dynamic>{
          "source": <String, dynamic>{
            "type": "flutter-sdk",
            "version": sdkVersion,
          },
          "mode": "call",
        },
        "call_web": <String, dynamic>{
          "dynamic_variables": <String, Object?>{
            "name": "Ada",
            "attempts": 2,
            "enabled": true,
          },
          "metadata": <String, Object?>{"campaign": "summer"},
        },
      },
    });
  });
}
