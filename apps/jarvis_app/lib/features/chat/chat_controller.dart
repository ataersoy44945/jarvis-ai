import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/audio/voice_service.dart';
import '../auth/auth_controller.dart';

class ChatMessage {
  ChatMessage({required this.role, required this.content, this.id, this.rating});

  final String role;
  final String content;

  /// Server id (assistant replies only) — needed for feedback.
  final int? id;

  /// 1 = good, -1 = bad, null = not rated.
  int? rating;
}

class ChatController extends ChangeNotifier {
  ChatController(this._api);

  final ApiClient _api;
  final VoiceService voice = VoiceService();

  AuthController? _auth;
  int? conversationId;
  final List<ChatMessage> messages = [];
  bool sending = false;
  String? error;

  void attachAuth(AuthController auth) {
    _auth = auth;
  }

  Future<void> initVoice() async {
    voice.addListener(_onVoice);
    await voice.init();
  }

  void _onVoice() => notifyListeners();

  @override
  void dispose() {
    voice.removeListener(_onVoice);
    voice.dispose();
    super.dispose();
  }

  Future<void> loadLatestConversation() async {
    try {
      final list = await _api.listConversations();
      if (list.isEmpty) return;
      final id = list.first['id'] as int;
      await openConversation(id);
    } catch (_) {
      // Fresh users have no history yet.
    }
  }

  Future<void> openConversation(int id) async {
    final detail = await _api.getConversation(id);
    conversationId = id;
    messages
      ..clear()
      ..addAll(
        ((detail['messages'] as List?) ?? []).map(
          (m) => ChatMessage(
            role: (m as Map)['role'] as String,
            content: m['content'] as String,
            id: m['id'] as int?,
            rating: m['rating'] as int?,
          ),
        ),
      );
    notifyListeners();
  }

  Future<void> startNewChat() async {
    conversationId = null;
    messages.clear();
    error = null;
    notifyListeners();
  }

  Future<void> sendText(String text, {bool speakReply = true}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || sending) return;

    error = null;
    sending = true;
    messages.add(ChatMessage(role: 'user', content: trimmed));
    voice.setThinking(true);
    notifyListeners();

    try {
      final data = await _api.sendChat(
        message: trimmed,
        conversationId: conversationId,
      );
      conversationId = data['conversation_id'] as int;
      final reply = data['reply'] as String;
      messages.add(ChatMessage(
        role: 'assistant',
        content: reply,
        id: data['message_id'] as int?,
      ));
      notifyListeners();
      if (speakReply) {
        await voice.speak(reply);
      } else {
        voice.setThinking(false);
      }
    } on DioException catch (e) {
      error = e.response?.data?.toString() ?? e.message ?? 'Chat failed';
      voice.setThinking(false);
    } catch (e) {
      error = e.toString();
      voice.setThinking(false);
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  /// Rate a Jarvis reply. Tapping the same rating again clears it.
  /// Rated replies (and corrections) become training data for your own model.
  Future<void> rate(ChatMessage m, int rating, {String? correction}) async {
    final id = m.id;
    if (id == null) return;
    final previous = m.rating;
    final next = (previous == rating && correction == null) ? 0 : rating;
    m.rating = next == 0 ? null : next;
    notifyListeners();
    try {
      await _api.sendFeedback(messageId: id, rating: next, correction: correction);
    } catch (e) {
      m.rating = previous;
      error = 'Geri bildirim kaydedilemedi: $e';
      notifyListeners();
    }
  }

  Future<void> listenAndSend() async {
    final text = await voice.listenOnce();
    if (text == null) return;
    await sendText(text, speakReply: true);
  }

  Future<void> logout() async {
    await voice.stopSpeaking();
    await voice.stopListening();
    await startNewChat();
    await _auth?.logout();
  }
}
