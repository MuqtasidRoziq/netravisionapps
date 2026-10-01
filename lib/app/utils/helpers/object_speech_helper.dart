import 'package:flutter/services.dart';
import '../../data/models/vision_mode.dart';

/// Helper untuk menerjemahkan label deteksi AI menjadi kalimat
/// yang alami, informatif, dan mengutamakan keselamatan tunanetra.
class ObjectSpeechHelper {
  ObjectSpeechHelper._();

  // Daftar rintangan berbahaya yang butuh peringatan cepat & getaran
  static const Set<String> _dangerousObstacles = {
    'jalan berlubang',
    'tangga',
    'tiang',
    'kumpulan tiang',
    'tepi trotoar',
    'rintangan jalan',
    'rel kereta api',
    'mobil',
    'sepeda motor',
    'bus',
    'truk',
  };

  // Objek yang tidak perlu dibacakan agar tidak membisingkan pengguna
  static const Set<String> _ignoredLabels = {
    'langit',
    'tanah',
    'latar belakang',
    'luar area',
    'plat nomor',
    'batas visual',
    'objek tidak dikenal',
    'area terbuka',
    'bukan jalan',
  };

  // Kamus konversi nominal uang rupiah ke ucapan yang fasih
  static const Map<String, String> _currencyNames = {
    '1000': 'Uang seribu rupiah',
    '2000': 'Uang dua ribu rupiah',
    '5000': 'Uang lima ribu rupiah',
    '10000': 'Uang sepuluh ribu rupiah',
    '20000': 'Uang dua puluh ribu rupiah',
    '50000': 'Uang lima puluh ribu rupiah',
    '100000': 'Uang seratus ribu rupiah',
  };

  /// Memeriksa apakah objek layak diumumkan ke tunanetra
  static bool shouldAnnounce(String label, VisionMode mode) {
    final clean = label.trim().toLowerCase();
    if (_ignoredLabels.contains(clean)) return false;
    return clean.isNotEmpty;
  }

  /// Memeriksa apakah ini rintangan bahaya (butuh getaran taktil)
  static bool isDangerousObstacle(String label) {
    final clean = label.trim().toLowerCase();
    return _dangerousObstacles.contains(clean);
  }

  /// Format teks hasil deteksi menjadi kalimat ramah TTS
  static String formatForTts(String label, VisionMode mode) {
    final clean = label.trim().toLowerCase();

    // 1. Jika mode baca uang
    if (mode == VisionMode.currency) {
      if (_currencyNames.containsKey(clean)) {
        return _currencyNames[clean]!;
      }
      return 'Terdeteksi uang $label rupiah';
    }

    // 2. Jika rintangan berbahaya (Indoor / Outdoor)
    if (_dangerousObstacles.contains(clean)) {
      // Picu getaran getar bahaya di HP
      HapticFeedback.heavyImpact();
      return 'Awas, ada $clean di depan!';
    }

    // 3. Objek biasa
    return 'Ada $clean di depan';
  }
}