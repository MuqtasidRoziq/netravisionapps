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

  /// Prioritas ucapan yang saat ini sedang berbunyi.
  TtsPriority _currentPriority = TtsPriority.normal;

  /// Pesan terbaru yang menunggu ucapan saat ini selesai (anti-potong).
  String? _pending;
  TtsPriority _pendingPriority = TtsPriority.normal;

  /// Saat true, mikrofon sedang mendengarkan (STT) → tahan SEMUA ucapan agar
  /// suara speaker tidak bocor/terekam kembali oleh mikrofon.
  bool _listeningGate = false;

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

      // Pastikan `speak()` benar-benar menunggu sampai suara selesai — krusial
      // agar mic tidak dibuka saat speaker masih berbunyi (sumber "gema").
      //
      // Catatan: `setAudioAttributesForNavigation()` sengaja TIDAK dipakai.
      // Pengaturan atribut audio itu bisa membuat engine TTS memegang audio
      // focus, sehingga SpeechRecognizer tidak menerima audio dan mic terasa
      // "tidak terdengar". Keheningan sebelum mic dibuka sudah dijamin oleh
      // `beginListeningSession()` (memanggil `stop()`).
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _currentPriority = TtsPriority.normal;
        _flushPending();
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _currentPriority = TtsPriority.normal;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _currentPriority = TtsPriority.normal;
        _flushPending();
      });
    } catch (e) {
      // Fallback jika device simulator belum punya tts engine
    }

    return this;
  }

  /// Membaca teks tanpa memotong ucapan yang sedang berjalan.
  ///
  /// - [priority] menentukan siapa yang boleh memotong siapa (lihat
  ///   [TtsPriority]). Default [TtsPriority.normal].
  /// - [isUrgent] dipertahankan untuk kompatibilitas: `true` setara dengan
  ///   [TtsPriority.danger] (menyerobot).
  /// - Kalimat biasa/lebih rendah saat sedang berbicara disimpan sebagai pesan
  ///   tunggu berprioritas tertinggi dan dibaca setelah ucapan sekarang selesai.
  Future<void> speak(
    String text, {
    TtsPriority? priority,
    bool isUrgent = false,
  }) async {
    final resolved = priority ??
        (isUrgent ? TtsPriority.danger : TtsPriority.normal);
    final now = DateTime.now();

    // Selama mikrofon mendengarkan, tahan SEMUA ucapan (termasuk SOS) agar
    // tidak terekam kembali oleh STT. Pesan di-flush setelah sesi dengar usai.
    if (_listeningGate) {
      if (_pending == null || resolved.index >= _pendingPriority.index) {
        _pending = text;
        _pendingPriority = resolved;
      }
      return;
    }

    // Jika TalkBack aktif, serahkan ke TalkBack agar tidak ada dua suara.
    // Jika tidak, pakai flutter_tts.
    if (await isTalkBackEnabled()) {
      final action = TtsPolicy.decide(
        text: text,
        priority: resolved,
        currentPriority: _currentPriority,
        isSpeaking: false,
        lastSpoken: _lastSpoken,
        sinceLast: now.difference(_lastTime),
        debounce: _debounce,
      );
      if (action == TtsAction.ignore) return;
      _lastSpoken = text;
      _lastTime = now;
      // ignore: deprecated_member_use
      SemanticsService.announce(text, TextDirection.ltr);
      return;
    }

    final action = TtsPolicy.decide(
      text: text,
      priority: resolved,
      currentPriority: _currentPriority,
      isSpeaking: _isSpeaking,
      lastSpoken: _lastSpoken,
      sinceLast: now.difference(_lastTime),
      debounce: _debounce,
    );

    switch (action) {
      case TtsAction.ignore:
        return;
      case TtsAction.enqueue:
        // Simpan pesan tunggu dengan prioritas tertinggi; jangan biarkan
        // arahan penting ditimpa info biasa.
        if (_pending == null || resolved.index >= _pendingPriority.index) {
          _pending = text;
          _pendingPriority = resolved;
        }
        return;
      case TtsAction.preempt:
        _pending = null;
        _pendingPriority = TtsPriority.normal;
        try {
          await _tts.stop();
        } catch (_) {}
        await _speakNow(text, resolved);
      case TtsAction.speakNow:
        await _speakNow(text, resolved);
    }
  }

  /// Membaca teks dan menunggu hingga suara selesai sepenuhnya.
  /// Sangat penting saat berkoordinasi dengan mikrofon (STT) agar mic tidak merekam suara speaker sendiri.
  Future<void> speakAndWait(
    String text, {
    TtsPriority? priority,
    bool isUrgent = false,
    Duration maxWait = const Duration(seconds: 12),
  }) async {
    // `speak()` menunggu sampai suara selesai (awaitSpeakCompletion). Tetapi
    // bila engine TTS tidak pernah memanggil completion, await ini bisa
    // menggantung selamanya sehingga mic TIDAK PERNAH dibuka (gejala "tidak
    // terdengar"). Batasi dengan [maxWait] agar selalu lanjut.
    try {
      await speak(text, priority: priority, isUrgent: isUrgent)
          .timeout(maxWait);
    } catch (_) {}
    // Sisa waktu untuk memastikan benar-benar hening bila handler lebih lambat.
    final start = DateTime.now();
    while (_isSpeaking && DateTime.now().difference(start) < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    // Jeda singkat agar hardware speaker benar-benar senyap sebelum mic dibuka.
    await Future.delayed(const Duration(milliseconds: 350));
  }

  /// Tandai bahwa mikrofon (STT) akan segera aktif: hentikan TTS lebih dulu
  /// agar mesin suara melepas audio focus (bila masih dipegang, SpeechRecognizer
  /// tidak menerima audio → gejala "tidak terdengar"), lalu tahan semua ucapan
  /// agar suara speaker tidak terekam kembali oleh mikrofon.
  Future<void> beginListeningSession() async {
    _listeningGate = true;
    // Jangan biarkan panggilan platform yang menggantung menahan mic dibuka.
    try {
      await stop().timeout(const Duration(milliseconds: 800));
    } catch (_) {}
    // Beri jeda agar speaker & audio focus benar-benar lepas sebelum mic dibuka.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Sesi dengar selesai: lepaskan tahanan dan ucapkan pesan yang tertunda.
  void endListeningSession() {
    _listeningGate = false;
    _currentPriority = TtsPriority.normal;
    _flushPending();
  }

  /// Ucapkan [text] saat tidak ada ucapan berjalan (tanpa `stop()`).
  Future<void> _speakNow(String text, TtsPriority priority) async {
    _lastSpoken = text;
    _lastTime = DateTime.now();
    _currentPriority = priority;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Ucapkan pesan tunggu berprioritas tertinggi setelah ucapan selesai.
  void _flushPending() {
    final pending = _pending;
    if (pending == null || _isSpeaking) return;
    final pendingPriority = _pendingPriority;
    _pending = null;
    _pendingPriority = TtsPriority.normal;
    _speakNow(pending, pendingPriority);
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
    _pendingPriority = TtsPriority.normal;
    _currentPriority = TtsPriority.normal;
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }
}
