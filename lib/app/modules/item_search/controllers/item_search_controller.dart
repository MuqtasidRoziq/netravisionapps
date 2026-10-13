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
/// 2. STT mendengarkan dan mengekstrak kata kunci barang.
/// 3. Controller membuka DetectorView dalam mode [VisionMode.search]
///    sambil meneruskan kata kunci yang diekstrak.
class ItemSearchController extends GetxController {
  final TtsService _ttsService = Get.find<TtsService>();
  final SpeechToText _speech = SpeechToText();

  final RxBool isListening = false.obs;
  final RxBool isInitialized = false.obs;
  final RxString recognizedText = ''.obs;
  final RxString extractedItem = ''.obs;
  final RxString statusMessage = 'Ketuk mikrofon lalu ucapkan nama barang'.obs;

  @override
  void onInit() {
    super.onInit();
    _initSpeech();
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

    HapticFeedback.mediumImpact();
    recognizedText.value = '';
    extractedItem.value = '';
    statusMessage.value = 'Sedang mendengarkan...';
    _ttsService.speak('Silakan ucapkan nama barang yang ingin dicari.', isUrgent: true);

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
      final item = _extractItemKeyword(raw);
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

  /// Ekstrak kata kunci barang dari kalimat user.
  ///
  /// Contoh input: "tolong carikan saya botol minum"
  /// Output: "botol minum"
  String _extractItemKeyword(String sentence) {
    final lower = sentence.toLowerCase();

    // Hapus frase perintah umum yang tidak relevan
    final prefixPatterns = [
      RegExp(r'^(tolong\s+)?(carikan|cari|temukan|cek|cari tahu)\s+(saya\s+)?'),
      RegExp(r'^(saya\s+)?(mau|ingin|minta)\s+(cari|mencari|temukan)\s+'),
      RegExp(r'^(di mana|dimana|ada gak|ada tidak)\s+(ada\s+)?'),
      RegExp(r'^(apakah\s+)?ada\s+'),
    ];

    String cleaned = lower;
    for (final pattern in prefixPatterns) {
      cleaned = cleaned.replaceFirst(pattern, '').trim();
    }

    // Ambil maksimal 4 kata pertama sebagai kata kunci item
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(4).toList();
    if (words.isEmpty) return sentence.trim();
    return words.join(' ');
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