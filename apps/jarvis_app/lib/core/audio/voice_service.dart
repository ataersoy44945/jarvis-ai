import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceState { idle, listening, thinking, speaking }

class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  VoiceState state = VoiceState.idle;
  String partial = '';
  bool available = false;
  String? error;

  Future<void> init() async {
    try {
      available = await _stt.initialize(
        onError: (e) {
          error = e.errorMsg;
          state = VoiceState.idle;
          notifyListeners();
        },
        onStatus: (_) {},
      );
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setLanguage('tr-TR');
      _tts.setCompletionHandler(() {
        state = VoiceState.idle;
        notifyListeners();
      });
    } catch (e) {
      available = false;
      error = e.toString();
    }
    notifyListeners();
  }

  Future<String?> listenOnce() async {
    if (!available) {
      await init();
    }
    if (!available) {
      error = 'Speech recognition unavailable on this device';
      notifyListeners();
      return null;
    }

    partial = '';
    state = VoiceState.listening;
    notifyListeners();

    final completer = Completer<String?>();
    await _stt.listen(
      onResult: (result) {
        partial = result.recognizedWords;
        notifyListeners();
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'tr_TR',
        listenMode: ListenMode.confirmation,
        partialResults: true,
      ),
    );

    final text = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () async {
        await _stt.stop();
        return partial.isEmpty ? null : partial;
      },
    );

    await _stt.stop();
    state = VoiceState.idle;
    notifyListeners();
    final trimmed = text?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> stopListening() async {
    await _stt.stop();
    state = VoiceState.idle;
    notifyListeners();
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    state = VoiceState.speaking;
    notifyListeners();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    state = VoiceState.idle;
    notifyListeners();
  }

  void setThinking(bool value) {
    state = value ? VoiceState.thinking : VoiceState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _stt.stop();
    _tts.stop();
    super.dispose();
  }
}
