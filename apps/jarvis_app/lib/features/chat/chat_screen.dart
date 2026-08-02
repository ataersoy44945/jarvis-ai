import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/voice_service.dart';
import '../../core/theme/jarvis_theme.dart';
import '../auth/auth_controller.dart';
import '../sphere/ai_sphere.dart';
import 'chat_controller.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatController>();
      await chat.initVoice();
      await chat.loadLatestConversation();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    await context.read<ChatController>().sendText(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final auth = context.watch<AuthController>();
    final voice = chat.voice;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.55),
            radius: 1.2,
            colors: [Color(0xFF10263A), JarvisTheme.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'JARVIS',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: JarvisTheme.cyan,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      auth.name ?? '',
                      style: const TextStyle(color: JarvisTheme.muted, fontSize: 13),
                    ),
                    IconButton(
                      tooltip: 'New chat',
                      onPressed: chat.startNewChat,
                      icon: const Icon(Icons.add_comment_outlined, color: JarvisTheme.muted),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: chat.logout,
                      icon: const Icon(Icons.logout, color: JarvisTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AiSphere(state: voice.state, size: MediaQuery.sizeOf(context).width < 500 ? 200 : 240),
              Text(
                _statusLabel(voice.state),
                style: const TextStyle(color: JarvisTheme.muted, letterSpacing: 1.2),
              ),
              if (voice.partial.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Text(
                    voice.partial,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: JarvisTheme.cyan),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: chat.messages.length,
                  itemBuilder: (context, index) {
                    final m = chat.messages[index];
                    final mine = m.role == 'user';
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? JarvisTheme.cyan.withValues(alpha: 0.16)
                              : JarvisTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: mine
                                ? JarvisTheme.cyan.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Text(m.content),
                      ),
                    );
                  },
                ),
              ),
              if (chat.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(chat.error!, style: const TextStyle(color: JarvisTheme.danger)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Ask Jarvis…',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: voice.state == VoiceState.listening ? Icons.stop : Icons.mic,
                      active: voice.state == VoiceState.listening,
                      onTap: chat.sending
                          ? null
                          : () async {
                              if (voice.state == VoiceState.listening) {
                                await voice.stopListening();
                              } else {
                                await chat.listenAndSend();
                                _scrollToEnd();
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    _RoundAction(
                      icon: Icons.send_rounded,
                      onTap: chat.sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(VoiceState state) {
    return switch (state) {
      VoiceState.idle => 'ONLINE',
      VoiceState.listening => 'LISTENING',
      VoiceState.thinking => 'THINKING',
      VoiceState.speaking => 'SPEAKING',
    };
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, this.onTap, this.active = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? JarvisTheme.cyan : JarvisTheme.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            color: active ? JarvisTheme.bg : JarvisTheme.cyan,
          ),
        ),
      ),
    );
  }
}
