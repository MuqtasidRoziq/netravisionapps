import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../data/models/vision_mode.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';
import '../../detector/controllers/detector_controller.dart';

/// Controller untuk fitur Cari Barang menggunakan pengenalan suara.
///
/// Alur:
/// 1. User menekan tombol mikrofon.
/// 2. Suara speaker/TTS dihentikan segera agar tidak bocor masuk ke mic.
/// 3. STT mendengarkan suara user dan mengekstrak kata kunci murni (misal: "cangkir").
/// 4. Controller membuka DetectorView dalam mode [VisionMode.itemSearch]
///    sambil meneruskan kata kunci yang diekstrak.
class ItemSearchController extends GetxController {
  final TtsService _ttsService = Get.find<TtsService>();
  final SpeechToText _speech = SpeechToText();

  final RxBool isListening = false.obs;
  final RxBool isInitialized = false.obs;
  final RxString recognizedText = ''.obs;
  final RxString extractedItem = ''.obs;
  final RxString statusMessage = 'Ketuk mikrofon lalu ucapkan nama barang'.obs;

  /// Daftar label objek yang didukung (model indoor COCO 80 kelas)
  static const List<String> supportedItems = [
    'cangkir', 'botol', 'kursi', 'sofa', 'meja makan', 'tempat tidur',
    'ponsel', 'laptop', 'televisi', 'tetikus', 'remot', 'keyboard',
    'buku', 'jam', 'vas', 'gunting', 'boneka beruang', 'pengering rambut',
    'sikat gigi', 'tas punggung', 'payung', 'tas tangan', 'koper',
    'garpu', 'pisau', 'sendok', 'mangkuk', 'kulkas', 'microwave',
    'oven', 'pemanggang roti', 'wastafel', 'sepeda', 'sepeda motor',
    'mobil', 'kucing', 'anjing', 'pisang', 'apel', 'roti isi', 'jeruk',
    'brokoli', 'wortel', 'sosis', 'pizza', 'donat', 'kue',
  ];

  /// Pemetaan sinonim umum ke label model AI
  static const Map<String, String> synonymMap = {
    'gelas': 'cangkir',
    'mug': 'cangkir',
    'cangkir kopi': 'cangkir',
    'cangkir teh': 'cangkir',
    'cangki': 'cangkir',
    'hp': 'ponsel',
    'handphone': 'ponsel',
    'smartphone': 'ponsel',
    'telepon': 'ponsel',
    'tumbler': 'botol',
    'botol minum': 'botol',
    'mouse': 'tetikus',
    'tv': 'televisi',
    'kasur': 'tempat tidur',
    'ransel': 'tas punggung',
    'tas': 'tas punggung',
  };

  @override
  void onInit() {
    super.onInit();
    _initSpeech();
  }

