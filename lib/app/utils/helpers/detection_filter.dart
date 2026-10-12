import 'dart:math' as math;
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

  /// Dimensi minimum sisi bounding box (lebar & tinggi).
  /// Sesuai hasil pengujian di HP: abaikan objek terlalu kecil (< 8% dimensi layar).
  static const double minNormalizedSide = 0.08;

  /// Dimensi maksimum sisi bounding box (lebar & tinggi).
  static const double maxNormalizedSide = 0.95;

  /// Batas rasio aspek koin (koin wajib mendekati lingkaran <= 1.8).
  static const double maxCoinAspectRatio = 1.8;

  /// Batas rasio aspek uang kertas (uang kertas tidak boleh terlalu tipis/memanjang <= 3.2).
  static const double maxBanknoteAspectRatio = 3.2;

  /// Margin terhadap tepi bingkai: uang yang menempel tepi berarti terpotong
  /// (parsial) → tidak boleh dibacakan sebagai nominal.
  static const double edgeMargin = 0.01;

  /// Ukuran jendela konfirmasi temporal (jumlah frame yang diingat).
  static const int temporalWindowSize = 3;

  /// Jumlah kemunculan wajib dalam jendela agar label dianggap stabil.
  static const int temporalRequiredHits = 2;

  /// Khusus Mode Baca Uang: apakah kotak ini "layak uang"?
  ///
  /// Menolak kotak kosong / terlalu kecil (< 8% dimensi) / melahap bingkai /
  /// menempel tepi / koin lonjong (keyboard) / uang kertas abnormal.
  static bool isPlausibleMoneyBox(Rect box, {String? label}) {
    if (box.isEmpty || box.width <= 0 || box.height <= 0) return false;

    // 1. Filter batas dimensi sisi (lebar & tinggi minimal 8%, maksimal 95%)
    // Tombol keyboard laptop atau noise kecil (< 8%) langsung gugur!
    if (box.width < minNormalizedSide ||
        box.height < minNormalizedSide ||
        box.width > maxNormalizedSide ||
        box.height > maxNormalizedSide) {
      return false;
    }

    // 2. Filter luas area
    final area = box.width * box.height;
    if (area < moneyMinNormalizedArea || area > moneyMaxNormalizedArea) {
      return false;
    }

    // 3. Margin terhadap tepi layar (menolak uang terpotong tepi layar)
    if (box.left <= edgeMargin ||
        box.right >= 1 - edgeMargin ||
        box.top <= edgeMargin ||
        box.bottom >= 1 - edgeMargin) {
      return false;
    }

    // 4. Filter Geometri Aspek Rasio:
    final double maxSide = math.max(box.width, box.height);
    final double minSide = math.max(math.min(box.width, box.height), 0.001);
    final double aspectRatio = maxSide / minSide;

    if (label != null) {
      final clean = label.trim().toLowerCase();
      final bool isCoin = clean.contains('coin');
      if (isCoin) {
        // Koin harus mendekati lingkaran (aspect ratio <= 1.8).
        // Tombol keyboard lonjong (spacebar, shift, dsb) langsung gugur!
        if (aspectRatio > maxCoinAspectRatio) {
          return false;
        }
      } else {
        // Uang kertas berbentuk persegi panjang wajar (aspect ratio <= 3.2).
        if (aspectRatio > maxBanknoteAspectRatio) {
          return false;
        }
      }
    } else {
      if (aspectRatio > maxBanknoteAspectRatio) {
        return false;
      }
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