// Kunci API dibaca dari `--dart-define` saat build, tidak pernah di-commit.
///
/// Build:
///   flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=xxx
class ApiKeys {
  ApiKeys._();

  /// Dipakai untuk Maps SDK Android (manifest, via env) DAN untuk panggilan
  /// Directions/Places dari sisi Dart. Bisa satu kunci dengan semua API
  /// diaktifkan, atau dipisah dengan dua var sendiri.
  static const String _defaultDevKey = '';

  static const String _rawKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: _defaultDevKey,
    ),
  );

  /// Mengambil kunci Google Maps yang sudah dibersihkan dari spasi atau tanda petik.
  static String get googleMaps {
    final key = _rawKey.trim();
    if ((key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))) {
 
      return key.substring(1, key.length - 1).trim();
    }
    return key;
  }

  static bool get isConfigured => googleMaps.isNotEmpty;
}