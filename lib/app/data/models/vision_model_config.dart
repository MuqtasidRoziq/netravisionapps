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
      modelPath: 'assets/models/rupiah/best.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.80,
      iouThreshold: 0.45,
    ),
    VisionMode.outdoor: VisionModelConfig(
      modelPath: 'assets/models/outdoor/netravision_out.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.35,
      iouThreshold: 0.45,
    ),
    // Model indoor saat ini: YOLO11n detect COCO 80 kelas. Model ini mengenali
    // orang/perabot tertentu, tetapi belum mendukung pintu, tangga, atau drop-off.
    VisionMode.indoor: VisionModelConfig(
      modelPath: 'assets/models/indoor/indoor_objects.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.25,
      iouThreshold: 0.45,
    ),
    // Mode Cari Barang: gunakan model indoor (COCO 80 kelas) dengan threshold
    // sensitif agar dapat mendeteksi barang yang dicari user.
    VisionMode.itemSearch: VisionModelConfig(
      modelPath: 'assets/models/indoor/indoor_objects.tflite',
      task: YOLOTask.detect,
      confidenceThreshold: 0.25,
      iouThreshold: 0.40,
    ),
  };

  static VisionModelConfig forMode(VisionMode mode) =>
      byMode[mode] ?? byMode[VisionMode.indoor]!;
}
