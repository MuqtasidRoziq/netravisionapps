import 'package:flutter/services.dart';
import '../../data/models/vision_mode.dart';
import 'spatial_estimator.dart';

/// Helper untuk menerjemahkan label deteksi AI menjadi kalimat
/// yang alami, informatif, dan mengutamakan keselamatan tunanetra.
class ObjectSpeechHelper {
  ObjectSpeechHelper._();

  /// 24 kelas standar model outdoor (sesuai urutan output model TFLite outdoor)
  static const List<String> outdoorClassLabels = [
    'micromobility', // 0
    'bus', // 1
    'car', // 2
    'push_cart', // 3
    'pet', // 4
    'motorcycle', // 5
    'movable_signage', // 6
    'person', // 7
    'truck', // 8
    'wheelchair', // 9
    'barricade', // 10
    'bench', // 11
    'bollard', // 12
    'chair', // 13
    'fire hydrant', // 14
    'service_terminal', // 15
    'pole', // 16
    'potted plant', // 17
    'control_cabinet', // 18
    'transit_stop', // 19
    'table', // 20
    'traffic light', // 21
    'traffic_sign', // 22
    'tree_trunk', // 23
  ];

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
    'skuter atau sepeda',
    'gerobak',
    'barikade jalan',
    'tiang pembatas trotoar',
    'batang pohon',
    'rambu jalan',
    'hidran air',
    'gardu listrik',
    // Label dari model outdoor (Inggris)
    'car',
    'motorcycle',
    'truck',
    'barricade',
    'bollard',
    'pole',
    'micromobility',
    'push_cart',
    'push cart',
    'tree_trunk',
    'tree trunk',
    'movable_signage',
    'movable signage',
    'fire hydrant',
    'fire_hydrant',
    'control_cabinet',
    'control cabinet',
  };

  // Kamus terjemahan label outdoor/indoor ke Bahasa Indonesia ramah tunanetra
  static const Map<String, String> _labelTranslations = {
    'micromobility': 'skuter atau sepeda',
    'bus': 'bus',
    'car': 'mobil',
    'push_cart': 'gerobak',
    'push cart': 'gerobak',
    'pet': 'hewan peliharaan',
    'motorcycle': 'sepeda motor',
    'movable_signage': 'rambu jalan',
    'movable signage': 'rambu jalan',
    'person': 'orang',
    'truck': 'truk',
    'wheelchair': 'kursi roda',
    'barricade': 'barikade jalan',
    'bench': 'kursi taman',
    'bollard': 'tiang pembatas trotoar',
    'chair': 'kursi',
    'fire hydrant': 'hidran air',
    'fire_hydrant': 'hidran air',
    'service_terminal': 'terminal layanan',
    'service terminal': 'terminal layanan',
    'pole': 'tiang',
    'potted plant': 'pot tanaman',
    'potted_plant': 'pot tanaman',
    'control_cabinet': 'gardu listrik',
    'control cabinet': 'gardu listrik',
    'transit_stop': 'halte',
    'transit stop': 'halte',
    'table': 'meja',
    'traffic light': 'lampu lalu lintas',
    'traffic_light': 'lampu lalu lintas',
    'traffic_sign': 'rambu lalu lintas',
    'traffic sign': 'rambu lalu lintas',
    'tree_trunk': 'batang pohon',
    'tree trunk': 'batang pohon',
    // Pemetaan langsung bila sudah Bahasa Indonesia
    'mobil': 'mobil',
    'sepeda motor': 'sepeda motor',
    'truk': 'truk',
    'orang': 'orang',
    'tiang': 'tiang',
    'tangga': 'tangga',
    'kursi': 'kursi',
    'meja': 'meja',
    'pintu': 'pintu',
    'jendela': 'jendela',
    'lampu lalu lintas': 'lampu lalu lintas',
    'rambu lalu lintas': 'rambu lalu lintas',
    'batang pohon': 'batang pohon',
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
    '75000': 'Uang tujuh puluh lima ribu rupiah',
    '100000': 'Uang seratus ribu rupiah',
    'coin_1000': 'Koin seribu rupiah',
    'coin_500': 'Koin lima ratus rupiah',
    'coin_200': 'Koin dua ratus rupiah',
    'coin_100': 'Koin seratus rupiah',
    'coin_50': 'Koin lima puluh rupiah',
  };

  /// Menguraikan label ke nama Bahasa Indonesia yang natural.
  /// Menangani nama Inggris, nama Indonesia, indeks kelas, atau format fallback "class X".
  static String resolveLabel(String rawLabel, {int? classIndex}) {
    final clean = rawLabel.trim().toLowerCase();
    if (clean.isEmpty && classIndex == null) return '';

    // 1. Cek langsung di kamus terjemahan
    if (_labelTranslations.containsKey(clean)) {
      return _labelTranslations[clean]!;
    }

    // 2. Jika formatnya "class 0", "class 2", "class_2", "class: 2"
    final classMatch = RegExp(r'^class[_\s:]*(\d+)$').firstMatch(clean);
    if (classMatch != null) {
      final idx = int.tryParse(classMatch.group(1)!);
      if (idx != null && idx >= 0 && idx < outdoorClassLabels.length) {
        final english = outdoorClassLabels[idx];
        return _labelTranslations[english] ?? english;
      }
    }

    // 3. Fallback bila diberikan classIndex numerik
    if (classIndex != null &&
        classIndex >= 0 &&
        classIndex < outdoorClassLabels.length) {
      final english = outdoorClassLabels[classIndex];
      return _labelTranslations[english] ?? english;
    }

    // 4. Penggantian garis bawah ke spasi jika ada
    final unspaced = clean.replaceAll('_', ' ');
    if (_labelTranslations.containsKey(unspaced)) {
      return _labelTranslations[unspaced]!;
    }

    return clean.isNotEmpty ? clean : 'objek';
  }

  /// Memeriksa apakah objek layak diumumkan ke tunanetra
  static bool shouldAnnounce(String label, VisionMode mode, {int? classIndex}) {
    final clean = label.trim().toLowerCase();
    if (_ignoredLabels.contains(clean)) return false;
    if (mode == VisionMode.currency) {
      return _currencyNames.containsKey(clean);
    }
    final resolved = resolveLabel(label, classIndex: classIndex);
    if (_ignoredLabels.contains(resolved.toLowerCase())) return false;
    return resolved.isNotEmpty;
  }

  /// Memeriksa apakah ini rintangan bahaya (butuh getaran taktil)
  static bool isDangerousObstacle(String label, {int? classIndex}) {
    final clean = label.trim().toLowerCase();
    if (_dangerousObstacles.contains(clean)) return true;
    final resolved = resolveLabel(label, classIndex: classIndex).toLowerCase();
    return _dangerousObstacles.contains(resolved);
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
    int? classIndex,
    SpatialInfo? spatial,
  }) {
    final clean = label.trim().toLowerCase();

    // 1. Jika mode baca uang
    if (mode == VisionMode.currency) {
      if (_currencyNames.containsKey(clean)) {
        return _currencyNames[clean]!;
      }
      return '';
    }

    final translated = resolveLabel(label, classIndex: classIndex);
    final isDanger = isDangerousObstacle(label, classIndex: classIndex);

    // 2. Jika rintangan berbahaya (Indoor / Outdoor)
    if (isDanger) {
      // Picu getaran getar bahaya di HP
      HapticFeedback.heavyImpact();
      if (spatial != null) {
        return 'Awas, ada $translated ${_directionPhrase(spatial)}, '
            '${_proximityPhrase(spatial)} di depan Anda!';
      }
      return 'Awas, ada $translated di depan!';
    }

    // 3. Objek biasa
    if (spatial != null) {
      return 'Ada $translated ${_directionPhrase(spatial)}, '
          '${_proximityPhrase(spatial)} di depan Anda';
    }
    return 'Ada $translated di depan';
  }

  /// Format teks hasil deteksi agar rapi saat ditampilkan pada layar UI.
  static String formatDisplayName(
    String label,
    VisionMode mode, {
    int? classIndex,
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
        case '75000':
          return 'Uang Rp 75.000';
        case '100000':
          return 'Uang Rp 100.000';
        case 'coin_1000':
          return 'Koin Rp 1.000';
        case 'coin_500':
          return 'Koin Rp 500';
        case 'coin_200':
          return 'Koin Rp 200';
        case 'coin_100':
          return 'Koin Rp 100';
        case 'coin_50':
          return 'Koin Rp 50';
        default:
          return 'Bukan uang';
      }
    }

    final resolved = resolveLabel(label, classIndex: classIndex);
    final displayName = resolved.isNotEmpty ? resolved : label;
    if (spatial == null) return displayName;

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
    return '$displayName · $direction$vertical$distance';
  }
}