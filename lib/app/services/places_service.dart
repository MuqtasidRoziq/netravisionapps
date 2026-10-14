import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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

/// Hasil pencarian tujuan.
class PlaceSearchResult {
  const PlaceSearchResult({required this.place, required this.beyondLocal});

  /// Tempat terdekat yang cocok, atau null bila tak ada hasil.
  final GeoPlace? place;

  /// True bila tempat terdekat masih di luar radius lokal yang nyaman ditempuh
  /// kaki ([PlacesService.localRadiusMeters]).
  final bool beyondLocal;

  bool get found => place != null;
}

/// Mencari tujuan: Google Places bila tersedia, fallback otomatis ke
/// OpenStreetMap Nominatim bila Google API tidak aktif / request denied.
class PlacesService {
  static const _textSearchUrl =
      'https://maps.googleapis.com/maps/api/place/textsearch/json';
  static const _nearbySearchUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Radius lokal yang nyaman ditempuh kaki; di atas ini dianggap jauh.
  static const int localRadiusMeters = 5000;

  /// Batas keras: kandidat di luar radius ini tidak akan dipilih diam-diam.
  static const int maxRadiusMeters = 15000;

  /// Tahapan radius: cari sempit dulu, melebar bertahap agar tetap lokal.
  static const List<int> radiusTiers = [5000, 10000, 15000];

  /// Cari satu tujuan terbaik untuk [query] di sekitar [center].
  ///
  /// Pencarian dilakukan bertahap dari radius sempit ke lebar ([radiusTiers])
  /// dan berhenti pada tahap pertama yang menemukan tempat di dalam radiusnya,
  /// sehingga hasil tetap lokal (tidak meloncat ke kota lain). Bila tempat
  /// terdekat masih di luar [localRadiusMeters], [PlaceSearchResult.beyondLocal]
  /// bernilai true agar UI dapat memperingatkan pengguna.
  Future<PlaceSearchResult> searchBest({
    required String query,
    required GeoPoint center,
    int radiusMeters = localRadiusMeters,
  }) async {
    final tiers = <int>{radiusMeters, ...radiusTiers}.toList()..sort();

    // Simpan kandidat TERDEKAT lintas tahap (bukan hanya tahap terakhir), agar
    // hasil yang dipilih selalu yang paling dekat dari posisi pengguna.
    GeoPlace? best;
    double? bestDist;
    for (final radius in tiers) {
      final candidates = await _gather(query, center, radius);
      if (candidates.isEmpty) continue;

      // WAJIB: pilih yang benar-benar TERDEKAT dari posisi pengguna.
      // (Google Places mengembalikan hasil paling populer, bukan terdekat,
      // jadi kita hitung jarak tiap kandidat lalu urutkan sendiri.)
      final nearest = selectNearest(candidates);
      if (nearest == null) continue;
      final dist =
          nearest.distanceMeters ?? haversineMeters(center, nearest.point);
      if (best == null || dist < (bestDist ?? double.infinity)) {
        best = nearest;
        bestDist = dist;
      }
      if (dist <= radius) break;
    }

    if (best == null) {
      return const PlaceSearchResult(place: null, beyondLocal: false);
    }
    final dist = bestDist ?? haversineMeters(center, best.point);
    return PlaceSearchResult(
      place: best,
      beyondLocal: dist > localRadiusMeters,
    );
  }

