import "package:flutter_test/flutter_test.dart";
import "package:vox_ai_flutter/vox_ai_flutter.dart";

void main() {
  test("Conversation exposes initial disconnected state", () {
    final conversation = Conversation();

    expect(conversation.status, ConversationStatus.disconnected);
    expect(conversation.mode, ConversationMode.listening);
    expect(conversation.isSpeaking, isFalse);
    expect(conversation.micMuted, isTrue);
    expect(conversation.messages, isEmpty);
    expect(conversation.getMessages(), isEmpty);
    expect(conversation.getId(), isNull);
  });
}
