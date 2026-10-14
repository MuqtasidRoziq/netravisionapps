import 'package:vibration/vibration.dart';

import '../utils/helpers/indoor_assist_engine.dart';

/// Haptik burst khusus Mode Dalam Ruangan.
///
/// Pola selalu selesai sendiri (`repeat: -1`). Motor tunggal hanya menyatakan
/// urgensi, bukan arah, karena arah getaran pada ponsel tidak dapat dibedakan.
class IndoorHapticService {
  IndoorHapticService._();

  static const List<int> warningPattern = [0, 110, 80, 110];
  static const List<int> criticalPattern = [0, 160, 70, 160, 70, 220];

  static Future<void> alert(IndoorRiskLevel risk) async {
    final pattern = switch (risk) {
      IndoorRiskLevel.critical => criticalPattern,
      IndoorRiskLevel.warning => warningPattern,
      IndoorRiskLevel.notice || IndoorRiskLevel.none => null,
    };
    if (pattern == null) return;
    try {
      await Vibration.vibrate(pattern: pattern, repeat: -1);
    } catch (_) {
      // Perangkat tanpa vibrator/custom pattern tetap mendapat peringatan TTS.
    }
  }

  static Future<void> stop() async {
    try {
      await Vibration.cancel();
    } catch (_) {
      // Abaikan platform yang tidak menyediakan vibrator.
    }
  }
}
