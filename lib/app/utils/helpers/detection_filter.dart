import 'dart:ui';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Filter presisi hasil deteksi agar yang diumumkan hanya objek yang benar-benar
/// valid, stabil, dan — khusus Mode Baca Uang — memang berbentuk uang.
///
/// Fungsi murni (tanpa Dependency Injection) agar mudah diuji unit.
class DetectionFilter {
  DetectionFilter._();

  /// Luas minimum uang (fraksi bingkai kamera). Uang yang terlalu kecil =
  /// terlalu jauh sehingga pembacaan nominalnya tidak tepercaya.
  static const double moneyMinNormalizedArea = 0.03;

  /// Luas maksimum (jaga-jaga kotak aneh yang menelan seluruh bingkai).
  static const double moneyMaxNormalizedArea = 0.85;

  /// Margin terhadap tepi bingkai: uang yang menempel tepi berarti terpotong
  /// (parsial) → tidak boleh dibacakan sebagai nominal.
  static const double edgeMargin = 0.01;

  /// Ukuran jendela konfirmasi temporal (jumlah frame yang diingat).
  static const int temporalWindowSize = 3;

  /// Jumlah kemunculan wajib dalam jendela agar label dianggap stabil.
  static const int temporalRequiredHits = 2;

  /// Khusus Mode Baca Uang: apakah kotak ini "layak uang"?
  ///
  /// Menolak kotak kosong / terlalu kecil / melahap bingkai / menempel tepi,
  /// sehingga objek non-uang dan uang parsial tidak sempat diumumkan.
  static bool isPlausibleMoneyBox(Rect box) {
    if (box.isEmpty || box.width <= 0 || box.height <= 0) return false;
    final area = box.width * box.height;
    if (area < moneyMinNormalizedArea || area > moneyMaxNormalizedArea) {
      return false;
    }
    if (box.left <= edgeMargin ||
        box.right >= 1 - edgeMargin ||
        box.top <= edgeMargin ||
        box.bottom >= 1 - edgeMargin) {
      return false;
    }
    return true;
  }

  /// Pilih deteksi "terbaik" dari kandidat yang sudah lolos filter.
  ///
  /// Skor = confidence × luas kotak: mengutamakan objek yang yakin DAN besar
  /// (dekat kamera), bukan sekadar deteksi pertama dalam daftar.
  static YOLOResult selectBest(List<YOLOResult> candidates) {
    assert(candidates.isNotEmpty, 'selectBest butuh minimal 1 kandidat');
    var best = candidates.first;
    var bestScore = -1.0;
    for (final candidate in candidates) {
      final box = candidate.normalizedBox;
      final area = box.isEmpty ? 0.0 : box.width * box.height;
      final score = candidate.confidence * area;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  /// Konfirmasi temporal: apakah classIndex [classIndex] cukup stabil pada
  /// jendela [window] (frame-frame terakhir yang diproses)?
  ///
  /// Stabil = jendela sudah penuh dan classIndex muncul ≥ [temporalRequiredHits].
  /// Ini mencegah blip satu frame (false positive acak) langsung menjadi suara.
  static bool isStable(
    List<int> window,
    int classIndex, {
    int windowSize = temporalWindowSize,
    int requiredHits = temporalRequiredHits,
  }) {
    if (window.length < windowSize) return false;
    final hits = window.where((i) => i == classIndex).length;
    return hits >= requiredHits;
  }
}