import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/audio/voice_service.dart';
import '../../core/theme/jarvis_theme.dart';
import '../../core/widgets/hud/hud_arc_gauge.dart';
import '../../core/widgets/hud/hud_panel.dart';
import '../../core/widgets/hud/hud_tick_rail.dart';
import '../../core/widgets/jarvis_atmosphere.dart';
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
      _scrollToEnd();
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

  Future<void> _toggleMic() async {
    final chat = context.read<ChatController>();
    final voice = chat.voice;
    if (chat.sending) return;
    if (voice.state == VoiceState.listening) {
      await voice.stopListening();
    } else {
      await chat.listenAndSend();
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final auth = context.watch<AuthController>();
    final voice = chat.voice;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final coreSize = wide
        ? 300.0
        : (MediaQuery.sizeOf(context).width < 420 ? 200.0 : 240.0);

    final voiceLevel = switch (voice.state) {
      VoiceState.idle => 0.18,
      VoiceState.listening => 0.82,
      VoiceState.thinking => 0.55,
      VoiceState.speaking => 0.95,
    };

    return Scaffold(
      body: JarvisAtmosphere(
        intensity: 1.15,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                _TopHud(
                  userName: auth.name ?? 'OPERATOR',
                  onNewChat: chat.startNewChat,
                  onLogout: chat.logout,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 210,
                              child: _StatusPanel(
                                voiceLevel: voiceLevel,
                                linkLevel: chat.sending ? 0.7 : 0.35,
                                conversationId: chat.conversationId,
                                state: voice.state,
                                sending: chat.sending,
                                onNewChat: chat.startNewChat,
                                onLogout: chat.logout,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: Center(
                                child: HudCore(
                                  state: voice.state,
                                  size: coreSize,
                                  onTap: _toggleMic,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 5,
                              child: _TranscriptPanel(
                                chat: chat,
                                scroll: _scroll,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            HudCore(
                              state: voice.state,
                              size: coreSize,
                              onTap: _toggleMic,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _statusCode(voice.state),
                              style: GoogleFonts.orbitron(
                                color: JarvisTheme.cyan,
                                fontSize: 11,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _TranscriptPanel(
                                chat: chat,
                                scroll: _scroll,
                              ),
                            ),
                          ],
                        ),
                ),
                if (chat.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      chat.error!,
                      style: const TextStyle(color: JarvisTheme.danger, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                _CommandStrip(
                  controller: _input,
                  sending: chat.sending,
                  listening: voice.state == VoiceState.listening,
                  onSend: _send,
                  onMic: _toggleMic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusCode(VoiceState state) {
    return switch (state) {
      VoiceState.idle => 'SYS // ONLINE',
      VoiceState.listening => 'SYS // LISTENING',
      VoiceState.thinking => 'SYS // COMPUTING',
      VoiceState.speaking => 'SYS // SPEAKING',
    };
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.userName,
    required this.onNewChat,
    required this.onLogout,
  });

  final String userName;
  final VoidCallback onNewChat;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HudTickRail(),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'JARVIS',
              style: GoogleFonts.orbitron(
                color: JarvisTheme.cyanBright,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'SYSTEMS ONLINE',
              style: GoogleFonts.rajdhani(
                color: JarvisTheme.ok,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Text(
              userName.toUpperCase(),
              style: GoogleFonts.rajdhani(
                color: JarvisTheme.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 16),
            const HudClock(),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'New session',
              onPressed: onNewChat,
              icon: const Icon(Icons.add, color: JarvisTheme.cyan, size: 20),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: onLogout,
              icon: const Icon(Icons.power_settings_new, color: JarvisTheme.muted, size: 20),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.voiceLevel,
    required this.linkLevel,
    required this.conversationId,
    required this.state,
    required this.sending,
    required this.onNewChat,
    required this.onLogout,
  });

  final double voiceLevel;
  final double linkLevel;
  final int? conversationId;
  final VoiceState state;
  final bool sending;
  final VoidCallback onNewChat;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      title: 'STATUS // NODE',
      child: Column(
        children: [
          HudArcGauge(value: voiceLevel, label: 'VOICE', sublabel: _stateName(state)),
          const SizedBox(height: 16),
          HudArcGauge(
            value: linkLevel,
            label: 'LINK',
            sublabel: sending ? 'BUSY' : 'READY',
            size: 88,
          ),
          const SizedBox(height: 18),
          _kv('SESSION', conversationId == null ? 'NEW' : '#$conversationId'),
          _kv('CHANNEL', 'LOCAL API'),
          _kv('MODE', state == VoiceState.listening ? 'VOICE' : 'TEXT'),
          const Spacer(),
          _HudLink(label: 'NEW SESSION', onTap: onNewChat),
          _HudLink(label: 'SIGN OUT', onTap: onLogout, danger: true),
        ],
      ),
    );
  }

  String _stateName(VoiceState s) => switch (s) {
        VoiceState.idle => 'IDLE',
        VoiceState.listening => 'LISTEN',
        VoiceState.thinking => 'THINK',
        VoiceState.speaking => 'SPEAK',
      };

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            k,
            style: GoogleFonts.rajdhani(
              color: JarvisTheme.muted,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            v,
            style: GoogleFonts.orbitron(
              color: JarvisTheme.cyan,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudLink extends StatelessWidget {
  const _HudLink({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.chevron_right,
              size: 16,
              color: danger ? JarvisTheme.danger : JarvisTheme.cyan,
            ),
            Text(
              label,
              style: GoogleFonts.orbitron(
                color: danger ? JarvisTheme.danger : JarvisTheme.cyan,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({required this.chat, required this.scroll});

  final ChatController chat;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      title: 'TRANSCRIPT // FEED',
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: chat.messages.isEmpty && !chat.sending
          ? Center(
              child: Text(
                'AWAITING INPUT',
                style: GoogleFonts.orbitron(
                  color: JarvisTheme.muted,
                  letterSpacing: 3,
                  fontSize: 12,
                ),
              ),
            )
          : ListView.builder(
              controller: scroll,
              itemCount: chat.messages.length + (chat.sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (chat.sending && index == chat.messages.length) {
                  return const _TypingLine();
                }
                final m = chat.messages[index];
                return _FeedLine(
                  mine: m.role == 'user',
                  text: m.content,
                  rating: m.rating,
                  onRate: m.role == 'assistant' && m.id != null
                      ? (r) => chat.rate(m, r)
                      : null,
                  onCorrect: m.role == 'assistant' && m.id != null
                      ? () => _askCorrection(context, chat, m)
                      : null,
                );
              },
            ),
    );
  }
}

Future<void> _askCorrection(BuildContext context, ChatController chat, ChatMessage m) async {
  final ctrl = TextEditingController(text: m.content);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: JarvisTheme.bg,
      title: Text(
        'DOĞRU CEVAP NE OLMALIYDI?',
        style: GoogleFonts.orbitron(color: JarvisTheme.cyan, fontSize: 12, letterSpacing: 1.5),
      ),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: ctrl,
          maxLines: 8,
          style: GoogleFonts.rajdhani(color: JarvisTheme.ink, fontSize: 15),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('KAYDET')),
      ],
    ),
  );
  if (result != null && result.trim().isNotEmpty) {
    // A correction means "this is what you should have said" — stored as a good example.
    await chat.rate(m, 1, correction: result);
  }
}

class _FeedLine extends StatelessWidget {
  const _FeedLine({
    required this.mine,
    required this.text,
    this.rating,
    this.onRate,
    this.onCorrect,
  });

  final bool mine;
  final String text;
  final int? rating;
  final void Function(int rating)? onRate;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(top: 2, right: 8),
            color: mine ? JarvisTheme.cyanBright : JarvisTheme.cyanDim,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? 'OPERATOR' : 'JARVIS',
                  style: GoogleFonts.orbitron(
                    color: mine ? JarvisTheme.cyanBright : JarvisTheme.cyan,
                    fontSize: 9,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: GoogleFonts.rajdhani(
                    color: JarvisTheme.ink,
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onRate != null)
                  Row(
                    children: [
                      _RateBtn(
                        icon: Icons.thumb_up_alt_outlined,
                        active: rating == 1,
                        tooltip: 'İyi cevap',
                        onTap: () => onRate!(1),
                      ),
                      _RateBtn(
                        icon: Icons.thumb_down_alt_outlined,
                        active: rating == -1,
                        tooltip: 'Kötü cevap',
                        onTap: () => onRate!(-1),
                      ),
                      _RateBtn(
                        icon: Icons.edit_outlined,
                        active: false,
                        tooltip: 'Düzelt',
                        onTap: onCorrect,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateBtn extends StatelessWidget {
  const _RateBtn({required this.icon, required this.active, required this.tooltip, this.onTap});

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 15,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
      color: active ? JarvisTheme.cyanBright : JarvisTheme.muted,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }
}

class _TypingLine extends StatefulWidget {
  const _TypingLine();

  @override
  State<_TypingLine> createState() => _TypingLineState();
}

class _TypingLineState extends State<_TypingLine> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final dots = '.' * (1 + (_ctrl.value * 3).floor() % 3);
        return _FeedLine(mine: false, text: 'computing$dots');
      },
    );
  }
}

class _CommandStrip extends StatelessWidget {
  const _CommandStrip({
    required this.controller,
    required this.sending,
    required this.listening,
    required this.onSend,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool sending;
  final bool listening;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: JarvisTheme.surface.withValues(alpha: 0.7),
            border: Border.all(color: JarvisTheme.cyan.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '>',
                  style: GoogleFonts.orbitron(color: JarvisTheme.cyan, fontSize: 16),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  style: GoogleFonts.rajdhani(
                    color: JarvisTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!sending) onSend();
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter command…',
                    hintStyle: GoogleFonts.rajdhani(color: JarvisTheme.muted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              _CmdBtn(
                icon: listening ? Icons.stop : Icons.mic,
                active: listening,
                onTap: sending ? null : onMic,
              ),
              _CmdBtn(
                icon: Icons.send,
                active: true,
                onTap: sending ? null : onSend,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'JARVIS SYSTEMS  //  STARK PROTOCOL UI',
          style: GoogleFonts.orbitron(
            color: JarvisTheme.muted.withValues(alpha: 0.7),
            fontSize: 8,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

class _CmdBtn extends StatelessWidget {
  const _CmdBtn({required this.icon, required this.onTap, this.active = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active ? JarvisTheme.cyan.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
              color: active
                  ? JarvisTheme.cyan
                  : JarvisTheme.cyan.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(icon, size: 18, color: JarvisTheme.cyan),
        ),
      ),
    );
  }
}
