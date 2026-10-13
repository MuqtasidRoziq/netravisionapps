import 'dart:math' as math;
import 'dart:ui';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Filter presisi hasil deteksi agar yang diumumkan hanya objek yang benar-benar
/// valid, stabil, dan — khusus Mode Baca Uang — memang berbentuk uang.
///
/// Fungsi murni (tanpa Dependency Injection) agar mudah diuji unit.
class DetectionFilter {
  DetectionFilter._();

  /// Luas minimum uang (fraksi bingkai kamera). Uang yang dipegang pengguna
  /// tunanetra 15–30 cm di depan kamera umumnya memenuhi minimal 6% luas layar.
  /// Objek kecil di kejauhan (tombol keyboard, ornamen meja, stiker) langsung gugur.
  static const double moneyMinNormalizedArea = 0.06;

  /// Luas maksimum (uang tidak boleh menelan layar penuh > 75% sampai hilang konteks).
  static const double moneyMaxNormalizedArea = 0.75;

  /// Dimensi minimum sisi pendek bounding box uang (lebar / tinggi minimal 14% layar).
  static const double minMoneyNormalizedSide = 0.14;

  /// Dimensi minimum sisi panjang bounding box uang (minimal 22% layar).
  static const double minMoneyLongSide = 0.22;

  /// Dimensi maksimum sisi bounding box (lebar & tinggi).
  static const double maxNormalizedSide = 0.95;

  /// Batas rasio aspek koin (koin wajib mendekati lingkaran 0.85 s/d 1.25).
  static const double minCoinAspectRatio = 0.85;
  static const double maxCoinAspectRatio = 1.25;

  /// Batas rasio aspek uang kertas Rupiah (Panjang / Lebar fisik Bank Indonesia: 1.86–2.32).
  /// Dengan toleransi sudut kemiringan kamera HP: 1.35 s/d 2.65.
  /// Objek bujur sangkar / mendekati kotak (aspect ratio < 1.35, misal touchpad, logo laptop,
  /// layar laptop, buku, gelas) LANGSUNG DITOLAK!
  /// Objek terlalu pipih (aspect ratio > 2.65, misal bilah keyboard penuh, penggaris) LANGSUNG DITOLAK!
  static const double minBanknoteAspectRatio = 1.35;
  static const double maxBanknoteAspectRatio = 2.65;

  /// Margin terhadap tepi bingkai: uang yang menempel tepi berarti terpotong
  /// (parsial) → tidak boleh dibacakan sebagai nominal.
  static const double edgeMargin = 0.02;

  /// Batas zona tengah kamera (titik tengah bounding box harus berada di area fokus tengah).
  static const double minCenterZone = 0.12;
  static const double maxCenterZone = 0.88;

  /// Ukuran jendela konfirmasi temporal default (jumlah frame yang diingat).
  static const int temporalWindowSize = 3;

  /// Jumlah kemunculan wajib dalam jendela agar label dianggap stabil.
  static const int temporalRequiredHits = 2;

  /// Konfirmasi temporal khusus mode baca uang: wajib muncul 3 dari 4 frame terakhir.
  static const int currencyTemporalWindowSize = 4;
  static const int currencyTemporalRequiredHits = 3;

  /// Khusus Mode Baca Uang: apakah kotak ini "layak uang"?
  ///
  /// Menolak kotak kosong / terlalu kecil (< 14% sisi, < 6% luas) / melahap bingkai /
  /// menempel tepi / di luar zona tengah / rasio aspek non-uang (keyboard, laptop, dsb).
  static bool isPlausibleMoneyBox(Rect box, {String? label}) {
    if (box.isEmpty || box.width <= 0 || box.height <= 0) return false;

    // 1. Filter batas dimensi sisi:
    // Sisi pendek minimal 14%, sisi panjang minimal 22%, maksimal 95%
    final double maxSide = math.max(box.width, box.height);
    final double minSide = math.max(math.min(box.width, box.height), 0.001);
    if (minSide < minMoneyNormalizedSide ||
        maxSide < minMoneyLongSide ||
        box.width > maxNormalizedSide ||
        box.height > maxNormalizedSide) {
      return false;
    }

    // 2. Filter luas area (uang wajib mencakup 6% - 75% layar)
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

    // 4. Filter zona fokus tengah kamera
    final centerX = (box.left + box.right) / 2;
    final centerY = (box.top + box.bottom) / 2;
    if (centerX < minCenterZone ||
        centerX > maxCenterZone ||
        centerY < minCenterZone ||
        centerY > maxCenterZone) {
      return false;
    }

    // 5. Filter Geometri Aspek Rasio:
    final double aspectRatio = maxSide / minSide;

    final clean = (label ?? '').trim().toLowerCase();
    final bool isCoin = clean.contains('coin');
    if (isCoin) {
      // Koin harus bulat (rasio 0.85 s/d 1.25)
      if (aspectRatio < minCoinAspectRatio || aspectRatio > maxCoinAspectRatio) {
        return false;
      }
    } else {
      // Uang kertas Rupiah asli berasio 1.86–2.32.
      // Dibatasi ketat ke rentang 1.35 s/d 2.65.
      // Laptop/layar/touchpad/buku (rasio < 1.35) atau bilah keyboard panjang (rasio > 2.65) otomatis GUGUR!
      if (aspectRatio < minBanknoteAspectRatio ||
          aspectRatio > maxBanknoteAspectRatio) {
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