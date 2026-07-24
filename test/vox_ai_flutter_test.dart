import "package:flutter_test/flutter_test.dart";
import "package:vox_ai_flutter/vox_ai_flutter.dart";
import "package:vox_ai_flutter/src/constants.dart";
import "package:vox_ai_flutter/src/token_request.dart";

void main() {
  test("Conversation exposes initial disconnected state", () {
    final conversation = Conversation();

    expect(conversation.status, ConversationStatus.disconnected);
    expect(conversation.agentState, isNull);
    expect(conversation.getAgentState(), isNull);
    expect(conversation.isSpeaking, isFalse);
    expect(conversation.micMuted, isTrue);
    expect(conversation.messages, isEmpty);
    expect(conversation.getMessages(), isEmpty);
    expect(conversation.getId(), isNull);
  });

  test("trims and maps visitorId without legacy customer fields", () {
    final body = buildTokenRequestBody(
      const StartSessionOptions(
        agentId: "agent-1",
        apiKey: "sk_test",
        visitorId: "  flutter-user-42  ",
      ),
      "call",
    );

    expect(body["visitor_id"], "flutter-user-42");
    expect(body.containsKey("customer_id"), isFalse);
    expect(body.containsKey("customer_external_id"), isFalse);
  });

  test("omits visitor_id when the host app does not provide one", () {
    final body = buildTokenRequestBody(
      const StartSessionOptions(agentId: "agent-1", apiKey: "sk_test"),
      "call",
    );

    expect(body.containsKey("visitor_id"), isFalse);
  });

  test("rejects an empty visitorId after trimming", () {
    expect(
      () => buildTokenRequestBody(
        const StartSessionOptions(
          agentId: "agent-1",
          apiKey: "sk_test",
          visitorId: " \t\n ",
        ),
        "call",
      ),
      throwsA(
        isA<ArgumentError>().having((error) => error.name, "name", "visitorId"),
      ),
    );
  });

  test("labels token requests as flutter-sdk", () {
    final body = buildTokenRequestBody(
      const StartSessionOptions(agentId: "agent-1", apiKey: "sk_test"),
      "chat",
    );
    final metadata = body["metadata"] as Map<String, dynamic>;
    final runtimeContext = metadata["runtime_context"] as Map<String, dynamic>;
    final source = runtimeContext["source"] as Map<String, dynamic>;

    expect(source["type"], "flutter-sdk");
    expect(source["version"], sdkVersion);
    expect(runtimeContext["mode"], "chat");
  });

  test("includes top-level SDK source and version", () {
    final body = buildTokenRequestBody(
      const StartSessionOptions(agentId: "agent-1", apiKey: "sk_test"),
      "call",
    );

    expect(body["source_type"], "flutter-sdk");
    expect(body["version"], sdkVersion);
  });

  test("accepts primitive dynamicVariables values", () {
    final body = buildTokenRequestBody(
      const StartSessionOptions(
        agentId: "agent-1",
        apiKey: "sk_test",
        dynamicVariables: <String, Object?>{
          "name": "Ada",
          "attempts": 3,
          "score": 9.5,
          "enabled": true,
        },
      ),
      "call",
    );

    expect(body["dynamic_variables"], <String, Object?>{
      "name": "Ada",
      "attempts": 3,
      "score": 9.5,
      "enabled": true,
    });
  });

  test("rejects non-primitive dynamicVariables values", () {
    final invalidValues = <String, Object?>{
      "null": null,
      "map": <String, Object?>{"nested": "value"},
      "list": <Object?>["value"],
    };

    for (final entry in invalidValues.entries) {
      expect(
        () => buildTokenRequestBody(
          StartSessionOptions(
            agentId: "agent-1",
            apiKey: "sk_test",
            dynamicVariables: <String, Object?>{entry.key: entry.value},
          ),
          "call",
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            "name",
            "dynamicVariables['${entry.key}']",
          ),
        ),
        reason: "${entry.key} should not be accepted",
      );
    }
  });

  test("startSession rejects non-primitive dynamicVariables", () async {
    final conversation = Conversation();
    addTearDown(conversation.dispose);

    await expectLater(
      conversation.startSession(
        const StartSessionOptions(
          agentId: "agent-1",
          apiKey: "sk_test",
          dynamicVariables: <String, Object?>{
            "profile": <String, Object?>{"name": "Ada"},
          },
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.name,
          "name",
          "dynamicVariables['profile']",
        ),
      ),
    );
    expect(conversation.status, ConversationStatus.disconnected);
  });
}
