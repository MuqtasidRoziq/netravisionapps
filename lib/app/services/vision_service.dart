import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:get/get.dart';
import '../data/models/vision_mode.dart';

/// Engine inferensi AI terpusat menggunakan FlutterVision (YOLOv8/TFLite).
/// Menerapkan konsep plug-and-play: otomatis me-load model & label sesuai mode yang aktif.
class VisionService extends GetxService {
  late FlutterVision _vision;

  final RxBool isModelLoaded = false.obs;
  final RxString statusMessage = 'Model belum dimuat'.obs;
  VisionMode? _currentLoadedMode;

  VisionMode? get currentLoadedMode => _currentLoadedMode;

  Future<VisionService> init() async {
    _vision = FlutterVision();
    return this;
  }

  /// Memuat model YOLO (.tflite) dan labels.txt sesuai mode yang dipilih pengguna
  Future<bool> loadModel(VisionMode mode) async {
    // Jika model untuk mode ini sudah aktif di memori, tidak perlu load ulang
    if (_currentLoadedMode == mode && isModelLoaded.value) {
      return true;
    }

    // Bersihkan model sebelumnya jika ada
    await closeModel();

    String modelPath = '';
    String labelPath = '';

    switch (mode) {
      case VisionMode.outdoor:
        modelPath = 'assets/models/outdoor/netravision_out.tflite';
        labelPath = 'assets/models/outdoor/labels.txt';
        break;
      case VisionMode.currency:
        modelPath = 'assets/models/rupiah/rupiah.tflite';
        labelPath = 'assets/models/rupiah/labels.txt';
        break;
      case VisionMode.indoor:
        // Gunakan model outdoor sebagai fallback cerdas jika model indoor belum dimasukkan
        modelPath = 'assets/models/outdoor/netravision_out.tflite';
        labelPath = 'assets/models/outdoor/labels.txt';
        break;
    }

    try {
      statusMessage.value = 'Memuat model ${mode.title}...';
      await _vision.loadYoloModel(
        modelPath: modelPath,
        labels: labelPath,
        modelVersion: 'yolov8',
        numThreads: 4, // Gunakan 4 core CPU agar inferensi kencang
        useGpu: true,  // Akselerasi GPU perangkat jika didukung
      );

      _currentLoadedMode = mode;
      isModelLoaded.value = true;
      statusMessage.value = 'Model ${mode.title} siap!';
      return true;
    } catch (e) {
      isModelLoaded.value = false;
      statusMessage.value = 'Gagal memuat model: $e';
      return false;
    }
  }

  /// Menjalankan deteksi AI langsung pada frame kamera real-time
  Future<List<Map<String, dynamic>>> detectOnFrame(CameraImage image) async {
    if (!isModelLoaded.value) return [];

    try {
      final results = await _vision.yoloOnFrame(
        bytesList: image.planes.map((plane) => plane.bytes).toList(),
        imageHeight: image.height,
        imageWidth: image.width,
        iouThreshold: 0.45,
        confThreshold: 0.35,  // Ambang batas keyakinan minimal 35%
        classThreshold: 0.35,
      );

      return results;
    } catch (e) {
      return [];
    }
  }

  /// Menutup model untuk menghemat RAM HP saat tidak digunakan
  Future<void> closeModel() async {
    if (isModelLoaded.value) {
      try {
        await _vision.closeYoloModel();
      } catch (_) {}
      isModelLoaded.value = false;
      _currentLoadedMode = null;
    }
  }

  @override
  void onClose() {
    closeModel();
    super.onClose();
  }
}