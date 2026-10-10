import 'package:get/get.dart';
import 'package:vibration/vibration.dart';

import '../utils/helpers/spatial_estimator.dart';

/// Getaran taktil proporsional jarak untuk tunanetra.
///
/// Sebagian perangkat (termasuk yang dipakai uji) tidak mendukung kontrol
/// `amplitude` (`VibratorInfo.mCapabilities` kosong), jadi intensitas tidak
/// diatur via amplitude. Sebagai gantinya dipakai POLA DENYUT BERULANG
/// (`VibrationEffect.createWaveform`): selama objek dekat, getar mengulang
/// terus-menerus; tempo pola menandai jarak (cepat = sangat dekat, pelan =
/// dekat, tegas = bahaya).
class VibrationService extends GetxService {
  /// Pola denyut aktif saat ini; `null` = tidak bergetar.
  List<int>? _activePattern;

  /// Pola denyut berulang untuk satu konteks deteksi.
  ///
  /// Format `[delay, on, off, on, ...]`; `null` berarti tidak bergetar.
  /// Device tanpa amplitude control tetap menjalankan pola dengan kekuatan
  /// default, jadi tempo (bukan amplitude) yang membedakan jarak.
  static List<int>? patternFor({
    required ProximityBand band,
    required bool dangerous,
  }) {
    if (dangerous) return const [0, 350, 120, 350];
    switch (band) {
      case ProximityBand.sangatDekat:
        return const [0, 260, 160, 260];
      case ProximityBand.dekat:
        return const [0, 200, 200, 300];
      case ProximityBand.sedang:
      case ProximityBand.jauh:
        return null;
    }
  }

  /// Tembakkan getaran denyut berulang untuk objek berbahaya / dekat.
  ///
  /// [band] ganti `null`/`sedang`/`jauh` → hentikan getaran. Pola yang sama
  /// tidak di-restart agar tidak terlihat "kedip".
  void vibrateNear({
    required ProximityBand band,
    required bool dangerous,
  }) {
    final pattern = patternFor(band: band, dangerous: dangerous);
    if (pattern == null) {
      stop();
      return;
    }
    if (_activePattern == pattern) return;
    _activePattern = pattern;
    try {
      Vibration.vibrate(pattern: pattern, repeat: 0);
    } catch (_) {
      // Platform tanpa dukungan getar / channel error → abaikan.
    }
  }

  /// Hentikan semua getaran.
  void stop() {
    _activePattern = null;
    try {
      Vibration.cancel();
    } catch (_) {
      // abaikan
    }
  }
}