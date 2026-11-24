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

/// Mencari tujuan: Menggunakan Google Places API (New) resmi dengan pengurutan
/// jarak (DISTANCE) layaknya Google Maps asli, dengan fallback otomatis ke
/// OpenStreetMap (Nominatim & Photon) bila offline atau tanpa kuota.
class PlacesService {
  // --- Google Places API (New) Endpoints ---
  static const _newPlacesSearchTextUrl =
      'https://places.googleapis.com/v1/places:searchText';
  static const _newPlacesSearchNearbyUrl =
      'https://places.googleapis.com/v1/places:searchNearby';

  // --- Identitas Keamanan Android untuk Kunci API Google Cloud ---
  static const String _androidPackage = 'com.netravision.apps';
  static const String _androidCert =
      'DA61DA76BAACCAF681925ED57FFCF0CF37FEB553';

  static Map<String, String> get _googleNewHeaders => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiKeys.googleMaps,
        'X-Goog-FieldMask':
            'places.displayName,places.formattedAddress,places.location,places.types',
        'X-Android-Package': _androidPackage,
        'X-Android-Cert': _androidCert,
      };

  /// Radius lokal yang nyaman ditempuh kaki; di atas ini dianggap jauh.
  static const int localRadiusMeters = 1500;

  /// Batas keras: kandidat di luar radius ini tidak akan dipilih diam-diam.
  static const int maxRadiusMeters = 15000;

  /// Tahapan radius fallback: cari dari yang terdekat dulu (100m sebelah rumah, 300m gang/RT, 800m RW)
  /// baru melebar bertahap ke 2km, 5km, dan 15km jika di sekitar tidak ada.
  static const List<int> radiusTiers = [100, 300, 800, 2000, 5000, 15000];

  /// Cari satu tujuan terbaik untuk [query] di sekitar [center].
  ///
  /// Memprioritaskan Google Places API (New) dengan `rankPreference: "DISTANCE"`
  /// sehingga hasil yang dikembalikan dijamin tempat terdekat dari koordinat pengguna,
  /// persis seperti aplikasi Google Maps asli.
  Future<PlaceSearchResult> searchBest({
    required String query,
    required GeoPoint center,
    int radiusMeters = localRadiusMeters,
  }) async {
    // 1. Prioritas Utama: Google Places API (New) resmi dengan bias lokasi & urutan jarak
    if (ApiKeys.isConfigured) {
      try {
        final googlePlaces =
            await _searchGoogleNew(query, center, radiusMeters);
        if (googlePlaces.isNotEmpty) {
          final nearest = selectNearest(googlePlaces);
          if (nearest != null) {
            final dist = nearest.distanceMeters ??
                haversineMeters(center, nearest.point);
            debugPrint(
                '[PlacesService] Google Places (New) matched: "${nearest.name}" (${dist.toStringAsFixed(1)}m away)');
            return PlaceSearchResult(
              place: nearest,
              beyondLocal: dist > localRadiusMeters,
            );
          }
        }
      } catch (e) {
        debugPrint('[PlacesService] Google Places (New) exception: $e');
      }
    }

    // 2. Fallback: OpenStreetMap (Nominatim + Photon) bertahap dari jarak paling dekat
    final tiers = <int>{...radiusTiers, radiusMeters}.toList()..sort();
    GeoPlace? best;
    double? bestDist;
    for (final radius in tiers) {
      final candidates = await _gather(query, center, radius);
      if (candidates.isEmpty) continue;

      final nearest = selectNearest(candidates);
      if (nearest == null) continue;
      final dist =
          nearest.distanceMeters ?? haversineMeters(center, nearest.point);
      if (best == null || dist < (bestDist ?? double.infinity)) {
        best = nearest;
        bestDist = dist;
      }

      // Jika tempat terdekat berada di dalam radius tier ini, langsung berhenti!
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

  /// Pencarian resmi Google Places API (New) dengan urutan jarak (DISTANCE).
  Future<List<GeoPlace>> _searchGoogleNew(
    String query,
    GeoPoint center,
    int radiusMeters,
  ) async {
    final places = <GeoPlace>[];

    // 1. Text Search (New) dengan rankPreference: DISTANCE
    try {
      final effectiveRadius = math.max(radiusMeters.toDouble(), 2500.0);
      final bodyText = jsonEncode({
        'textQuery': query,
        'locationBias': {
          'circle': {
            'center': {'latitude': center.lat, 'longitude': center.lng},
            'radius': effectiveRadius,
          }
        },
        'rankPreference': 'DISTANCE',
        'maxResultCount': 15,
      });

      final response = await http
          .post(
            Uri.parse(_newPlacesSearchTextUrl),
            headers: _googleNewHeaders,
            body: bodyText,
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = json['places'] as List<dynamic>? ?? [];
        for (final item in rawList) {
          final p = item as Map<String, dynamic>;
          final loc = p['location'] as Map<String, dynamic>?;
          if (loc == null) continue;
          final lat = (loc['latitude'] as num?)?.toDouble();
          final lng = (loc['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          final disp = p['displayName'] as Map<String, dynamic>?;
          final name = (disp?['text'] as String?)?.trim() ?? 'Tempat';
          final addr = (p['formattedAddress'] as String?)?.trim();
          final pt = GeoPoint(lat, lng);
          places.add(GeoPlace(
            name: name,
            address: addr,
            point: pt,
            distanceMeters: haversineMeters(center, pt),
          ));
        }
      } else {
        debugPrint(
            '[PlacesService] Google Places (New) searchText HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[PlacesService] Google Places (New) searchText error: $e');
    }

    // 2. Jika text search kosong dan query memiliki kategori Google (misal: mosque, school),
    // coba searchNearby (New) dengan rankPreference DISTANCE
    if (places.isEmpty) {
      final types = _newTypesForQuery(query);
      if (types.isNotEmpty) {
        try {
          final bodyNearby = jsonEncode({
            'includedTypes': types,
            'locationRestriction': {
              'circle': {
                'center': {'latitude': center.lat, 'longitude': center.lng},
                'radius': math.max(radiusMeters.toDouble(), 2500.0),
              }
            },
            'rankPreference': 'DISTANCE',
            'maxResultCount': 15,
          });

          final response = await http
              .post(
                Uri.parse(_newPlacesSearchNearbyUrl),
                headers: _googleNewHeaders,
                body: bodyNearby,
              )
              .timeout(const Duration(seconds: 6));

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final rawList = json['places'] as List<dynamic>? ?? [];
            for (final item in rawList) {
              final p = item as Map<String, dynamic>;
              final loc = p['location'] as Map<String, dynamic>?;
              if (loc == null) continue;
              final lat = (loc['latitude'] as num?)?.toDouble();
              final lng = (loc['longitude'] as num?)?.toDouble();
              if (lat == null || lng == null) continue;

              final disp = p['displayName'] as Map<String, dynamic>?;
              final name = (disp?['text'] as String?)?.trim() ?? 'Tempat';
              final addr = (p['formattedAddress'] as String?)?.trim();
              final pt = GeoPoint(lat, lng);
              places.add(GeoPlace(
                name: name,
                address: addr,
                point: pt,
                distanceMeters: haversineMeters(center, pt),
              ));
            }
          }
        } catch (e) {
          debugPrint('[PlacesService] Google Places (New) searchNearby error: $e');
        }
      }
    }

    // Urutkan selalu dari jarak paling dekat
    places.sort((a, b) => (a.distanceMeters ?? double.infinity)
        .compareTo(b.distanceMeters ?? double.infinity));
    return places;
  }

  /// Gabungkan kandidat dari Nominatim + Photon (Komoot OSM) pada radius tertentu.
  Future<List<GeoPlace>> _gather(
    String query,
    GeoPoint center,
    int radius,
  ) async {
    final candidates = <GeoPlace>[];

    // 1. Kategori resmi OSM di Nominatim (dengan viewbox bounded=1 lokal)
    final categoryPhrase = _osmCategoryPhraseForQuery(query);
    if (categoryPhrase != null) {
      final catResults = await _searchNominatim(categoryPhrase, center, radius);
      candidates.addAll(_filterCategoryRelevance(catResults, query));
    }

    // 2. Cari via Nominatim dengan query teks langsung
    if (candidates.isEmpty || radius <= 800) {
      final nomDirect = await _searchNominatim(query, center, radius);
      candidates.addAll(_filterCategoryRelevance(nomDirect, query));
    }

    // 3. Cari via Photon dengan proximity bias (hanya menerima tempat <= radius * 1.45)
    final photonResults = await _searchPhoton(query, center, radius);
    candidates.addAll(_filterCategoryRelevance(photonResults, query));

    // 4. Jika kandidat masih kosong, coba sinonim lokal (misal: "sd" -> "sekolah dasar", "masjid" -> "mushola")
    if (candidates.isEmpty) {
      final synonyms = _synonymsForQuery(query);
      for (final alt in synonyms.take(3)) {
        if (alt.toLowerCase() != query.toLowerCase()) {
          final altNom = await _searchNominatim(alt, center, radius);
          candidates.addAll(_filterCategoryRelevance(altNom, query));
          if (candidates.isNotEmpty) break;

          final altPhoton = await _searchPhoton(alt, center, radius);
          candidates.addAll(_filterCategoryRelevance(altPhoton, query));
          if (candidates.isNotEmpty) break;
        }
      }
    }

    // 5. Hapus duplikasi berdasarkan koordinat berdekatan (< 30 meter)
    final unique = <GeoPlace>[];
    for (final c in candidates) {
      final exists = unique.any((u) =>
          haversineMeters(u.point, c.point) < 30.0 ||
          (u.name.toLowerCase() == c.name.toLowerCase() &&
              haversineMeters(u.point, c.point) < 80.0));
      if (!exists) {
        unique.add(c);
      }
    }

    // Urutkan selalu dari jarak terdekat ke terjauh
    unique.sort((a, b) => (a.distanceMeters ?? double.infinity)
        .compareTo(b.distanceMeters ?? double.infinity));

    debugPrint(
        '[PlacesService] OSM Gather for "$query" (radius ${radius}m) found ${unique.length} candidates.');
    return unique;
  }

  /// Pilih kandidat tempat dengan jarak terdekat dari posisi pengguna.
  @visibleForTesting
  static GeoPlace? selectNearest(List<GeoPlace> candidates) {
    if (candidates.isEmpty) return null;
    final sorted = List<GeoPlace>.of(candidates)
      ..sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));
    return sorted.first;
  }

  /// Mengambil nama jalan / lokasi terkini dari koordinat GPS (Reverse Geocoding).
  Future<String?> reverseGeocode(GeoPoint point) async {
    // 1. Coba Google Maps Geocoding API jika API key tersedia
    if (ApiKeys.isConfigured) {
      try {
        final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json')
            .replace(
          queryParameters: {
            'latlng': '${point.lat},${point.lng}',
            'language': 'id',
            'key': ApiKeys.googleMaps,
          },
        );
        final response =
            await http.get(uri, headers: {
          'X-Android-Package': _androidPackage,
          'X-Android-Cert': _androidCert,
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          if (json['status'] == 'OK') {
            final results = json['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              final first = results.first as Map<String, dynamic>;
              final components =
                  first['address_components'] as List<dynamic>? ?? [];
              String? routeName;
              String? sublocality;
              for (final c in components) {
                final types =
                    (c['types'] as List<dynamic>?)?.cast<String>() ?? [];
                if (types.contains('route')) {
                  routeName = c['long_name'] as String?;
                } else if (types.contains('sublocality') ||
                    types.contains('sublocality_level_1')) {
                  sublocality = c['long_name'] as String?;
                }
              }
              if (routeName != null && routeName.isNotEmpty) {
                return sublocality != null
                    ? '$routeName, $sublocality'
                    : routeName;
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
          final road = (address['road'] ??
              address['pedestrian'] ??
              address['suburb']) as String?;
          final neighbourhood = (address['neighbourhood'] ??
              address['suburb'] ??
              address['city']) as String?;
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

  /// Pencarian tempat via Photon (Komoot OSM) dengan bias kedekatan koordinat [center].
  Future<List<GeoPlace>> _searchPhoton(
    String query,
    GeoPoint center,
    int radiusMeters,
  ) async {
    final uri = Uri.parse('https://photon.komoot.io/api/').replace(
      queryParameters: {
        'q': query,
        'lat': '${center.lat}',
        'lon': '${center.lng}',
        'limit': '15',
      },
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'NetraVisionApp/1.0 (contact@netravision.app)',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return const [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>? ?? [];
      final places = <GeoPlace>[];

      for (final raw in features) {
        final f = raw as Map<String, dynamic>;
        final geom = f['geometry'] as Map<String, dynamic>?;
        if (geom == null) continue;
        final coords = geom['coordinates'] as List<dynamic>?;
        if (coords == null || coords.length < 2) continue;
        final lng = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final point = GeoPoint(lat, lng);
        final dist = haversineMeters(center, point);
        if (dist > radiusMeters * 1.45) continue;

        final props = f['properties'] as Map<String, dynamic>? ?? {};
        final rawName = (props['name'] as String?)?.trim() ?? '';
        final district = (props['district'] as String?)?.trim();
        final city = (props['city'] as String?)?.trim();
        final street = (props['street'] as String?)?.trim();
        final state = (props['state'] as String?)?.trim();

        String name;
        if (rawName.isNotEmpty) {
          final lower = rawName.toLowerCase();
          final isGeneric = lower == 'lapangan' ||
              lower == 'masjid' ||
              lower == 'mushola' ||
              lower == 'musholla' ||
              lower == 'mesjid' ||
              lower == 'toko' ||
              lower == 'warung' ||
              lower == 'taman';
          if (isGeneric &&
              (district != null || city != null || street != null)) {
            final loc = street ?? district ?? city;
            name = '$rawName $loc';
          } else {
            name = rawName;
          }
        } else {
          name = 'Tempat';
        }

        final addrParts = [
          if (street != null && street.isNotEmpty) street,
          if (district != null && district.isNotEmpty) district,
          if (city != null && city.isNotEmpty) city,
          if (state != null && state.isNotEmpty) state,
        ];

        places.add(GeoPlace(
          name: name,
          address: addrParts.isNotEmpty ? addrParts.join(', ') : null,
          point: point,
          distanceMeters: dist,
        ));
      }

      places.sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));
      return places;
    } catch (e) {
      debugPrint('[PlacesService] Photon search error: $e');
      return const [];
    }
  }

  /// Pencarian tempat di OpenStreetMap Nominatim di sekitar [center].
  Future<List<GeoPlace>> _searchNominatim(
    String query,
    GeoPoint center,
    int radiusMeters,
  ) async {
    final radius = radiusMeters < 80 ? 80 : radiusMeters;
    final latDelta = (radius * 1.15) / 111000.0;
    final cosLat =
        math.cos(center.lat * math.pi / 180.0).abs().clamp(0.1, 1.0);
    final lngDelta = (radius * 1.15) / (111000.0 * cosLat);

    final minLon = (center.lng - lngDelta).toStringAsFixed(6);
    final maxLon = (center.lng + lngDelta).toStringAsFixed(6);
    final minLat = (center.lat - latDelta).toStringAsFixed(6);
    final maxLat = (center.lat + latDelta).toStringAsFixed(6);
    final viewbox = '$minLon,$maxLat,$maxLon,$minLat';

    // 1. Coba pencarian dengan bounded=1 terlebih dahulu untuk area lokal
    var places = await _fetchNominatim(
      query: query,
      center: center,
      viewbox: viewbox,
      bounded: true,
      maxDistance: radius * 1.35,
    );

    // 2. Jika bounded=1 kosong dan radius sudah cukup lebar (> 800m), coba bounded=0
    if (places.isEmpty && radius > 800) {
      places = await _fetchNominatim(
        query: query,
        center: center,
        viewbox: viewbox,
        bounded: false,
        maxDistance: radius * 1.5,
      );
    }

    return places;
  }

  Future<List<GeoPlace>> _fetchNominatim({
    required String query,
    required GeoPoint center,
    required String viewbox,
    required bool bounded,
    required double maxDistance,
  }) async {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'countrycodes': 'id',
        'limit': '15',
        'viewbox': viewbox,
        if (bounded) 'bounded': '1',
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

        final point = GeoPoint(lat, lon);
        final dist = haversineMeters(center, point);
        if (dist > maxDistance) continue;

        final rawName = (item['name'] as String?)?.trim() ?? '';
        final displayName = (item['display_name'] as String?)?.trim() ?? '';
        String name;
        if (rawName.isNotEmpty) {
          final lower = rawName.toLowerCase();
          final isGeneric = lower == 'lapangan' ||
              lower == 'masjid' ||
              lower == 'mushola' ||
              lower == 'musholla' ||
              lower == 'toko' ||
              lower == 'warung' ||
              lower == 'taman';
          if (isGeneric && displayName.isNotEmpty) {
            final parts = displayName.split(',').map((p) => p.trim()).toList();
            if (parts.length > 1 && parts[1].isNotEmpty) {
              name = '$rawName ${parts[1]}';
            } else {
              name = rawName;
            }
          } else {
            name = rawName;
          }
        } else if (displayName.isNotEmpty) {
          final parts = displayName.split(',').map((p) => p.trim()).toList();
          if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
            name = '${parts[0]} (${parts[1]})';
          } else {
            name = parts.first;
          }
        } else {
          name = 'Tempat';
        }

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
  static List<String> synonymsForQuery(String query) =>
      _synonymsForQuery(query);

  static List<String> _synonymsForQuery(String query) {
    final q = query.toLowerCase();
    final syn = <String>[];
    if (q.contains('lapangan') ||
        q.contains('stadion') ||
        q.contains('futsal') ||
        q.contains('bola')) {
      syn.addAll([
        'lapangan',
        'lapangan bola',
        'lapangan sepak bola',
        'lapangan futsal',
        'stadion',
        'alun-alun'
      ]);
    }
    if (q.contains('taman') || q.contains('alun')) {
      syn.addAll(['taman', 'alun-alun', 'taman kota', 'ruang terbuka']);
    }
    if (q.contains('makan') ||
        q.contains('nasi') ||
        q.contains('resto') ||
        q.contains('lapar') ||
        q.contains('warteg')) {
      syn.addAll(['warung makan', 'warung', 'rumah makan', 'restoran']);
    }
    if (q.contains('warung') ||
        q.contains('kelontong') ||
        q.contains('toko')) {
      syn.addAll(['warung', 'toko', 'indomaret', 'alfamart']);
    }
    if (q.contains('minimarket') ||
        q.contains('supermarket') ||
        q.contains('swalayan')) {
      syn.addAll(['minimarket', 'indomaret', 'alfamart', 'supermarket']);
    }
    if (q.contains('masjid') ||
        q.contains('mushola') ||
        q.contains('musholla') ||
        q.contains('mesjid') ||
        q.contains('sholat') ||
        q.contains('solat') ||
        q.contains('ibadah')) {
      syn.addAll(['mushola', 'masjid', 'musholla', 'mesjid', 'surau']);
    }
    if (q.contains('sekolah dasar') || q == 'sd' || q.contains('sd ')) {
      syn.addAll(['sekolah dasar', 'sd', 'sd negeri', 'sekolah']);
    }
    if (q.contains('madrasah') || q == 'mi' || q.contains('mi ')) {
      syn.addAll(
          ['madrasah ibtidaiyah', 'mi', 'madrasah', 'sekolah dasar']);
    }
    if (q.contains('gereja')) {
      syn.addAll(['gereja', 'katedral']);
    }
    if (q.contains('pom') ||
        q.contains('bensin') ||
        q.contains('spbu') ||
        q.contains('bbm')) {
      syn.addAll(['spbu', 'pertamina']);
    }
    if (q.contains('apotek') || q.contains('apotik') || q.contains('obat')) {
      syn.addAll(['apotek', 'farmasi', 'toko obat']);
    }
    if (q.contains('sakit') ||
        q.contains('dokter') ||
        q.contains('klinik') ||
        q.contains('puskesmas')) {
      syn.addAll(['puskesmas', 'rumah sakit', 'klinik']);
    }
    if (q.contains('kopi') ||
        q.contains('cafe') ||
        q.contains('kafe') ||
        q.contains('warkop')) {
      syn.addAll(['warkop', 'cafe', 'kopi']);
    }
    if (q.contains('sekolah') ||
        q.contains('kampus') ||
        q.contains('kuliah')) {
      syn.addAll(['sekolah', 'universitas', 'kampus']);
    }
    return syn;
  }

  /// Pemetaan tipe kategori resmi Google Places API (New).
  static List<String> _newTypesForQuery(String query) {
    final q = query.toLowerCase();
    if (q.contains('masjid') ||
        q.contains('mushola') ||
        q.contains('musholla') ||
        q.contains('sholat')) {
      return const ['mosque', 'place_of_worship'];
    }
    if (q.contains('sekolah dasar') || q == 'sd' || q.contains('sd ')) {
      return const ['primary_school', 'school'];
    }
    if (q.contains('madrasah') || q == 'mi' || q.contains('mi ')) {
      return const ['primary_school', 'school'];
    }
    if (q.contains('smp') || q.contains('sma') || q.contains('smk')) {
      return const ['secondary_school', 'school'];
    }
    if (q.contains('sekolah') || q.contains('kampus')) {
      return const ['school', 'university'];
    }
    if (q.contains('makan') || q.contains('warung') || q.contains('resto')) {
      return const ['restaurant', 'cafe', 'fast_food_restaurant'];
    }
    if (q.contains('apotek') || q.contains('apotik') || q.contains('obat')) {
      return const ['pharmacy'];
    }
    if (q.contains('minimarket') ||
        q.contains('supermarket') ||
        q.contains('toko')) {
      return const ['convenience_store', 'supermarket', 'grocery_store'];
    }
    if (q.contains('spbu') || q.contains('bensin') || q.contains('pom')) {
      return const ['gas_station'];
    }
    if (q.contains('lapangan') ||
        q.contains('stadion') ||
        q.contains('futsal')) {
      return const ['stadium', 'athletic_field'];
    }
    if (q.contains('taman') || q.contains('alun')) {
      return const ['park'];
    }
    if (q.contains('bank') || q.contains('atm')) {
      return const ['bank', 'atm'];
    }
    if (q.contains('sakit') || q.contains('klinik') || q.contains('puskesmas')) {
      return const ['hospital', 'medical_clinic'];
    }
    return const [];
  }

  /// Petakan kata kunci generik ke frasa kategori khusus OpenStreetMap Nominatim.
  static String? _osmCategoryPhraseForQuery(String query) {
    final q = query.toLowerCase().trim();
    if (q.contains('masjid') ||
        q.contains('mushola') ||
        q.contains('musholla') ||
        q.contains('mesjid') ||
        q.contains('surau') ||
        q.contains('langgar') ||
        q.contains('sholat') ||
        q.contains('solat') ||
        q.contains('ibadah')) {
      return 'place of worship';
    }
    if (q == 'gereja' || q == 'katedral') {
      return 'church';
    }
    if (q.contains('sekolah dasar') || q == 'sd') {
      return 'sekolah dasar';
    }
    if (q.contains('madrasah') || q == 'mi') {
      return 'madrasah ibtidaiyah';
    }
    if (q.contains('lapangan') ||
        q.contains('stadion') ||
        q.contains('futsal') ||
        q.contains('bola')) {
      return 'pitch';
    }
    if (q == 'taman' || q == 'alun-alun' || q == 'alun alun') {
      return 'park';
    }
    if (q.contains('makan') ||
        q.contains('warung') ||
        q.contains('resto') ||
        q.contains('kuliner') ||
        q.contains('lapar')) {
      return 'restaurant';
    }
    if (q.contains('minimarket') ||
        q.contains('supermarket') ||
        q.contains('swalayan') ||
        q.contains('toko')) {
      return 'convenience';
    }
    if (q.contains('apotek') || q.contains('apotik') || q.contains('obat')) {
      return 'pharmacy';
    }
    if (q.contains('sakit') ||
        q.contains('puskesmas') ||
        q.contains('klinik') ||
        q.contains('dokter')) {
      return 'hospital';
    }
    if (q.contains('spbu') || q.contains('bensin') || q.contains('pom')) {
      return 'fuel';
    }
    if (q.contains('bank') || q.contains('atm')) {
      return 'bank';
    }
    if (q.contains('sekolah')) {
      return 'school';
    }
    if (q.contains('kampus') ||
        q.contains('kuliah') ||
        q.contains('universitas')) {
      return 'university';
    }
    return null;
  }

  /// Filter relevansi nama agar pencarian spesifik (misal: masjid) tidak mengambil gereja/pura.
  static List<GeoPlace> _filterCategoryRelevance(
      List<GeoPlace> places, String query) {
    final q = query.toLowerCase();
    final isMosque = q.contains('masjid') ||
        q.contains('mushola') ||
        q.contains('musholla') ||
        q.contains('mesjid') ||
        q.contains('sholat') ||
        q.contains('solat');
    final isChurch = q.contains('gereja') || q.contains('katedral');

    if (!isMosque && !isChurch) return places;

    return places.where((p) {
      final name = p.name.toLowerCase();
      final addr = (p.address ?? '').toLowerCase();
      final combined = '$name $addr';

      if (isMosque) {
        if (combined.contains('gereja') ||
            combined.contains('church') ||
            combined.contains('katedral') ||
            combined.contains('vihara') ||
            combined.contains('pura') ||
            combined.contains('klenteng')) {
          return false;
        }
      } else if (isChurch) {
        if (combined.contains('masjid') ||
            combined.contains('mushola') ||
            combined.contains('musholla') ||
            combined.contains('mesjid') ||
            combined.contains('vihara') ||
            combined.contains('pura')) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}
