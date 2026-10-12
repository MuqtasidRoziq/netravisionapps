import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/helpers/geo_math.dart';
import '../utils/helpers/navigation_models.dart';
import 'api_keys.dart';

/// Error pencarian tujuan dengan pesan ramah pengguna.
class PlacesException implements Exception {
  final String message;
  const PlacesException(this.message);

  @override
  String toString() => message;
}

/// Mencari tujuan: nama dulu (Text Search), fallback kategori terdekat
/// (Nearby Search) untuk kata kunci umum seperti "warung".
class PlacesService {
  static const _textSearchUrl =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';
  static const _nearbySearchUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Cari satu tujuan terbaik untuk [query] di sekitar [center].
  ///
  /// [radiusMeters] membatasi pencarian (prioritas nama). Mengembalikan tempat
  /// terdekat yang cocok, atau null bila tak ada hasil.
  Future<GeoPlace?> searchBest({
    required String query,
    required GeoPoint center,
    int radiusMeters = 3000,
  }) async {
    if (!ApiKeys.isConfigured) {
      throw const PlacesException(
          'Kunci API Google belum diisi. Isi lewat --dart-define=GOOGLE_MAPS_API_KEY saat build.');
    }

    final candidates = <GeoPlace>[];

    // 1. Pencarian nama.
    final textResults = await _textSearch(query, center, radiusMeters);
    candidates.addAll(textResults);

    // 2. Fallback kategori terdekat.
    if (textResults.isEmpty) {
      for (final type in _typesForQuery(query)) {
        final nearby = await _nearbyByTypes(center, [type], radiusMeters ~/ 2);
        if (nearby.isNotEmpty) {
          candidates.addAll(nearby);
          break;
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Pilih yang terdekat.
    candidates.sort((a, b) =>
        (a.distanceMeters ?? double.infinity)
            .compareTo(b.distanceMeters ?? double.infinity));
    return candidates.first;
  }

  Future<List<GeoPlace>> _textSearch(String query, GeoPoint center, int radius) async {
    final uri = Uri.parse(_textSearchUrl).replace(queryParameters: {
      'query': query,
      'location': '${center.lat},${center.lng}',
      'radius': '$radius',
      'language': 'id',
      'key': ApiKeys.googleMaps,
    });
    return _requestResults(uri);
  }

  Future<List<GeoPlace>> _nearbyByTypes(
      GeoPoint center, List<String> types, int radius) async {
    final uri = Uri.parse(_nearbySearchUrl).replace(queryParameters: {
      'location': '${center.lat},${center.lng}',
      'radius': '$radius',
      'type': types.join('|'),
      'language': 'id',
      'key': ApiKeys.googleMaps,
    });
    return _requestResults(uri);
  }

  Future<List<GeoPlace>> _requestResults(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return const [];

    final results = json['results'] as List<dynamic>? ?? [];
    final places = <GeoPlace>[];
    for (final raw in results) {
      final item = raw as Map<String, dynamic>;
      final geometry = item['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;
      final location = geometry['location'] as Map<String, dynamic>?;
      if (location == null) continue;
      final lat = (location['lat'] as num?)?.toDouble();
      final lng = (location['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      places.add(GeoPlace(
        name: (item['name'] as String?) ?? 'Tempat',
        address: (item['vicinity'] as String?) ??
            (item['formatted_address'] as String?),
        point: GeoPoint(lat, lng),
      ));
    }
    return places;
  }

  /// Petakan kata kunci umum ke kategori Google Places untuk fallback.
  static List<String> _typesForQuery(String query) {
    final q = query.toLowerCase();
    if (q.contains('warung') ||
        q.contains('indomaret') ||
        q.contains('alfamart') ||
        q.contains('minimarket') ||
        q.contains('swalayan')) {
      return const ['convenience_store', 'supermarket'];
    }
    if (q.contains('makan') || q.contains('nasi') || q.contains('resto')) {
      return const ['restaurant', 'cafe', 'fast_food'];
    }
    if (q.contains('pom') ||
        q.contains('bensin') ||
        q.contains('spbu') ||
        q.contains('bbm')) {
      return const ['gas_station'];
    }
    if (q.contains('apotek') || q.contains('apotik')) {
      return const ['pharmacy'];
    }
    if (q.contains('masjid')) {
      return const ['mosque'];
    }
    if (q.contains('bank')) {
      return const ['bank'];
    }
    if (q.contains('pasar') || q.contains('sayur')) {
      return const ['market', 'supermarket'];
    }
    if (q.contains('cafe') || q.contains('kopi')) {
      return const ['cafe'];
    }
    return const ['convenience_store', 'supermarket', 'restaurant'];
  }
}