import 'dart:convert';
import 'package:flutter/services.dart';

/// Pengelolaan Kunci Google Maps API.
/// Mendukung pembacaan dari:
/// 1. File `.env` (via asset bundling di runtime)
/// 2. `--dart-define=MAPS_API_KEY=...` atau `--dart-define=GOOGLE_MAPS_API_KEY=...` saat build
/// 3. Fallback dev key
class ApiKeys {
  ApiKeys._();

  static String _envFileKey = '';

  /// Fallback key default (kosong agar tidak ada key yang ter-publish ke Git)
  static const String _defaultDevKey = '';

  static const String _rawKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: _defaultDevKey,
    ),
  );

  /// Inisialisasi: baca file .env jika ada di assets
  static Future<void> init() async {
    try {
      final envString = await rootBundle.loadString('.env');
      final lines = const LineSplitter().convert(envString);
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx != -1) {
          final key = trimmed.substring(0, eqIdx).trim();
          final val = trimmed.substring(eqIdx + 1).trim();
          if ((key == 'MAPS_API_KEY' || key == 'GOOGLE_MAPS_API_KEY') && val.isNotEmpty) {
            _envFileKey = _clean(val);
            break;
          }
        }
      }
    } catch (_) {
      // Jika asset .env belum dimuat, fallback ke _rawKey / _defaultDevKey
    }
  }

  /// Mengambil kunci Google Maps yang sudah dibersihkan dari spasi atau tanda petik.
  static String get googleMaps {
    if (_envFileKey.isNotEmpty) {
      return _clean(_envFileKey);
    }
    return _clean(_rawKey);
  }

  static String _clean(String key) {
    var k = key.trim();
    if ((k.startsWith('"') && k.endsWith('"')) ||
        (k.startsWith("'") && k.endsWith("'"))) {
      k = k.substring(1, k.length - 1).trim();
    }
    return k;
  }

  static bool get isConfigured => googleMaps.isNotEmpty;
}