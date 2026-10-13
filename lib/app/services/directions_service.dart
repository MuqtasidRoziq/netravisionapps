import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/helpers/geo_math.dart';
import '../utils/helpers/navigation_models.dart';
import 'api_keys.dart';

/// Error rute dari Google Directions API dengan pesan ramah pengguna.
class DirectionsException implements Exception {
  final String message;
  const DirectionsException(this.message);

  @override
  String toString() => message;
}

/// Klien Google Directions API (mode=walking, bahasa Indonesia).
class DirectionsService {
  static const _base = 'https://maps.googleapis.com/maps/api/directions/json';

  Future<RouteResult> getWalkingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    if (!ApiKeys.isConfigured) {
      throw const DirectionsException(
          'Kunci API Google belum diisi. Isi lewat --dart-define=GOOGLE_MAPS_API_KEY saat build.');
    }

    final uri = Uri.parse(_base).replace(queryParameters: {
      'origin': '${origin.lat},${origin.lng}',
      'destination': '${destination.lat},${destination.lng}',
      'mode': 'walking',
      'language': 'id',
      'alternatives': 'false',
      'key': ApiKeys.googleMaps,
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw DirectionsException('Gagal memuat rute (HTTP ${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String? ?? '';
    if (status != 'OK') {
      throw DirectionsException(_messageForStatus(status));
    }

    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw const DirectionsException('Rute tidak ditemukan.');
    }
    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? [];
    if (legs.isEmpty) {
      throw const DirectionsException('Rute yang ditemukan tidak memiliki detail.');
    }
    final leg = legs.first as Map<String, dynamic>;

    final overviewRaw = ((route['overview_polyline'] as Map<String, dynamic>?)?['points'] as String?) ?? '';
    final steps = (leg['steps'] as List<dynamic>? ?? []).map((raw) {
      final step = raw as Map<String, dynamic>;
      final start = _point(step['start_location']);
      final end = _point(step['end_location']);
      final pointsRaw =
          ((step['polyline'] as Map<String, dynamic>?)?['points'] as String?) ?? '';
      return RouteStep(
        instruction: NavigationGuider.cleanHtml(
            (step['html_instructions'] as String?) ?? ''),
        maneuver: (step['maneuver'] as String?) ?? '',
        distanceMeters:
            ((step['distance'] as Map<String, dynamic>?)?['value'] as num?)?.toDouble() ?? 0,
        start: start,
        end: end,
        points: pointsRaw.isEmpty ? [start, end] : decodePolyline(pointsRaw),
      );
    }).toList();

    if (steps.isEmpty) {
      throw const DirectionsException('Rute tidak memiliki langkah pejalan kaki.');
    }

    final totalMeters =
        ((leg['distance'] as Map<String, dynamic>?)?['value'] as num?)?.toDouble() ?? 0;

    return RouteResult(
      steps: steps,
      overviewPoints: overviewRaw.isEmpty ? const [] : decodePolyline(overviewRaw),
      destination: _point(leg['end_location']),
      totalMeters: totalMeters,
    );
  }

  static GeoPoint _point(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return GeoPoint((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }

  static String _messageForStatus(String status) {
    switch (status) {
      case 'ZERO_RESULTS':
        return 'Tidak ada rute jalan kaki ke tujuan tersebut.';
      case 'OVER_QUERY_LIMIT':
        return 'Kuota permintaan rute berlebih. Coba beberapa saat lagi.';
      case 'REQUEST_DENIED':
        return 'Akses Directions ditolak. Periksa API key dan API Directions.';
      case 'INVALID_REQUEST':
        return 'Permintaan rute tidak valid.';
      case 'MAX_ROUTE_LENGTH_EXCEEDED':
        return 'Rute terlalu jauh untuk berjalan kaki.';
      default:
        return 'Gagal membuat rute (status $status).';
    }
  }
}