  /// Gabungkan kandidat dari Google + Nominatim pada radius tertentu.
  Future<List<GeoPlace>> _gather(
    String query,
    GeoPoint center,
    int radius,
  ) async {
    final candidates = <GeoPlace>[];

    // Cari paralel: OpenStreetMap Nominatim (akurat lokal di Indonesia) dan
    // Google Places (bila kunci API terkonfigurasi). Menggabungkan keduanya
    // memperbesar peluang menemukan cabang tempat TERDEKAT dari posisi user,
    // bukan hanya kantor pusat yang paling populer.
    final searches = <Future<List<GeoPlace>>>[
      _searchNominatim(query, center, radius),
    ];
    if (ApiKeys.isConfigured) {
      searches.add(_searchGoogle(query, center, radius));
    }

    final results = await Future.wait(searches);
    for (final list in results) {
      candidates.addAll(list);
    }

    // Jika query belum ada hasil langsung, coba alternatif sinonim
    // (misal: "makan" -> "rumah makan" / "warung").
    if (candidates.isEmpty) {
      for (final alt in _synonymsForQuery(query)) {
        final altResults = await _searchNominatim(alt, center, radius);
        if (altResults.isNotEmpty) {
          candidates.addAll(altResults);
          break;
        }
      }
    }

    return candidates;
  }

