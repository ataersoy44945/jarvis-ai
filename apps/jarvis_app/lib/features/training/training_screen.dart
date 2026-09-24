import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/jarvis_theme.dart';
import '../../core/widgets/hud/hud_panel.dart';
import '../../core/widgets/jarvis_atmosphere.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TurnDraft {
  _TurnDraft()
      : user = TextEditingController(),
        assistant = TextEditingController();

  final TextEditingController user;
  final TextEditingController assistant;

  void dispose() {
    user.dispose();
    assistant.dispose();
  }
}

class _TrainingScreenState extends State<TrainingScreen> {
  final List<_TurnDraft> _turns = [_TurnDraft()];
  List<Map<String, dynamic>> _saved = [];
  int _total = 0;
  int _target = 100;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    for (final turn in _turns) {
      turn.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    final api = context.read<ApiClient>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await api.trainingStats();
      final examples = await api.listTrainingExamples();
      if (!mounted) return;
      setState(() {
        _total = (stats['total'] as num?)?.toInt() ?? 0;
        _target = (stats['target'] as num?)?.toInt() ?? 100;
        _saved = examples;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Eğitim verisi alınamadı';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final messages = <Map<String, String>>[];
    for (final turn in _turns) {
      final user = turn.user.text.trim();
      final assistant = turn.assistant.text.trim();
      if (user.isEmpty && assistant.isEmpty) continue;
      messages.add({'role': 'user', 'content': user});
      messages.add({'role': 'assistant', 'content': assistant});
    }
    if (messages.isEmpty || messages.any((m) => m['content']!.isEmpty)) {
      setState(() => _error = 'Her turda kullanıcı ve Jarvis metni gerekli');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ApiClient>().createTrainingExample(messages);
      for (final turn in _turns) {
        turn.user.clear();
        turn.assistant.clear();
      }
      if (_turns.length > 1) {
        for (final extra in _turns.sublist(1)) {
          extra.dispose();
        }
        _turns.removeRange(1, _turns.length);
      }
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Örnek kaydedilemedi');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(int id) async {
    try {
      await context.read<ApiClient>().deleteTrainingExample(id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Örnek silinemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _target == 0 ? 0.0 : (_total / _target).clamp(0.0, 1.0);
    return Scaffold(
      body: JarvisAtmosphere(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Geri',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: JarvisTheme.cyan, size: 20),
                    ),
                    Text(
                      'EĞİTİM',
                      style: GoogleFonts.orbitron(
                        color: JarvisTheme.cyanBright,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HudPanel(
                  expand: false,
                  title: 'HEDEF',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_total / $_target',
                        style: GoogleFonts.orbitron(
                          color: JarvisTheme.cyan,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: JarvisTheme.cyanDeep,
                          color: JarvisTheme.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: HudPanel(
                    title: 'ÖRNEK YAZ',
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            children: [
                              for (var i = 0; i < _turns.length; i++) ...[
                                Text(
                                  'TUR ${i + 1}',
                                  style: GoogleFonts.orbitron(
                                    color: JarvisTheme.muted,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _box('Kullanıcı', _turns[i].user),
                                const SizedBox(height: 6),
                                _box('Jarvis', _turns[i].assistant),
                                const SizedBox(height: 12),
                              ],
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => setState(() => _turns.add(_TurnDraft())),
                                  child: const Text('+ TUR EKLE'),
                                ),
                              ),
                              if (_error != null)
                                Text(_error!, style: const TextStyle(color: JarvisTheme.danger)),
                              const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _saving ? null : _save,
                                child: Text(_saving ? 'KAYDEDİLİYOR' : 'KAYDET'),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'KAYITLI ÖRNEKLER',
                                style: GoogleFonts.orbitron(
                                  color: JarvisTheme.cyan,
                                  fontSize: 11,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_saved.isEmpty)
                                Text(
                                  'Henüz örnek yok',
                                  style: GoogleFonts.rajdhani(color: JarvisTheme.muted),
                                ),
                              for (final ex in _saved)
                                _SavedTile(
                                  example: ex,
                                  onDelete: () => _delete(ex['id'] as int),
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 5,
      style: GoogleFonts.rajdhani(color: JarvisTheme.ink, fontSize: 16),
      decoration: InputDecoration(hintText: label),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.example, required this.onDelete});

  final Map<String, dynamic> example;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final messages = (example['messages'] as List?) ?? [];
    final preview = messages.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      final who = map['role'] == 'assistant' ? 'J' : 'U';
      return '$who: ${map['content']}';
    }).join('  ·  ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rajdhani(color: JarvisTheme.inkSoft, fontSize: 14),
            ),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: JarvisTheme.danger, size: 18),
          ),
        ],
      ),
    );
  }
}
