import 'dart:math';
import 'dart:ui';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Zona horizontal objek relatif terhadap bingkai kamera.
enum HorizontalZone {
  /// cx < 0.35 — di samping kiri pengguna.
  kiri,

  /// 0.35 <= cx <= 0.65 — tepat di depan pengguna.
  depan,

  /// cx > 0.65 — di samping kanan pengguna.
  kanan,
}

/// Zona vertikal objek relatif terhadap bingkai kamera.
enum VerticalZone {
  /// cy < 0.33 — objek di bagian atas pandangan (mis. bahaya menggantung).
  atas,

  /// 0.33 <= cy <= 0.66 — ketinggian pandangan normal.
  tengah,

  /// cy > 0.66 — objek dekat permukaan tanah/lantai (mis. lubang, perabot).
  bawah,
}

/// Kisaran kedekatan objek berdasarkan ukuran kotak pada bingkai kamera.
enum ProximityBand {
  /// luas kotak >= 0.20 — sangat dekat (sekitar < 1 m).
  sangatDekat,

  /// luas kotak >= 0.08 — dekat.
  dekat,

  /// luas kotak >= 0.03 — sedang.
  sedang,

  /// selain itu — jauh.
  jauh,
}

/// Informasi spasial hasil deteksi: posisi + kedekatan + perkiraan jarak.
class SpatialInfo {
  const SpatialInfo({
    required this.horizontal,
    required this.vertical,
    required this.band,
    this.meters,
  });

  final HorizontalZone horizontal;
  final VerticalZone vertical;
  final ProximityBand band;

  /// Perkiraan jarak dalam meter (estimasi kasar, `null` bila kelas tidak
  /// punya referensi ukuran fisik).
  final double? meters;
}

/// Estimasi posisi & jarak objek dari `YOLOResult.normalizedBox`.
///
/// Murni (tanpa plugin/platform) agar mudah diuji unit. Jarak DIPERKIRAKAN
/// dari lebar fisik referensi per kelas + asumsi FOV kamera ~65° — bukan dari
/// sensor depth — jadi akurasinya ±40% dan hanya cocok untuk "sekitar X meter".
class SpatialEstimator {
  SpatialEstimator._();

  /// Batas kiri/kanan zona horizontal (fraksi lebar frame, 0..1).
  static const double hLeftBound = 0.35;
  static const double hRightBound = 0.65;

  /// Batas atas/bawah zona vertikal (fraksi tinggi frame, 0..1).
  static const double vLowBound = 0.33;
  static const double vHighBound = 0.66;

  /// Asumsi FOV horizontal kamera ponsel (derajat). Dipakai untuk estimasi
  /// meter; sesuaikan bila hasil terasa meleset pada perangkat tertentu.
  static const double assumedHorizontalFovDegrees = 65.0;

  /// Ambang luas kotak (fraksi frame) untuk tiap band kedekatan.
  static const double veryCloseArea = 0.20;
  static const double closeArea = 0.08;
  static const double mediumArea = 0.03;

  /// Lebar fisik (meter) per kelas — referensi untuk estimasi jarak.
  /// Kunci pakai label Bahasa Indonesia aplikasi (fallback Inggris).
  static const Map<String, double> referenceWidthMeters = {
    'orang': 0.45,
    'person': 0.45,
    'mobil': 1.8,
    'car': 1.8,
    'sepeda motor': 0.8,
    'motorcycle': 0.8,
    'bus': 2.6,
    'truk': 2.5,
    'truck': 2.5,
    'kereta api': 3.0,
    'train': 3.0,
    'bajaj': 1.4,
    'sepeda': 0.7,
    'bicycle': 0.7,
    'perahu': 1.5,
    'boat': 1.5,
    'kursi': 0.5,
    'chair': 0.5,
    'sofa': 0.9,
    'couch': 0.9,
    'meja makan': 1.2,
    'dining table': 1.2,
    'kulkas': 0.6,
    'refrigerator': 0.6,
    'pintu': 0.9,
    'door': 0.9,
    'bangku': 0.6,
    'bench': 0.6,
    'tanaman pot': 0.4,
    'potted plant': 0.4,
    'toilet': 0.45,
    'wastafel': 0.5,
    'sink': 0.5,
    'oven': 0.6,
    'kompor': 0.6,
    'televisi': 1.0,
    'tv': 1.0,
    'tiang': 0.3,
    'tangga': 1.0,
    'jembatan': 3.0,
    'bridge': 3.0,
    'papan reklame': 1.0,
    'hewan': 0.8,
  };

  /// Zona horizontal dari titik tengah-x kotak.
  static HorizontalZone classifyHorizontal(Rect box) {
    final cx = (box.left + box.right) / 2;
    if (cx < hLeftBound) return HorizontalZone.kiri;
    if (cx > hRightBound) return HorizontalZone.kanan;
    return HorizontalZone.depan;
  }

  /// Zona vertikal dari titik tengah-y kotak.
  static VerticalZone classifyVertical(Rect box) {
    final cy = (box.top + box.bottom) / 2;
    if (cy < vLowBound) return VerticalZone.atas;
    if (cy > vHighBound) return VerticalZone.bawah;
    return VerticalZone.tengah;
  }

  /// Band kedekatan dari luas kotak (fraksi frame).
  static ProximityBand classifyProximity(Rect box) {
    final area = box.width * box.height;
    if (area >= veryCloseArea) return ProximityBand.sangatDekat;
    if (area >= closeArea) return ProximityBand.dekat;
    if (area >= mediumArea) return ProximityBand.sedang;
    return ProximityBand.jauh;
  }

  /// Lebar fisik referensi untuk [label]; `null` bila tidak dikenal.
  static double? referenceWidthOf(String label) {
    final clean = label.trim().toLowerCase();
    return referenceWidthMeters[clean];
  }

  /// Estimasi jarak (meter) ke objek dari lebar kotak & lebar fisik kelas.
  ///
  /// Mengasumsikan frame mencakup [assumedHorizontalFovDegrees] secara
  /// horizontal: `jarak = lebarReferensi / (2 * tan(setengah sudut objek))`.
  static double? estimateMeters(Rect box, String label) {
    final refWidth = referenceWidthOf(label);
    if (refWidth == null || box.isEmpty || box.width <= 0) return null;
    final halfAngle =
        0.5 * assumedHorizontalFovDegrees * box.width * (pi / 180);
    if (halfAngle <= 0) return null;
    return refWidth / (2 * tan(halfAngle));
  }

  /// Susun [SpatialInfo] lengkap untuk satu hasil deteksi.
  static SpatialInfo of(YOLOResult result) {
    final box = result.normalizedBox;
    return SpatialInfo(
      horizontal: classifyHorizontal(box),
      vertical: classifyVertical(box),
      band: classifyProximity(box),
      meters: estimateMeters(box, result.className),
    );
  }
}