  @override
  void onReady() {
    super.onReady();
    _ttsService.speak(
      'Halaman Cari Barang. Ketuk tombol mikrofon di tengah, lalu sebutkan nama barang yang ingin dicari, misalnya cangkir atau botol.',
    );
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (error) => _handleSttError(error.errorMsg),
        onStatus: (status) => _handleSttStatus(status),
      );
      isInitialized.value = available;
      if (!available) {
        statusMessage.value = 'Mikrofon tidak tersedia di perangkat ini';
        _ttsService.speak('Mikrofon tidak tersedia di perangkat ini.');
      }
    } catch (e) {
      isInitialized.value = false;
      statusMessage.value = 'Gagal menginisialisasi mikrofon';
    }
  }

  /// Mulai mendengarkan perintah suara user.
  Future<void> startListening() async {
    if (!isInitialized.value) {
      _ttsService.speak('Mikrofon tidak siap. Coba lagi nanti.');
      return;
    }
    if (isListening.value) return;

    // 1. Matikan audio TTS segera agar suara speaker tidak masuk ke mikrofon
    await _ttsService.stop();

    HapticFeedback.heavyImpact();
    recognizedText.value = '';
    extractedItem.value = '';
    statusMessage.value = 'Mendengarkan... Silakan sebutkan nama barang.';

    // 2. Beri jeda 250ms agar speaker HP benar-benar senyap sebelum mic merekam
    await Future.delayed(const Duration(milliseconds: 250));

    isListening.value = true;
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 3),
        localeId: 'id_ID',
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  /// Hentikan listening secara manual.
  Future<void> stopListening() async {
    if (!isListening.value) return;
    await _speech.stop();
    isListening.value = false;
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    recognizedText.value = result.recognizedWords;

    if (result.finalResult) {
      isListening.value = false;
      final raw = result.recognizedWords.trim();
      if (raw.isEmpty) {
        statusMessage.value = 'Tidak ada suara terdeteksi. Coba lagi.';
        _ttsService.speak('Tidak ada suara terdeteksi. Silakan coba lagi.');
        return;
      }
      final item = extractItemKeyword(raw);
      extractedItem.value = item;
      statusMessage.value = 'Mencari: $item';
      _ttsService.speak('Mencari $item. Membuka kamera deteksi.', isUrgent: true);

      // Buka halaman detektor dalam mode pencarian barang
      Future.delayed(const Duration(milliseconds: 800), () {
        Get.delete<DetectorController>(force: true);
        Get.toNamed(
          Routes.DETECTOR,
          arguments: VisionMode.itemSearch,
          parameters: {'targetItem': item},
        );
      });
    }
  }

  /// Ekstrak kata kunci barang dari kalimat user secara akurat dan bersih.
  ///
  /// Contoh:
  /// - "cari cangkir" -> "cangkir"
  /// - "mencari ucapkan nama barang cangkir" -> "cangkir"
  /// - "tolong carikan saya botol minum dong" -> "botol"
  static String extractItemKeyword(String sentence) {
    String text = sentence.toLowerCase().trim();

    // Hapus tanda baca
    text = text.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // 1. Hapus frasa prompt sistem/TalkBack yang mungkin bocor ke mikrofon
    final systemPhrases = [
      'silakan ucapkan nama barang yang ingin dicari',
      'silakan ucapkan nama barang',
      'ucapkan nama barang yang ingin dicari',
      'ucapkan nama barang',
      'yang ingin dicari',
      'ingin dicari',
      'nama barang',
      'ketuk untuk berhenti',
      'ketuk mikrofon',
      'sedang mendengarkan',
      'mulai berbicara',
    ];
    for (final phrase in systemPhrases) {
      text = text.replaceAll(phrase, ' ');
    }

    // 2. Hapus kata awalan perintah
    final prefixPatterns = [
      RegExp(r'\b(tolong\s+)?(carikan|cariin|mencari|cari|temukan|cek|lihat|tengok)\b'),
      RegExp(r'\b(saya\s+)?(mau|ingin|minta|butuh)\s+(cari|mencari|temukan|lihat)?\b'),
      RegExp(r'\b(di\s*mana|dimana|ada\s*gak|ada\s*tidak|apakah\s*ada|mana)\b'),
      RegExp(r'\b(tolong|bisa|coba|saya)\b'),
    ];
    for (final pattern in prefixPatterns) {
      text = text.replaceAll(pattern, ' ');
    }

    // 3. Hapus kata akhiran pemanis kalimat (dong, ya, nih, deh, dsb.)
    final suffixPatterns = [
      RegExp(r'\b(dong|ya|sih|deh|nih|lah|nya)\b'),
    ];
    for (final pattern in suffixPatterns) {
      text = text.replaceAll(pattern, ' ');
    }

    // Bersihkan spasi ganda
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 4. Periksa apakah ada kata kunci yang cocok dengan sinonim
    for (final entry in synonymMap.entries) {
      final regex = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b');
      if (regex.hasMatch(text)) {
        return entry.value;
      }
    }

    // 5. Periksa apakah ada kata kunci yang persis cocok dengan supportedItems
    for (final item in supportedItems) {
      final regex = RegExp(r'\b' + RegExp.escape(item) + r'\b');
      if (regex.hasMatch(text)) {
        return item;
      }
    }

    // 6. Jika tidak ada di daftar khusus, ambil kata yang tersisa (maksimal 2 kata pertama)
    final words = text.split(' ').where((w) => w.isNotEmpty).take(2).toList();
    if (words.isNotEmpty) {
      return words.join(' ');
    }

    return sentence.trim();
  }

  void _handleSttError(String error) {
    isListening.value = false;
    if (error.contains('error_no_match') || error.contains('error_speech_timeout')) {
      statusMessage.value = 'Tidak terdeteksi. Coba lagi.';
      _ttsService.speak('Ucapan tidak terdeteksi. Silakan coba lagi.');
    } else {
      statusMessage.value = 'Terjadi kesalahan mikrofon.';
    }
  }

  void _handleSttStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      isListening.value = false;
    }
  }

  @override
  void onClose() {
    _speech.stop();
    super.onClose();
  }
}