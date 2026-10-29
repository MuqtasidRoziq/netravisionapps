import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'vision_mode.dart';

/// Sumber kebenaran tunggal pemetaan fitur (mode) → model AI yang dipakai.
///
/// Setiap mode punya `modelPath`, `task`, dan ambang threshold sendiri agar
/// tidak ada mode yang salah-sambung ke model lain (mis. saat Mode Baca Uang
/// tidak boleh diproses model outdoor).
class VisionModelConfig {
  const VisionModelConfig({
    required this.modelPath,
    required this.task,
    required this.confidenceThreshold,
    required this.iouThreshold,
  });

  final String modelPath;
  final YOLOTask task;

  /// Ambang keyakinan mininum agar deteksi diumumkan.
  /// Mode Baca Uang sengaja tinggi (0.60): model rupiah YOLO26n rawan false
  /// positive 40–55% pada objek non-uang (telapak, dompet, meja).
  final double confidenceThreshold;
  final double iouThreshold;

  static const Map<VisionMode, VisionModelConfig> byMode = {
    VisionMode.currency: VisionModelConfig(
      modelPath: 'assets/models/rupiah/rupiah.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.60,
      iouThreshold: 0.50,
    ),
    VisionMode.outdoor: VisionModelConfig(
      modelPath: 'assets/models/outdoor/netravision_out.tflite',
      task: YOLOTask.segment,
      confidenceThreshold: 0.45,
      iouThreshold: 0.45,
    ),
    // Model indoor: YOLO11n 50 kelas indoor terpilih (mencakup perabotan, alat makan,
    // barang pribadi, perangkat elektronik, dan bebas dari 30 kelas kendaraan/outdoor).
    VisionMode.indoor: VisionModelConfig(
      modelPath: 'assets/models/indoor/indoor_objects.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.45,
      iouThreshold: 0.45,
    ),
    // Pencarian Objek Tunggal: memanfaatkan model indoor (50 kelas) dengan ambang
    // batas responsif (0.25) agar target tidak mudah hilang saat kamera bergerak.
    VisionMode.findObject: VisionModelConfig(
      modelPath: 'assets/models/indoor/indoor_objects.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.25,
      iouThreshold: 0.45,
    ),
  };

  static VisionModelConfig forMode(VisionMode mode) =>
      byMode[mode] ?? byMode[VisionMode.outdoor]!;
}