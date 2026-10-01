import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/vision_mode.dart';
import '../../../services/camera_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/vision_service.dart';
import '../../../utils/helpers/object_speech_helper.dart';

class DetectorController extends GetxController {
  final CameraService cameraService = Get.find<CameraService>();
  final TtsService ttsService = Get.find<TtsService>();
  final VisionService visionService = Get.find<VisionService>();

  late VisionMode mode;
  final RxString currentStatusText = 'Menyiapkan kamera & model AI...'.obs;
  final RxString lastDetectedObject = ''.obs;
  final RxBool isPaused = false.obs;

  bool _isDetecting = false; // Kunci Throttle agar frame kamera tidak bertumpuk/lag

  @override
  void onInit() {
    super.onInit();
    mode = Get.arguments is VisionMode ? Get.arguments as VisionMode : VisionMode.indoor;
    _initializeModeAndStartStream();
  }

  Future<void> _initializeModeAndStartStream() async {
    // 1. Suara sambutan mode awal
    await ttsService.speak(mode.announcement);

    // 2. Load model YOLO .tflite sesuai mode
    currentStatusText.value = 'Memuat model AI ${mode.title}...';
    final success = await visionService.loadModel(mode);

    if (!success) {
      currentStatusText.value = 'Gagal memuat model. Periksa file assets.';
      ttsService.speak('Peringatan: Gagal memuat model deteksi.');
      return;
    }

    currentStatusText.value = 'Mencari objek di depan Anda...';

    // 3. Pastikan kamera siap lalu mulai stream frame ke model
    if (cameraService.isInitialized.value) {
      _startDetectionStream();
    } else {
      // Tunggu hingga kamera siap
      ever(cameraService.isInitialized, (initialized) {
        if (initialized) _startDetectionStream();
      });
    }
  }

  /// Menghubungkan frame kamera langsung ke model YOLO
  void _startDetectionStream() {
    cameraService.startImageStream((CameraImage image) async {
      // Jika AI sedang sibuk memproses frame sebelumnya atau dijeda, LEWATKAN frame ini!
      if (_isDetecting || isPaused.value || !visionService.isModelLoaded.value) {
        return;
      }

      _isDetecting = true; // Kunci frame

      try {
        final List<Map<String, dynamic>> results =
            await visionService.detectOnFrame(image);

        if (results.isNotEmpty) {
          _processDetectionResults(results);
        }
      } catch (e) {
        // Abaikan frame error sesaat
      } finally {
        _isDetecting = false; // Buka kunci untuk frame berikutnya
      }
    });
  }

  /// Memproses hasil deteksi & mengucapkannya via Text-To-Speech
  void _processDetectionResults(List<Map<String, dynamic>> results) {
    // Filter hanya objek yang relevan untuk tunanetra
    final validDetections = results.where((item) {
      final tag = item['tag']?.toString() ?? '';
      return ObjectSpeechHelper.shouldAnnounce(tag, mode);
    }).toList();

    if (validDetections.isEmpty) return;

    // Prioritaskan jika ada rintangan berbahaya (lubang, tangga, kendaraan)
    Map<String, dynamic>? targetDetection;
    for (final det in validDetections) {
      final tag = det['tag']?.toString() ?? '';
      if (ObjectSpeechHelper.isDangerousObstacle(tag)) {
        targetDetection = det;
        break;
      }
    }

    // Jika tidak ada rintangan bahaya, ambil objek dengan confidence tertinggi
    targetDetection ??= validDetections.first;

    final String detectedLabel = targetDetection['tag']?.toString() ?? '';
    final isDangerous = ObjectSpeechHelper.isDangerousObstacle(detectedLabel);

    // Perbarui teks di layar UI
    lastDetectedObject.value = detectedLabel;
    currentStatusText.value = isDangerous
        ? '⚠️ Awas: $detectedLabel di depan!'
        : 'Terdeteksi: $detectedLabel';

    // Format kalimat dan ucapkan via TTS (dengan sistem Debounce anti-spam)
    final speechText = ObjectSpeechHelper.formatForTts(detectedLabel, mode);
    ttsService.speak(speechText, isUrgent: isDangerous);
  }

  /// Dipanggil saat tunanetra mengetuk layar kamera di mana saja
  void handleScreenTap() {
    HapticFeedback.mediumImpact();
    if (lastDetectedObject.value.isNotEmpty) {
      final speech = ObjectSpeechHelper.formatForTts(lastDetectedObject.value, mode);
      ttsService.speak('Objek di depan: $speech', isUrgent: true);
    } else {
      ttsService.speak('Belum ada objek terdeteksi di depan Anda.', isUrgent: true);
    }
  }

  /// Pause / Resume pemrosesan kamera
  void togglePause() {
    isPaused.value = !isPaused.value;
    if (isPaused.value) {
      ttsService.speak('Deteksi dijeda');
    } else {
      ttsService.speak('Deteksi dilanjutkan');
    }
  }

  @override
  void onClose() {
    cameraService.stopImageStream();
    ttsService.stop();
    super.onClose();
  }
}

