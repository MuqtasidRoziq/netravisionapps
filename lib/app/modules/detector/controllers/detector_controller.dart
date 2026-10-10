import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../data/models/vision_mode.dart';
import '../../../data/models/vision_model_config.dart';
import '../../../services/tts_service.dart';
import '../../../utils/helpers/detection_filter.dart';
import '../../../utils/helpers/object_speech_helper.dart';

/// Orkestrasi deteksi NetraVision di atas plugin `ultralytics_yolo`.
///
/// Kamera + inferensi ditangani native oleh [YOLOView] (layout NCHW didukung
/// penuh). Controller ini hanya: memilih model sesuai mode, menyaring hasil
/// deteksi, menentukan prioritas bahaya, lalu membacakan lewat TTS.
class DetectorController extends GetxController with WidgetsBindingObserver {
  final TtsService ttsService = Get.find<TtsService>();

  /// Dikendalikan secara imperatif dan dipasang ke [YOLOView] di layer view.
  final YOLOViewController yoloController = YOLOViewController();

  late VisionMode mode;
  final RxString currentStatusText = 'Menyiapkan kamera & model AI...'.obs;
  final RxString lastDetectedObject = ''.obs;
  final RxBool isPaused = false.obs;

  // Throttle: proses maksimal 2 frame per detik agar CPU & TTS tidak dibanjiri.
  static const _frameIntervalMs = 500;
  DateTime _lastFrameTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Histori classIndex frame-frame terakhir yang diproses, untuk konfirmasi
  // temporal (label baru hanya diumumkan bila stabil beberapa frame).
  final List<int> _recentClassIndices = [];

  /// Konfigurasi model untuk mode aktif (sumber tunggal di
  /// [VisionModelConfig]): path model, task, dan ambang threshold.
  VisionModelConfig get modelConfig => VisionModelConfig.forMode(mode);

  /// Batas maksimum deteksi per frame; mode uang sengaja kecil agar tidak
  /// "rame" dibanjiri deteksi palsu.
  int get _maxNumItems => mode == VisionMode.currency ? 5 : 30;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    mode = Get.arguments is VisionMode
        ? Get.arguments as VisionMode
        : VisionMode.indoor;
    // Terapkan segera; YOLOViewController mengingat nilainya dan menyamplikannya
    // ke native saat platform view menempel.
    yoloController.setNumItemsThreshold(_maxNumItems);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Hentikan suara & preview saat app ke background agar hemat baterai.
        ttsService.stop();
        yoloController.pause();
        break;
      case AppLifecycleState.resumed:
        if (!isPaused.value) {
          yoloController.resume();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Dipanggil [YOLOView] setelah model berhasil dimuat/diganti.
  void handleModelLoad(String modelPath, YOLOTask? task) {
    currentStatusText.value = mode == VisionMode.currency
        ? 'Arahkan uang ke kamera...'
        : 'Mencari objek di depan Anda...';
    ttsService.speak(mode.announcement);
  }

  /// Dipanggil [YOLOView] bila model gagal dimuat.
  void handleModelError(Object error, String modelPath, YOLOTask? task) {
    currentStatusText.value = 'Gagal memuat model. Periksa file assets.';
    ttsService.speak('Peringatan: Gagal memuat model deteksi.');
  }

  /// Callback hasil inferensi per frame dari [YOLOView].
  void handleResults(List<YOLOResult> results) {
    if (isPaused.value || results.isEmpty) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameTime).inMilliseconds < _frameIntervalMs) {
      return;
    }
    _lastFrameTime = now;

    _processDetectionResults(results);
  }

  void _processDetectionResults(List<YOLOResult> results) {
    // 1. Saring label yang layak diumumkan + (khusus uang) bentuk kotak yang
    //    memang layak uang (ukuran cukup, tidak terpotong tepi).
    final validDetections = results
        .where((r) => ObjectSpeechHelper.shouldAnnounce(r.className, mode))
        .where((r) =>
            mode != VisionMode.currency ||
            DetectionFilter.isPlausibleMoneyBox(r.normalizedBox))
        .toList();
    if (validDetections.isEmpty) return;

    // 2. Prioritas: rintangan berbahaya langsung; selain itu ambil deteksi
    //    terbaik (confidence × luas) — uang asli besar menang atas palsu kecil.
    final dangerous =
        validDetections
            .where(
              (d) => ObjectSpeechHelper.isDangerousObstacle(d.className),
            )
            .toList();
    final bool isDangerous = dangerous.isNotEmpty;
    final YOLOResult targetDetection = isDangerous
        ? dangerous.first
        : DetectionFilter.selectBest(validDetections);

    // 3. Konfirmasi temporal: label baru hanya diumumkan bila stabil (muncul
    //    2 dari 3 frame terakhir) agar blip satu frame tidak jadi suara.
    //    Rintangan berbahaya dikecualikan — keselamatan tidak menunggu.
    _recentClassIndices.add(targetDetection.classIndex);
    if (_recentClassIndices.length > DetectionFilter.temporalWindowSize) {
      _recentClassIndices.removeAt(0);
    }
    if (!isDangerous &&
        !DetectionFilter.isStable(_recentClassIndices, targetDetection.classIndex)) {
      return;
    }

    final String detectedLabel = targetDetection.className;
    lastDetectedObject.value = detectedLabel;
    final displayName = ObjectSpeechHelper.formatDisplayName(detectedLabel, mode);
    currentStatusText.value = isDangerous
        ? '⚠️ Awas: $displayName di depan!'
        : 'Terdeteksi: $displayName';

    final speechText = ObjectSpeechHelper.formatForTts(detectedLabel, mode);
    ttsService.speak(speechText, isUrgent: isDangerous);
  }

  void handleScreenTap() {
    HapticFeedback.mediumImpact();
    if (lastDetectedObject.value.isNotEmpty) {
      final speech =
          ObjectSpeechHelper.formatForTts(lastDetectedObject.value, mode);
      if (mode == VisionMode.currency) {
        ttsService.speak(speech, isUrgent: true);
      } else {
        ttsService.speak('Objek di depan: $speech', isUrgent: true);
      }
    } else {
      if (mode == VisionMode.currency) {
        ttsService.speak('Belum ada uang terdeteksi di depan kamera.',
            isUrgent: true);
      } else {
        ttsService.speak('Belum ada objek terdeteksi di depan Anda.',
            isUrgent: true);
      }
    }
  }

  void togglePause() {
    isPaused.value = !isPaused.value;
    if (isPaused.value) {
      yoloController.pause();
      ttsService.speak('Deteksi dijeda');
    } else {
      yoloController.resume();
      ttsService.speak('Deteksi dilanjutkan');
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    yoloController.dispose(); // Tutup stream zoom/lens/focus milik controller.
    ttsService.stop();
    super.onClose();
  }
}
