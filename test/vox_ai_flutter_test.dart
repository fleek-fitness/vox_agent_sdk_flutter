import "package:flutter_test/flutter_test.dart";
import "package:vox_ai_flutter/vox_ai_flutter.dart";
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

  test("maps visitorId to visitor_id without legacy customer fields", () {
    final body = buildTokenRequestBody(
      const StartSessionOptions(
        agentId: "agent-1",
        apiKey: "sk_test",
        visitorId: "flutter-user-42",
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
}
