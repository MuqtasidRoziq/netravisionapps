import 'package:flutter/services.dart';
import '../../data/models/vision_mode.dart';
import 'spatial_estimator.dart';

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

  /// Susun frasa letak ({samping kiri/kanan} + {atas/bawah}) dari [spatial].
  static String _directionPhrase(SpatialInfo spatial) {
    final hor = switch (spatial.horizontal) {
      HorizontalZone.kiri => 'di samping kiri',
      HorizontalZone.depan => 'di depan',
      HorizontalZone.kanan => 'di samping kanan',
    };
    final ver = switch (spatial.vertical) {
      VerticalZone.atas => ', atas',
      VerticalZone.tengah => '',
      VerticalZone.bawah => ', bawah',
    };
    return '$hor$ver';
  }

  /// Susun frasa jarak ("sekitar 1,5 meter" atau band "dekat").
  static String _proximityPhrase(SpatialInfo spatial) {
    final meters = spatial.meters;
    if (meters != null) {
      return 'sekitar ${_formatMeters(meters)} meter';
    }
    return switch (spatial.band) {
      ProximityBand.sangatDekat => 'sangat dekat',
      ProximityBand.dekat => 'dekat',
      ProximityBand.sedang => 'cukup dekat',
      ProximityBand.jauh => 'jauh',
    };
  }

  /// Bulatkan jarak ke kelipatan 0,5 m dan format Indonesia ("1,5").
  static String _formatMeters(double meters) {
    final rounded = (meters * 2).round() / 2;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.round()}';
    }
    return rounded.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// Format teks hasil deteksi menjadi kalimat ramah TTS.
  static String formatForTts(
    String label,
    VisionMode mode, {
    SpatialInfo? spatial,
  }) {
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
      if (spatial != null) {
        return 'Awas, ada $clean ${_directionPhrase(spatial)}, '
            '${_proximityPhrase(spatial)} di depan Anda!';
      }
      return 'Awas, ada $clean di depan!';
    }

    // 3. Objek biasa
    if (spatial != null) {
      return 'Ada $clean ${_directionPhrase(spatial)}, '
          '${_proximityPhrase(spatial)} di depan Anda';
    }
    return 'Ada $clean di depan';
  }

  /// Format teks hasil deteksi agar rapi saat ditampilkan pada layar UI.
  static String formatDisplayName(
    String label,
    VisionMode mode, {
    SpatialInfo? spatial,
  }) {
    final clean = label.trim().toLowerCase();
    if (mode == VisionMode.currency) {
      switch (clean) {
        case '1000':
          return 'Uang Rp 1.000';
        case '2000':
          return 'Uang Rp 2.000';
        case '5000':
          return 'Uang Rp 5.000';
        case '10000':
          return 'Uang Rp 10.000';
        case '20000':
          return 'Uang Rp 20.000';
        case '50000':
          return 'Uang Rp 50.000';
        case '100000':
          return 'Uang Rp 100.000';
        default:
          return 'Uang Rp $label';
      }
    }

    if (spatial == null) return label;

    final direction = switch (spatial.horizontal) {
      HorizontalZone.kiri => 'kiri',
      HorizontalZone.depan => 'depan',
      HorizontalZone.kanan => 'kanan',
    };
    final vertical = switch (spatial.vertical) {
      VerticalZone.atas => ' · atas',
      VerticalZone.tengah => '',
      VerticalZone.bawah => ' · bawah',
    };
    final distance = spatial.meters != null
        ? ' · ${_formatMeters(spatial.meters!)} m'
        : switch (spatial.band) {
            ProximityBand.sangatDekat => ' · sangat dekat',
            ProximityBand.dekat => ' · dekat',
            ProximityBand.sedang => ' · cukup dekat',
            ProximityBand.jauh => ' · jauh',
          };
    return '$label · $direction$vertical$distance';
  }
}