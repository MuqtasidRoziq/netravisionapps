import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../data/models/navigation_models.dart';
import 'location_service.dart';

/// Layanan pencarian tempat terdekat (Point of Interest) berbasis OpenStreetMap Overpass & Nominatim
class NearbyPlacesService extends GetxService {
  final LocationService _locationService = Get.find<LocationService>();

  /// Mencari tempat terdekat berdasarkan kategori
  Future<List<NearbyPlaceModel>> findNearbyByCategory(
    PlaceCategory category, {
    double radiusMeters = 1000.0,
  }) async {
    final pos = _locationService.currentGpsPosition.value;
    if (pos == null) return [];

    final lat = pos.latitude;
    final lng = pos.longitude;
    final heading = _locationService.currentHeading.value;

    final overpassQuery = _buildOverpassQuery(category, lat, lng, radiusMeters);

    try {
      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http
          .post(
            url,
            body: {'data': overpassQuery},
            headers: {'User-Agent': 'NetraVision-AssistiveApp/1.0'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = (data['elements'] as List?) ?? [];

        final List<NearbyPlaceModel> places = [];

        for (final el in elements) {
          final elLat = (el['lat'] ?? el['center']?['lat']) as num?;
          final elLng = (el['lon'] ?? el['center']?['lon']) as num?;
          if (elLat == null || elLng == null) continue;

          final tags = el['tags'] as Map<String, dynamic>? ?? {};
          String name = tags['name'] ?? tags['brand'] ?? tags['operator'] ?? '';

          if (name.isEmpty) {
            name = _defaultNameForCategory(category, tags);
          }

          final point = LatLng(elLat.toDouble(), elLng.toDouble());
          final dist = _locationService.calculateDistance(lat, lng, point.latitude, point.longitude);
          final bearing = _locationService.calculateBearing(lat, lng, point.latitude, point.longitude);
          final relative = _locationService.calculateRelativeBearing(heading, bearing);
          final clock = _locationService.bearingToClockFace(relative);

          final address = tags['addr:street'] != null
              ? '${tags['addr:street']} ${tags['addr:housenumber'] ?? ''}'.trim()
              : '';

          places.add(
            NearbyPlaceModel(
              id: '${el['type']}_${el['id']}',
              name: name,
              category: category,
              point: point,
              distanceMeters: dist,
              relativeBearing: relative,
              clockDirection: clock,
              address: address,
            ),
          );
        }

        // Urutkan dari yang terdekat ke terjauh
        places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return places;
      }
    } catch (_) {
      // Fallback ke pencarian alternatif jika server Overpass sibuk
    }

    // Fallback: Nominatim query
    return _searchNominatimByCategory(category, lat, lng, heading);
  }

  /// Pencarian kustom berdasarkan nama tempat (mis. "Indomaret", "Stasiun Gambir")
  Future<List<NearbyPlaceModel>> searchByText(String query) async {
    final pos = _locationService.currentGpsPosition.value;
    if (pos == null) return [];

    final lat = pos.latitude;
    final lng = pos.longitude;
    final heading = _locationService.currentHeading.value;

    try {
      // Prioritaskan hasil di sekitar lokasi pengguna (viewbox ±0.15 derajat ~ 15km)
      final left = lng - 0.15;
      final top = lat + 0.15;
      final right = lng + 0.15;
      final bottom = lat - 0.15;

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=15&viewbox=$left,$top,$right,$bottom&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'NetraVision-AssistiveApp/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        final List<NearbyPlaceModel> places = [];

        for (final item in list) {
          final elLat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final elLng = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          if (elLat == 0.0 || elLng == 0.0) continue;

          final name = item['name'] ?? item['display_name']?.split(',').first ?? query;
          final point = LatLng(elLat, elLng);
          final dist = _locationService.calculateDistance(lat, lng, elLat, elLng);
          final bearing = _locationService.calculateBearing(lat, lng, elLat, elLng);
          final relative = _locationService.calculateRelativeBearing(heading, bearing);
          final clock = _locationService.bearingToClockFace(relative);

          places.add(
            NearbyPlaceModel(
              id: 'nominatim_${item['osm_id'] ?? places.length}',
              name: name,
              category: PlaceCategory.custom,
              point: point,
              distanceMeters: dist,
              relativeBearing: relative,
              clockDirection: clock,
              address: item['display_name'] ?? '',
            ),
          );
        }

        places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return places;
      }
    } catch (_) {}

    return [];
  }

  /// Membangun query Overpass QL berdasarkan kategori
  String _buildOverpassQuery(PlaceCategory category, double lat, double lng, double radius) {
    final r = radius.toInt();
    String nodeFilters = '';

    switch (category) {
      case PlaceCategory.transport:
        nodeFilters = '''
          node["highway"="bus_stop"](around:$r, $lat, $lng);
          node["public_transport"="platform"](around:$r, $lat, $lng);
          node["railway"="station"](around:$r, $lat, $lng);
          node["amenity"="bus_station"](around:$r, $lat, $lng);
        ''';
        break;
      case PlaceCategory.convenience:
        nodeFilters = '''
          node["shop"="convenience"](around:$r, $lat, $lng);
          node["shop"="supermarket"](around:$r, $lat, $lng);
          node["shop"="grocery"](around:$r, $lat, $lng);
        ''';
        break;
      case PlaceCategory.health:
        nodeFilters = '''
          node["amenity"="pharmacy"](around:$r, $lat, $lng);
          node["amenity"="clinic"](around:$r, $lat, $lng);
          node["amenity"="hospital"](around:$r, $lat, $lng);
        ''';
        break;
      case PlaceCategory.worship:
        nodeFilters = '''
          node["amenity"="place_of_worship"](around:$r, $lat, $lng);
        ''';
        break;
      case PlaceCategory.food:
        nodeFilters = '''
          node["amenity"="restaurant"](around:$r, $lat, $lng);
          node["amenity"="fast_food"](around:$r, $lat, $lng);
          node["amenity"="cafe"](around:$r, $lat, $lng);
        ''';
        break;
      case PlaceCategory.custom:
        nodeFilters = '''
          node["amenity"](around:$r, $lat, $lng);
        ''';
        break;
    }

    return '[out:json][timeout:8];($nodeFilters);out body center 15;';
  }

  /// Fallback pencarian ke Nominatim saat Overpass sibuk
  Future<List<NearbyPlaceModel>> _searchNominatimByCategory(
    PlaceCategory category,
    double lat,
    double lng,
    double heading,
  ) async {
    final keyword = switch (category) {
      PlaceCategory.transport => 'halte bus',
      PlaceCategory.convenience => 'minimarket',
      PlaceCategory.health => 'apotek',
      PlaceCategory.worship => 'masjid',
      PlaceCategory.food => 'warung makan',
      PlaceCategory.custom => 'toko',
    };
    return searchByText(keyword);
  }

  String _defaultNameForCategory(PlaceCategory category, Map<String, dynamic> tags) {
    switch (category) {
      case PlaceCategory.transport:
        return 'Halte Bus / Angkutan';
      case PlaceCategory.convenience:
        return tags['shop'] == 'supermarket' ? 'Supermarket' : 'Minimarket';
      case PlaceCategory.health:
        return tags['amenity'] == 'hospital' ? 'Rumah Sakit' : 'Apotek';
      case PlaceCategory.worship:
        final religion = tags['religion'];
        if (religion == 'muslim') return 'Masjid';
        if (religion == 'christian') return 'Gereja';
        return 'Tempat Ibadah';
      case PlaceCategory.food:
        return 'Warung Makan';
      case PlaceCategory.custom:
        return 'Tempat Tujuan';
    }
  }
}
