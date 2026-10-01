import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

/// Service untuk menangani suara Text-to-Speech (TTS) dan TalkBack announcement.
/// Didesain dengan debounce agar tidak membingungkan pengguna tunanetra dengan spam audio.
class TtsService extends GetxService {
  late FlutterTts _tts;
  String _lastSpoken = '';
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<TtsService> init() async {
    _tts = FlutterTts();

    try {
      await _tts.setLanguage('id-ID'); // Bahasa Indonesia
      await _tts.setSpeechRate(0.5);   // Kecepatan sedang, artikulasi jelas
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
      });
    } catch (e) {
      // Fallback jika device simulator belum punya tts engine
    }

    return this;
  }

  /// Membaca teks dengan perlindungan Debounce (Cooldown 2 detik untuk teks berulang)
  Future<void> speak(String text, {bool isUrgent = false}) async {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime).inMilliseconds;

    // Jika kalimat sama dan belum lewat 2000ms, abaikan kecuali mendesak
    if (!isUrgent && text == _lastSpoken && elapsed < 2000) {
      return;
    }

    _lastSpoken = text;
    _lastTime = now;

    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}

    // Beritahukan juga ke TalkBack Android jika aktif
    SemanticsService.announce(text, TextDirection.ltr);
  }

  /// Menghentikan suara segera
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }
}
