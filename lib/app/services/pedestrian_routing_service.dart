import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../data/models/navigation_models.dart';
import 'location_service.dart';

/// Layanan penghitung rute pejalan kaki menggunakan OSRM (Open Source Routing Machine)
class PedestrianRoutingService extends GetxService {
  final LocationService _locationService = Get.find<LocationService>();

  /// Menghitung rute pejalan kaki dari lokasi pengguna ke tujuan
  Future<NavigationRoute?> calculateFootRoute({
    required LatLng destination,
    required String destinationName,
  }) async {
    final pos = _locationService.currentGpsPosition.value;
    if (pos == null) return null;

    final startLat = pos.latitude;
    final startLng = pos.longitude;
    final endLat = destination.latitude;
    final endLng = destination.longitude;

    // Coba endpoint OSRM foot khusus pejalan kaki (OSM Jerman / OSRM Project)
    final urls = [
      'https://routing.openstreetmap.de/routed-foot/route/v1/foot/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&steps=true',
      'https://router.project-osrm.org/route/v1/foot/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&steps=true',
    ];

    for (final urlStr in urls) {
      try {
        final url = Uri.parse(urlStr);
        final response = await http.get(
          url,
          headers: {'User-Agent': 'NetraVision-AssistiveApp/1.0'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final routes = (data['routes'] as List?) ?? [];
          if (routes.isEmpty) continue;

          final routeData = routes.first;
          final double totalDistance = (routeData['distance'] as num?)?.toDouble() ?? 0.0;
          final double totalDuration = (routeData['duration'] as num?)?.toDouble() ?? 0.0;

          // Ekstraksi garis polyline
          final geometry = routeData['geometry'] as Map<String, dynamic>?;
          final coords = (geometry?['coordinates'] as List?) ?? [];
          final List<LatLng> polylinePoints = coords.map((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          // Ekstraksi instruksi belokan demi belokan (steps)
          final legs = (routeData['legs'] as List?) ?? [];
          final List<NavigationStep> steps = [];

          if (legs.isNotEmpty) {
            final rawSteps = (legs.first['steps'] as List?) ?? [];
            for (int i = 0; i < rawSteps.length; i++) {
              final s = rawSteps[i];
              final sDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
              final sDur = (s['duration'] as num?)?.toDouble() ?? 0.0;
              final sName = s['name']?.toString().trim() ?? '';
              final maneuver = s['maneuver'] as Map<String, dynamic>? ?? {};

              final mType = maneuver['type']?.toString() ?? '';
              final mModifier = maneuver['modifier']?.toString() ?? '';
              final mLocation = (maneuver['location'] as List?) ?? [];
              LatLng targetPt = destination;
              if (mLocation.length >= 2) {
                targetPt = LatLng(
                  (mLocation[1] as num).toDouble(),
                  (mLocation[0] as num).toDouble(),
                );
              }

              final turnType = _parseTurnType(mType, mModifier);
              final instruction = _buildIndonesianInstruction(
                turnType: turnType,
                streetName: sName,
                distanceMeters: sDist,
                isFirst: i == 0,
                isLast: i == rawSteps.length - 1,
                destinationName: destinationName,
              );

              final clockFace = _turnTypeToClockFace(turnType);

              steps.add(
                NavigationStep(
                  instruction: instruction,
                  streetName: sName.isNotEmpty ? sName : 'jalan pejalan kaki',
                  distanceMeters: sDist,
                  durationSeconds: sDur,
                  turnType: turnType,
                  targetPoint: targetPt,
                  clockFace: clockFace,
                ),
              );
            }
          }

          if (steps.isEmpty) {
            // Fallback langkah tunggal jika OSRM tidak memberikan rincian
            steps.add(
              NavigationStep(
                instruction: 'Jalan lurus menuju $destinationName.',
                streetName: 'Jalan langsung',
                distanceMeters: totalDistance,
                durationSeconds: totalDuration,
                turnType: TurnType.depart,
                targetPoint: destination,
                clockFace: 'arah jam 12',
              ),
            );
          }

          return NavigationRoute(
            totalDistanceMeters: totalDistance,
            estimatedDurationSeconds: totalDuration,
            polylinePoints: polylinePoints,
            steps: steps,
            destinationName: destinationName,
          );
        }
      } catch (_) {}
    }

    // Jika offline atau OSRM gagal, buat rute lurus aman
    final directDist = _locationService.calculateDistance(startLat, startLng, endLat, endLng);
    final directBearing = _locationService.calculateBearing(startLat, startLng, endLat, endLng);
    final relative = _locationService.calculateRelativeBearing(
      _locationService.currentHeading.value,
      directBearing,
    );
    final clock = _locationService.bearingToClockFace(relative);

    return NavigationRoute(
      totalDistanceMeters: directDist,
      estimatedDurationSeconds: directDist / 1.1, // kecepatan jalan kaki ~1.1 m/s
      polylinePoints: [LatLng(startLat, startLng), destination],
      steps: [
        NavigationStep(
          instruction: 'Jalan lurus di $clock sejauh ${directDist.round()} meter menuju $destinationName.',
          streetName: 'Rute Langsung',
          distanceMeters: directDist,
          durationSeconds: directDist / 1.1,
          turnType: TurnType.depart,
          targetPoint: destination,
          clockFace: clock,
        ),
      ],
      destinationName: destinationName,
    );
  }

  TurnType _parseTurnType(String type, String modifier) {
    if (type == 'depart') return TurnType.depart;
    if (type == 'arrive') return TurnType.arrive;

    switch (modifier) {
      case 'straight':
        return TurnType.continueStraight;
      case 'slight right':
        return TurnType.slightRight;
      case 'right':
        return TurnType.right;
      case 'sharp right':
        return TurnType.sharpRight;
      case 'slight left':
        return TurnType.slightLeft;
      case 'left':
        return TurnType.left;
      case 'sharp left':
        return TurnType.sharpLeft;
      case 'uturn':
        return TurnType.uTurn;
      default:
        return TurnType.continueStraight;
    }
  }

  String _buildIndonesianInstruction({
    required TurnType turnType,
    required String streetName,
    required double distanceMeters,
    required bool isFirst,
    required bool isLast,
    required String destinationName,
  }) {
    final distStr = distanceMeters > 0 ? '${distanceMeters.round()} meter' : '';
    final streetPart = streetName.isNotEmpty ? 'di $streetName' : '';

    if (isLast || turnType == TurnType.arrive) {
      return 'Tiba di tujuan. $destinationName ada di depan Anda.';
    }

    if (isFirst || turnType == TurnType.depart) {
      if (distStr.isNotEmpty) {
        return 'Mulai berjalan $streetPart sejauh $distStr.';
      }
      return 'Mulai berjalan menuju rute.';
    }

    final action = switch (turnType) {
      TurnType.depart => 'Jalan',
      TurnType.continueStraight => 'Terus lurus $streetPart',
      TurnType.slightRight => 'Serong kanan ke arah jam 1',
      TurnType.right => 'Belok kanan arah jam 3 $streetPart',
      TurnType.sharpRight => 'Belok tajam ke kanan arah jam 4',
      TurnType.slightLeft => 'Serong kiri ke arah jam 11',
      TurnType.left => 'Belok kiri arah jam 9 $streetPart',
      TurnType.sharpLeft => 'Belok tajam ke kiri arah jam 8',
      TurnType.uTurn => 'Putar balik ke arah belakang',
      TurnType.arrive => 'Tiba di tujuan',
    };

    if (distStr.isNotEmpty) {
      return '$action, lalu jalan sejauh $distStr.';
    }
    return action;
  }

  String _turnTypeToClockFace(TurnType turnType) {
    switch (turnType) {
      case TurnType.depart:
      case TurnType.continueStraight:
        return 'arah jam 12';
      case TurnType.slightRight:
        return 'arah jam 1';
      case TurnType.right:
        return 'arah jam 3';
      case TurnType.sharpRight:
        return 'arah jam 4';
      case TurnType.slightLeft:
        return 'arah jam 11';
      case TurnType.left:
        return 'arah jam 9';
      case TurnType.sharpLeft:
        return 'arah jam 8';
      case TurnType.uTurn:
        return 'arah jam 6';
      case TurnType.arrive:
        return 'arah jam 12';
    }
  }
}