  /// Pilih kandidat tempat dengan jarak terdekat dari posisi pengguna.
  /// Dipisah murni agar mudah diuji tanpa jaringan.
  @visibleForTesting
  static GeoPlace? selectNearest(List<GeoPlace> candidates) {
    if (candidates.isEmpty) return null;
    final sorted = List<GeoPlace>.of(candidates)
      ..sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));
    return sorted.first;
  }

  /// Pencarian Google Places: Nearby terdekat (`rankby=distance`) + Text
  /// Search, lalu fallback kategori bila keduanya kosong.
  Future<List<GeoPlace>> _searchGoogle(
    String query,
    GeoPoint center,
    int radiusMeters,
  ) async {
    final results = <GeoPlace>[];

    // 1. Nearby Search diurut jarak → tempat TERDEKAT yang nyata (bukan populer).
    try {
      results.addAll(await _nearbyByKeyword(query, center));
    } catch (e) {
      debugPrint('[PlacesService] Google Nearby error: $e');
    }

    // 2. Text Search sebagai pelengkap (bias lokasi, menemukan nama unik).
    try {
      results.addAll(await _textSearch(query, center, radiusMeters));
    } catch (e) {
      debugPrint('[PlacesService] Google TextSearch error: $e');
    }

    // 3. Fallback kategori bila belum ada hasil.
    if (results.isEmpty) {
      for (final type in _typesForQuery(query)) {
        try {
          final nearby = await _nearbyByTypes(center, [type], radiusMeters);
          if (nearby.isNotEmpty) {
            results.addAll(nearby);
            break;
          }
        } catch (e) {
          debugPrint('[PlacesService] Google Nearby(type) error: $e');
        }
      }
    }
    return results;
  }

  /// Nearby Search Google yang DIURUT BERDASARKAN JARAK dari [center].
  ///
  /// `rankby=distance` mewajibkan `keyword` (atau nama/tipe) dan melarang
  /// `radius`, sehingga hasil yang dikembalikan adalah yang benar-benar
  /// terdekat, bukan yang paling populer.
  Future<List<GeoPlace>> _nearbyByKeyword(String query, GeoPoint center) async {
    final uri = Uri.parse(_nearbySearchUrl).replace(queryParameters: {
      'location': '${center.lat},${center.lng}',
      'rankby': 'distance',
      'keyword': query,
      'language': 'id',
      'key': ApiKeys.googleMaps,
    });
    return _requestResults(uri, center);
  }

  /// Mengambil nama jalan / lokasi terkini dari koordinat GPS (Reverse Geocoding).
  Future<String?> reverseGeocode(GeoPoint point) async {
    // 1. Coba Google Maps Geocoding API jika API key tersedia
    if (ApiKeys.isConfigured) {
      try {
        final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json').replace(
          queryParameters: {
            'latlng': '${point.lat},${point.lng}',
            'language': 'id',
            'key': ApiKeys.googleMaps,
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          if (json['status'] == 'OK') {
            final results = json['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              final first = results.first as Map<String, dynamic>;
              final components = first['address_components'] as List<dynamic>? ?? [];
              String? routeName;
              String? sublocality;
              for (final c in components) {
                final types = (c['types'] as List<dynamic>?)?.cast<String>() ?? [];
                if (types.contains('route')) {
                  routeName = c['long_name'] as String?;
                } else if (types.contains('sublocality') || types.contains('sublocality_level_1')) {
                  sublocality = c['long_name'] as String?;
                }
              }
              if (routeName != null && routeName.isNotEmpty) {
                return sublocality != null ? '$routeName, $sublocality' : routeName;
              }
              final formatted = first['formatted_address'] as String?;
              if (formatted != null && formatted.isNotEmpty) {
                final parts = formatted.split(',');
                if (parts.length >= 2) {
                  return '${parts[0].trim()}, ${parts[1].trim()}';
                }
                return parts.first.trim();
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: OpenStreetMap Nominatim (Gratis & akurat untuk jalan di Indonesia)
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.lat}&lon=${point.lng}&zoom=18&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'NetraVisionApp/1.0 (contact@netravision.app)',
      }).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final address = json['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = (address['road'] ?? address['pedestrian'] ?? address['suburb']) as String?;
          final neighbourhood = (address['neighbourhood'] ?? address['suburb'] ?? address['city']) as String?;
          if (road != null && road.isNotEmpty) {
            return neighbourhood != null ? '$road, $neighbourhood' : road;
          }
        }
        final displayName = json['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName.split(',').take(2).join(',').trim();
        }
      }
    } catch (_) {}

    return null;
  }

  Future<List<GeoPlace>> _textSearch(String query, GeoPoint center, int radius) async {
    final uri = Uri.parse(_textSearchUrl).replace(queryParameters: {
      'query': query,
      'location': '${center.lat},${center.lng}',
      'radius': '$radius',
      'language': 'id',
      'key': ApiKeys.googleMaps,
    });
    return _requestResults(uri, center);
  }

  Future<List<GeoPlace>> _nearbyByTypes(
      GeoPoint center, List<String> types, int radius) async {
    if (types.isEmpty) return const [];
    final uri = Uri.parse(_nearbySearchUrl).replace(queryParameters: {
      'location': '${center.lat},${center.lng}',
      'radius': '$radius',
      // Google hanya menerima SATU type per request.
      'type': types.first,
      'language': 'id',
      'key': ApiKeys.googleMaps,
    });
    return _requestResults(uri, center);
  }

  Future<List<GeoPlace>> _requestResults(Uri uri, GeoPoint center) async {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String? ?? '';
      if (status != 'OK') {
        final detail = json['error_message'] ?? 'tanpa detail';
        if (status == 'REQUEST_DENIED') {
          debugPrint('[PlacesService] Google Places DITOLAK ($status): $detail. '
              'Pastikan kunci API mengizinkan Places API (web service), bukan '
              'hanya Maps SDK Android. Sementara memakai fallback Nominatim.');
        } else {
          debugPrint('[PlacesService] Google Places status: $status ($detail)');
        }
        return const [];
      }

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
        final point = GeoPoint(lat, lng);
        places.add(GeoPlace(
          name: (item['name'] as String?) ?? 'Tempat',
          address: (item['vicinity'] as String?) ??
              (item['formatted_address'] as String?),
          point: point,
          // Hitung jarak nyata dari user agar pemilihan tempat terdekat akurat.
          distanceMeters: haversineMeters(center, point),
        ));
      }
      return places;
    } catch (e) {
      debugPrint('[PlacesService] _requestResults error: $e');
      return const [];
    }
  }

  /// Pencarian tempat di OpenStreetMap Nominatim di sekitar [center].
  Future<List<GeoPlace>> _searchNominatim(
    String query,
    GeoPoint center,
    int radiusMeters,
  ) async {
    final radius = radiusMeters < 500 ? 500 : radiusMeters;
    // Viewbox sedikit lebih longgar dari radius (margin 10%) agar titik di tepi
    // tetap terjangkau, tetapi tetap KETAT (bounded) supaya hasil tidak
    // meloncat ke kota lain.
    final latDelta = (radius * 1.1) / 111000.0;
    final cosLat = math.cos(center.lat * math.pi / 180.0).abs().clamp(0.1, 1.0);
    final lngDelta = (radius * 1.1) / (111000.0 * cosLat);

    final minLon = (center.lng - lngDelta).toStringAsFixed(6);
    final maxLon = (center.lng + lngDelta).toStringAsFixed(6);
    final minLat = (center.lat - latDelta).toStringAsFixed(6);
    final maxLat = (center.lat + latDelta).toStringAsFixed(6);

    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'countrycodes': 'id',
        'limit': '15',
        'viewbox': '$minLon,$maxLat,$maxLon,$minLat',
        // bounded=1 → benar-benar membatasi hasil ke dalam viewbox (bukan
        // sekadar bias seperti bounded=0), sehingga tidak ada hasil lintas kota.
        'bounded': '1',
      },
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'NetraVisionApp/1.0 (contact@netravision.app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return const [];
      final list = jsonDecode(response.body) as List<dynamic>? ?? [];
      final places = <GeoPlace>[];

      for (final raw in list) {
        final item = raw as Map<String, dynamic>;
        final latStr = item['lat'] as String?;
        final lonStr = item['lon'] as String?;
        if (latStr == null || lonStr == null) continue;
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;

        final rawName = (item['name'] as String?)?.trim() ?? '';
        final displayName = (item['display_name'] as String?)?.trim() ?? '';
        final name = rawName.isNotEmpty
            ? rawName
            : (displayName.isNotEmpty ? displayName.split(',').first.trim() : 'Tempat');

        final point = GeoPoint(lat, lon);
        final dist = haversineMeters(center, point);

        places.add(GeoPlace(
          name: name,
          address: displayName.isNotEmpty ? displayName : null,
          point: point,
          distanceMeters: dist,
        ));
      }

      places.sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));
      return places;
    } catch (e) {
      debugPrint('[PlacesService] OSM Nominatim error: $e');
      return const [];
    }
  }

  /// Sinonim umum untuk memperkaya pencarian bila query awal tidak ada hasil langsung.
  @visibleForTesting
  static List<String> synonymsForQuery(String query) => _synonymsForQuery(query);

  static List<String> _synonymsForQuery(String query) {
    final q = query.toLowerCase();
    final syn = <String>[];
    if (q.contains('makan') || q.contains('nasi') || q.contains('resto') || q.contains('lapar')) {
      syn.addAll(['warung', 'rumah makan', 'restoran']);
    }
    if (q.contains('warung') || q.contains('kelontong') || q.contains('toko')) {
      syn.addAll(['toko', 'indomaret', 'alfamart']);
    }
    if (q.contains('minimarket') || q.contains('supermarket') || q.contains('swalayan')) {
      syn.addAll(['indomaret', 'alfamart', 'supermarket']);
    }
    if (q.contains('masjid') || q.contains('mushola') || q.contains('sholat') || q.contains('ibadah')) {
      syn.addAll(['masjid', 'musholla']);
    }
    if (q.contains('pom') || q.contains('bensin') || q.contains('spbu') || q.contains('bbm')) {
      syn.addAll(['spbu', 'pertamina']);
    }
    if (q.contains('apotek') || q.contains('apotik') || q.contains('obat')) {
      syn.addAll(['apotek', 'farmasi']);
    }
    if (q.contains('sakit') || q.contains('dokter') || q.contains('klinik') || q.contains('puskesmas')) {
      syn.addAll(['puskesmas', 'rumah sakit', 'klinik']);
    }
    if (q.contains('kopi') || q.contains('cafe')) {
      syn.addAll(['cafe', 'warkop']);
    }
    return syn;
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