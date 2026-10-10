import 'spatial_estimator.dart';

/// Hasil keputusan pengumuman bahaya.
class DangerSpeechDecision {
  const DangerSpeechDecision({required this.speak, required this.urgent});

  /// Apakah harus membacakan peringatan sekarang.
  final bool speak;

  /// `true` = boleh memotong ucapan yang sedang jalan (bahaya menyerobot).
  final bool urgent;
}

/// Keputusan murni (tanpa platform) untuk meredam "Awas" dari deteksi bahaya.
///
/// Agar tidak seranah tetapi tetap aman:
/// - Bahaya pertama kali muncul → langsung diumumkan (urgent).
/// - Situasi memburuk → diumumkan bila jeda sejak "Awas" terakhir cukup
///   (anti-flicker antar label/band).
/// - Bahaya menetap → pengingat periodik singkat (non-urgent, tidak memotong).
class DangerSpeechPolicy {
  DangerSpeechPolicy._();

  static DangerSpeechDecision decide({
    required bool firstDanger,
    required bool worsened,
    required int msSinceLast,
    required int escalationMinGapMs,
    required int periodicCooldownMs,
  }) {
    if (firstDanger) {
      return const DangerSpeechDecision(speak: true, urgent: true);
    }
    if (worsened && msSinceLast >= escalationMinGapMs) {
      return const DangerSpeechDecision(speak: true, urgent: true);
    }
    if (msSinceLast >= periodicCooldownMs) {
      return const DangerSpeechDecision(speak: true, urgent: false);
    }
    return const DangerSpeechDecision(speak: false, urgent: false);
  }

  /// Apakah bahaya "memburuk" relatif terhadap frame sebelumnya.
  static bool worsened({
    required String label,
    required ProximityBand? band,
    required double? meters,
    required String prevLabel,
    required ProximityBand? prevBand,
    required double? prevMeters,
  }) {
    if (label != prevLabel) return true;
    if (band == ProximityBand.sangatDekat &&
        prevBand != ProximityBand.sangatDekat) {
      return true;
    }
    if (meters != null && prevMeters != null && meters < prevMeters * 0.7) {
      return true;
    }
    return false;
  }
}