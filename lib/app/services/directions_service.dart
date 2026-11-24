import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/helpers/geo_math.dart';
import '../utils/helpers/navigation_models.dart';
import 'api_keys.dart';

/// Error rute navigasi dengan pesan ramah pengguna.
class DirectionsException implements Exception {
  final String message;
  const DirectionsException(this.message);

  @override
  String toString() => message;
}

/// Klien layanan rute pejalan kaki: Menggunakan Google Routes API (New) resmi,
/// dengan fallback otomatis ke OSRM (Open Source Routing Machine) dan direct-line route.
class DirectionsService {
  static const _routesApiUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _legacyDirectionsUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  static const String _androidPackage = 'com.netravision.apps';
  static const String _androidCert =
      'DA61DA76BAACCAF681925ED57FFCF0CF37FEB553';

  Future<RouteResult> getWalkingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    // 1. Coba Google Routes API (New) jika API key aktif
    if (ApiKeys.isConfigured) {
      try {
        final newRoute = await _getGoogleRoutesApiWalkingRoute(
          origin: origin,
          destination: destination,
        );
        if (newRoute != null) {
          return newRoute;
        }
      } catch (e) {
        debugPrint('[DirectionsService] Google Routes API (New) error: $e');
      }

      // Fallback ke Legacy Directions API jika Routes API gagal
      try {
        final legacyRoute = await _getLegacyGoogleWalkingRoute(
          origin: origin,
          destination: destination,
        );
        if (legacyRoute != null) {
          return legacyRoute;
        }
      } catch (e) {
        debugPrint('[DirectionsService] Google Legacy Directions error: $e');
      }
    }

    // 2. Fallback: OSRM Foot Routing (Open Source Routing Machine, gratis tanpa kunci)
    try {
      return await _getOsrmWalkingRoute(
          origin: origin, destination: destination);
    } catch (e) {
      debugPrint('[DirectionsService] OSRM routing error: $e');
    }

