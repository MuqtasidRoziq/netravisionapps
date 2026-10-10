import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import '../utils/helpers/tts_policy.dart';

/// Service untuk menangani suara Text-to-Speech (TTS) dan TalkBack announcement.
/// Didesain dengan debounce agar tidak membingungkan pengguna tunanetra dengan spam audio.
class TtsService extends GetxService {
  static const String _accessibilityChannel = 'com.netravision.apps/accessibility';
  final MethodChannel _accessibilityEngine = const MethodChannel(_accessibilityChannel);

  late FlutterTts _tts;
  String _lastSpoken = '';
  DateTime _lastTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isSpeaking = false;

  /// Pesan terbaru yang menunggu ucapan saat ini selesai (anti-potong).
  String? _pending;

  static const Duration _debounce = Duration(milliseconds: 2000);

  // Status TalkBack disimpan cache agar tidak memanggil platform tiap frame.
  bool? _talkBackEnabled;
  DateTime _talkBackCheckedAt = DateTime.fromMillisecondsSinceEpoch(0);

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
        _flushPending();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _flushPending();
      });
    } catch (e) {
      // Fallback jika device simulator belum punya tts engine
    }

    return this;
  }

  /// Membaca teks tanpa memotong ucapan yang sedang berjalan.
  ///
  /// - [isUrgent] (peringatan bahaya / ketukan pengguna) → boleh menghentikan
  ///   ucapan saat ini lalu bicara segera.
  /// - Kalimat biasa saat sedang berbicara → disimpan sebagai pesan tunggu
  ///   terbaru dan dibaca setelah ucapan sekarang selesai.
  Future<void> speak(String text, {bool isUrgent = false}) async {
    final now = DateTime.now();

    // Jika TalkBack aktif, serahkan ke TalkBack agar tidak ada dua suara.
    // Jika tidak, pakai flutter_tts.
    if (await isTalkBackEnabled()) {
      final action = TtsPolicy.decide(
        text: text,
        urgent: isUrgent,
        isSpeaking: false,
        lastSpoken: _lastSpoken,
        sinceLast: now.difference(_lastTime),
        debounce: _debounce,
      );
      if (action == TtsAction.ignore) return;
      _lastSpoken = text;
      _lastTime = now;
      SemanticsService.announce(text, TextDirection.ltr);
      return;
    }

    final action = TtsPolicy.decide(
      text: text,
      urgent: isUrgent,
      isSpeaking: _isSpeaking,
      lastSpoken: _lastSpoken,
      sinceLast: now.difference(_lastTime),
      debounce: _debounce,
    );

    switch (action) {
      case TtsAction.ignore:
        return;
      case TtsAction.enqueue:
        _pending = text;
        return;
      case TtsAction.preempt:
        _pending = null;
        try {
          await _tts.stop();
        } catch (_) {}
        await _speakNow(text);
      case TtsAction.speakNow:
        await _speakNow(text);
    }
  }

  /// Ucapkan [text] saat tidak ada ucapan berjalan (tanpa `stop()`).
  Future<void> _speakNow(String text) async {
    _lastSpoken = text;
    _lastTime = DateTime.now();
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Ucapkan pesan tunggu terbaru setelah ucapan sekarang selesai.
  void _flushPending() {
    final pending = _pending;
    if (pending == null || _isSpeaking) return;
    _pending = null;
    _speakNow(pending);
  }

  /// Mengecek status TalkBack (touch exploration) via channel native.
  /// Hasil di-cache selama 10 detik agar tidak membebani platform saat deteksi intensif.
  Future<bool> isTalkBackEnabled() async {
    final now = DateTime.now();
    if (_talkBackEnabled == null ||
        now.difference(_talkBackCheckedAt).inSeconds >= 10) {
      try {
        _talkBackEnabled = await _accessibilityEngine
                .invokeMethod<bool>('isTalkBackEnabled') ??
            false;
      } catch (_) {
        // Platform selain Android (mis. desktop uji) tidak punya channel ini.
        _talkBackEnabled = false;
      }
      _talkBackCheckedAt = now;
    }
    return _talkBackEnabled ?? false;
  }

  /// Menghentikan suara segera
  Future<void> stop() async {
    _pending = null;
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }
}