    // 3. Fallback keselamatan terakhir: Garis lurus langsung ke tujuan
    return _getDirectLineRoute(origin: origin, destination: destination);
  }

  /// Google Routes API (New) computeRoutes untuk pejalan kaki.
  Future<RouteResult?> _getGoogleRoutesApiWalkingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    final payload = {
      'origin': {
        'location': {
          'latLng': {'latitude': origin.lat, 'longitude': origin.lng}
        }
      },
      'destination': {
        'location': {
          'latLng': {'latitude': destination.lat, 'longitude': destination.lng}
        }
      },
      'travelMode': 'WALK',
    };

    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': ApiKeys.googleMaps,
      'X-Goog-FieldMask':
          'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps',
      'X-Android-Package': _androidPackage,
      'X-Android-Cert': _androidCert,
    };

    final response = await http
        .post(
          Uri.parse(_routesApiUrl),
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      debugPrint(
          '[DirectionsService] Google Routes API (New) HTTP ${response.statusCode}: ${response.body}');
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final overviewRaw =
        ((route['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
                as String?) ??
            '';
    final totalMeters =
        (route['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final legs = route['legs'] as List<dynamic>? ?? [];
    final steps = <RouteStep>[];

    if (legs.isNotEmpty) {
      final leg = legs.first as Map<String, dynamic>;
      final rawSteps = leg['steps'] as List<dynamic>? ?? [];
      for (final s in rawSteps) {
        final step = s as Map<String, dynamic>;
        final stepDist =
            (step['distanceMeters'] as num?)?.toDouble() ?? 0.0;
        final navInstr =
            step['navigationInstruction'] as Map<String, dynamic>?;
        final rawInstruction =
            (navInstr?['instructions'] as String?) ?? '';
        final rawManeuver = (navInstr?['maneuver'] as String?) ?? '';
        final stepPolyline =
            ((step['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
                    as String?) ??
                '';

        final startLoc = step['startLocation'] as Map<String, dynamic>?;
        final startLatLng = startLoc?['latLng'] as Map<String, dynamic>?;
        final endLoc = step['endLocation'] as Map<String, dynamic>?;
        final endLatLng = endLoc?['latLng'] as Map<String, dynamic>?;

        final startPt = (startLatLng != null)
            ? GeoPoint(
                (startLatLng['latitude'] as num).toDouble(),
                (startLatLng['longitude'] as num).toDouble(),
              )
            : origin;
        final endPt = (endLatLng != null)
            ? GeoPoint(
                (endLatLng['latitude'] as num).toDouble(),
                (endLatLng['longitude'] as num).toDouble(),
              )
            : destination;

        steps.add(RouteStep(
          instruction: NavigationGuider.cleanHtml(rawInstruction),
          maneuver: rawManeuver.toLowerCase(),
          distanceMeters: stepDist,
          start: startPt,
          end: endPt,
          points: stepPolyline.isNotEmpty
              ? decodePolyline(stepPolyline)
              : [startPt, endPt],
        ));
      }
    }

    if (steps.isEmpty) return null;

    return RouteResult(
      steps: steps,
      overviewPoints: overviewRaw.isNotEmpty
          ? decodePolyline(overviewRaw)
          : [origin, destination],
      destination: destination,
      totalMeters: totalMeters,
    );
  }

  /// Legacy Google Directions API.
  Future<RouteResult?> _getLegacyGoogleWalkingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    final uri = Uri.parse(_legacyDirectionsUrl).replace(queryParameters: {
      'origin': '${origin.lat},${origin.lng}',
      'destination': '${destination.lat},${destination.lng}',
      'mode': 'walking',
      'language': 'id',
      'alternatives': 'false',
      'key': ApiKeys.googleMaps,
    });

    final response = await http.get(uri, headers: {
      'X-Android-Package': _androidPackage,
      'X-Android-Cert': _androidCert,
    }).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;

    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? [];
    if (legs.isEmpty) return null;

    final leg = legs.first as Map<String, dynamic>;
    final overviewRaw =
        ((route['overview_polyline'] as Map<String, dynamic>?)?['points']
                as String?) ??
            '';
    final steps = (leg['steps'] as List<dynamic>? ?? []).map((raw) {
      final step = raw as Map<String, dynamic>;
      final start = _point(step['start_location']);
      final end = _point(step['end_location']);
      final pointsRaw =
          ((step['polyline'] as Map<String, dynamic>?)?['points']
                  as String?) ??
              '';
      return RouteStep(
        instruction: NavigationGuider.cleanHtml(
            (step['html_instructions'] as String?) ?? ''),
        maneuver: (step['maneuver'] as String?) ?? '',
        distanceMeters:
            ((step['distance'] as Map<String, dynamic>?)?['value'] as num?)
                    ?.toDouble() ??
                0,
        start: start,
        end: end,
        points: pointsRaw.isEmpty
            ? [start, end]
            : decodePolyline(pointsRaw),
      );
    }).toList();

    if (steps.isEmpty) return null;

    final totalMeters =
        ((leg['distance'] as Map<String, dynamic>?)?['value'] as num?)
                ?.toDouble() ??
            0;

    return RouteResult(
      steps: steps,
      overviewPoints:
          overviewRaw.isEmpty ? const [] : decodePolyline(overviewRaw),
      destination: _point(leg['end_location']),
      totalMeters: totalMeters,
    );
  }

  Future<RouteResult> _getOsrmWalkingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    final url =
        'https://router.project-osrm.org/route/v1/foot/${origin.lng},${origin.lat};${destination.lng},${destination.lat}?overview=full&geometries=polyline&steps=true';
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent': 'NetraVisionApp/1.0 (contact@netravision.app)',
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw DirectionsException(
          'Gagal memuat rute (HTTP ${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['code'] != 'Ok') {
      throw const DirectionsException('Rute pejalan kaki tidak ditemukan.');
    }

    final routes = json['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw const DirectionsException('Rute jalan kaki kosong.');
    }

    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? [];
    final leg = legs.isNotEmpty ? legs.first as Map<String, dynamic> : null;

    final overviewRaw = (route['geometry'] as String?) ?? '';
    final overviewPoints = overviewRaw.isNotEmpty
        ? decodePolyline(overviewRaw)
        : <GeoPoint>[];

    final stepsList = (leg?['steps'] as List<dynamic>? ?? []);
    final routeSteps = <RouteStep>[];

    for (var i = 0; i < stepsList.length; i++) {
      final step = stepsList[i] as Map<String, dynamic>;
      final maneuverObj =
          (step['maneuver'] as Map<String, dynamic>?) ?? {};
      final type = (maneuverObj['type'] as String?) ?? '';
      final modifier = (maneuverObj['modifier'] as String?) ?? '';
      final name = (step['name'] as String?)?.trim() ?? '';
      final distance = ((step['distance'] as num?)?.toDouble() ?? 0)
          .clamp(0.0, double.infinity);
      final stepGeom = (step['geometry'] as String?) ?? '';
      final stepPoints =
          stepGeom.isNotEmpty ? decodePolyline(stepGeom) : <GeoPoint>[];

      final start = stepPoints.isNotEmpty
          ? stepPoints.first
          : (i == 0 ? origin : destination);
      final end = stepPoints.isNotEmpty
          ? stepPoints.last
          : (i == stepsList.length - 1 ? destination : origin);

      final maneuver = _osrmManeuverToGoogle(type, modifier);
      final instruction = _formatOsrmInstruction(type, modifier, name);

      routeSteps.add(RouteStep(
        instruction: instruction,
        maneuver: maneuver,
        distanceMeters: distance,
        start: start,
        end: end,
        points: stepPoints.isEmpty ? [start, end] : stepPoints,
      ));
    }

    if (routeSteps.isEmpty) {
      throw const DirectionsException(
          'Rute tidak memiliki langkah pejalan kaki.');
    }

    final totalMeters = ((leg?['distance'] as num?)?.toDouble() ??
            (route['distance'] as num?)?.toDouble()) ??
        haversineMeters(origin, destination);

    return RouteResult(
      steps: routeSteps,
      overviewPoints: overviewPoints.isNotEmpty
          ? overviewPoints
          : [origin, destination],
      destination: destination,
      totalMeters: totalMeters,
    );
  }

  @visibleForTesting
  static String osrmManeuverToGoogle(String type, String modifier) =>
      _osrmManeuverToGoogle(type, modifier);

  @visibleForTesting
  static String formatOsrmInstruction(
          String type, String modifier, String name) =>
      _formatOsrmInstruction(type, modifier, name);

  @visibleForTesting
  static RouteResult getDirectLineRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) =>
      _getDirectLineRoute(origin: origin, destination: destination);

  static String _osrmManeuverToGoogle(String type, String modifier) {
    if (type == 'depart') return 'depart';
    if (type == 'arrive') return 'arrive';
    if (type.contains('roundabout') || type.contains('rotary')) {
      return 'roundabout';
    }
    if (modifier == 'left') return 'turn-left';
    if (modifier == 'right') return 'turn-right';
    if (modifier == 'slight left') return 'turn-slight-left';
    if (modifier == 'slight right') return 'turn-slight-right';
    if (modifier == 'sharp left') return 'turn-sharp-left';
    if (modifier == 'sharp right') return 'turn-sharp-right';
    if (modifier == 'uturn') return 'u-turn';
    if (modifier == 'straight') return 'straight';
    return 'straight';
  }

  static String _formatOsrmInstruction(
      String type, String modifier, String name) {
    final road = name.isNotEmpty ? ' ke $name' : '';
    if (type == 'depart') {
      return name.isNotEmpty
          ? 'Mulai berjalan di $name'
          : 'Mulai berjalan ke arah tujuan';
    }
    if (type == 'arrive') {
      return 'Anda telah tiba di tujuan';
    }
    if (type.contains('roundabout') || type.contains('rotary')) {
      return 'Ikuti bundaran';
    }
    if (modifier == 'left') return 'Belok kiri$road';
    if (modifier == 'right') return 'Belok kanan$road';
    if (modifier == 'slight left') return 'Belok sedikit ke kiri$road';
    if (modifier == 'slight right') return 'Belok sedikit ke kanan$road';
    if (modifier == 'sharp left') return 'Belok tajam ke kiri$road';
    if (modifier == 'sharp right') return 'Belok tajam ke kanan$road';
    if (modifier == 'uturn') return 'Putar balik';
    if (type == 'fork') {
      return modifier.contains('left')
          ? 'Ambil jalur kiri$road'
          : 'Ambil jalur kanan$road';
    }
    if (name.isNotEmpty) {
      return 'Lurus terus di $name';
    }
    return 'Lurus terus';
  }

  static RouteResult _getDirectLineRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final total = haversineMeters(origin, destination);
    return RouteResult(
      steps: [
        RouteStep(
          instruction: 'Mulai berjalan lurus ke arah tujuan',
          maneuver: 'depart',
          distanceMeters: total,
          start: origin,
          end: destination,
          points: [origin, destination],
        ),
      ],
      overviewPoints: [origin, destination],
      destination: destination,
      totalMeters: total,
    );
  }

  static GeoPoint _point(dynamic raw) {
    final m = raw as Map<String, dynamic>;
    return GeoPoint(
        (m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
  }
}
