import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service pengelola GPS presisi tinggi dan Kompas digital untuk navigasi tunanetra.
///
/// Dilengkapi peredam lonjakan GPS (anti-jitter) dan konversi sudut arah jarum jam (clock-face).
class LocationService extends GetxService {
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxDouble currentHeading = 0.0.obs;
  final RxString currentAddress = 'Mencari lokasi GPS Anda...'.obs;
  final RxBool hasLocationPermission = false.obs;
  final RxBool isGpsEnabled = false.obs;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // Anti-jitter: posisi terakhir yang valid
  Position? _lastConfirmedPosition;
  DateTime _lastPositionUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Cache reverse geocode agar tidak membanjiri API nominatim
  LatLng? _lastGeocodedPoint;
  DateTime _lastGeocodedTime = DateTime.fromMillisecondsSinceEpoch(0);

  Future<LocationService> init() async {
    await checkAndRequestPermissions();
    return this;
  }

  @override
  void onClose() {
    stopTracking();
    super.onClose();
  }

  /// Memeriksa dan meminta izin lokasi GPS
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    isGpsEnabled.value = serviceEnabled;
    if (!serviceEnabled) {
      currentAddress.value = 'GPS tidak aktif. Mohon aktifkan GPS di pengaturan HP.';
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        hasLocationPermission.value = false;
        currentAddress.value = 'Izin lokasi ditolak.';
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      hasLocationPermission.value = false;
      currentAddress.value = 'Izin lokasi ditolak permanen. Buka pengaturan untuk mengizinkan.';
      return false;
    }

    hasLocationPermission.value = true;
    return true;
  }

  /// Memulai pemantauan lokasi GPS real-time dan kompas
  Future<void> startTracking() async {
    final granted = await checkAndRequestPermissions();
    if (!granted) return;

    // Ambil posisi awal segera
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _handleNewPosition(initial);
      updateCurrentAddress(initial.latitude, initial.longitude);
    } catch (_) {
      // Fallback ke posisi terakhir jika timeout
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _handleNewPosition(lastKnown);
      }
    }

    // Dengarkan perubahan GPS secara kontinu
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2, // Minimal geser 2 meter
    );

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handleNewPosition,
      onError: (err) {
        // GPS error handling
      },
    );

    // Dengarkan sensor kompas digital
    await _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null) {
        // Normalisasi 0..360 derajat
        final normalized = (heading + 360) % 360;
        currentHeading.value = normalized;
      }
    });
  }

  /// Menghentikan pemantauan GPS & kompas untuk menghemat baterai
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _compassSubscription?.cancel();
    _compassSubscription = null;
  }

  /// Filter anti-jitter: meredam lompatan GPS palsu saat pengguna diam
  void _handleNewPosition(Position newPos) {
    final now = DateTime.now();
    if (_lastConfirmedPosition != null) {
      final dist = Geolocator.distanceBetween(
        _lastConfirmedPosition!.latitude,
        _lastConfirmedPosition!.longitude,
        newPos.latitude,
        newPos.longitude,
      );

      // Jika lonjakan > 50 meter dalam tempo < 1 detik (teleport/glitch), abaikan
      final elapsedSec = now.difference(_lastPositionUpdateTime).inMilliseconds / 1000.0;
      if (elapsedSec > 0 && (dist / elapsedSec) > 30.0) {
        return;
      }

      // Jika pengguna sedang diam (kecepatan < 0.3 m/s dan jarak < 2m), pertahankan posisi lama
      if (newPos.speed < 0.3 && dist < 2.0) {
        return;
      }
    }

    _lastConfirmedPosition = newPos;
    _lastPositionUpdateTime = now;
    currentPosition.value = newPos;

    // Perbarui alamat nama jalan jika sudah bergeser > 30 meter
    if (_lastGeocodedPoint == null ||
        Geolocator.distanceBetween(
              _lastGeocodedPoint!.latitude,
              _lastGeocodedPoint!.longitude,
              newPos.latitude,
              newPos.longitude,
            ) >
            30.0) {
      updateCurrentAddress(newPos.latitude, newPos.longitude);
    }
  }

  /// Mendapatkan nama jalan dan area melalui Reverse Geocoding OpenStreetMap
  Future<void> updateCurrentAddress(double lat, double lng) async {
    final now = DateTime.now();
    if (now.difference(_lastGeocodedTime).inSeconds < 5) return;
    _lastGeocodedTime = now;
    _lastGeocodedPoint = LatLng(lat, lng);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'NetraVision-AssistiveApp/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['footway'];
          final suburb = address['suburb'] ?? address['neighbourhood'] ?? address['village'];
          final city = address['city'] ?? address['town'] ?? address['county'];

          if (road != null) {
            currentAddress.value = '$road, ${suburb ?? city ?? ''}'.trim();
          } else {
            currentAddress.value = data['display_name'] ?? 'Di sekitar area jalan';
          }
        }
      }
    } catch (_) {
      // Offline fallback: tetap gunakan status koordinat
      if (currentPosition.value != null) {
        currentAddress.value = 'Area sekitar lokasi Anda';
      }
    }
  }

  /// Jarak lurus fisik antara 2 titik koordinat (dalam satuan meter)
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Menghitung sudut azimuth (bearing) dari titik A ke titik B (0..360°)
  double calculateBearing(double startLat, double startLng, double endLat, double endLng) {
    final lat1 = startLat * (pi / 180);
    final lon1 = startLng * (pi / 180);
    final lat2 = endLat * (pi / 180);
    final lon2 = endLng * (pi / 180);

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final radians = atan2(y, x);
    final degrees = radians * (180 / pi);
    return (degrees + 360) % 360;
  }

  /// Menghitung selisih sudut relatif terhadap hadap ponsel pengguna (-180..+180°)
  double calculateRelativeBearing(double headingDegrees, double targetBearingDegrees) {
    double diff = targetBearingDegrees - headingDegrees;
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }
    return diff;
  }

  /// Konversi sudut relatif ke sistem Arah Jarum Jam (Clock-Face Direction)
  ///
  /// Sangat intuitif bagi tunanetra:
  /// - Arah jam 12: Lurus di depan
  /// - Arah jam 3: Kanan penuh (tegak lurus)
  /// - Arah jam 9: Kiri penuh (tegak lurus)
  /// - Arah jam 6: Di belakang / Putar balik
  String bearingToClockFace(double relativeAngleDegrees) {
    // Normalisasi ke rentang 0..360 (jam 12 = 0/360)
    final positiveAngle = (relativeAngleDegrees + 360) % 360;

    if (positiveAngle >= 345 || positiveAngle < 15) return 'arah jam 12 (lurus depan)';
    if (positiveAngle >= 15 && positiveAngle < 45) return 'arah jam 1';
    if (positiveAngle >= 45 && positiveAngle < 75) return 'arah jam 2';
    if (positiveAngle >= 75 && positiveAngle < 105) return 'arah jam 3 (samping kanan)';
    if (positiveAngle >= 105 && positiveAngle < 135) return 'arah jam 4';
    if (positiveAngle >= 135 && positiveAngle < 165) return 'arah jam 5';
    if (positiveAngle >= 165 && positiveAngle < 195) return 'arah jam 6 (putar balik ke belakang)';
    if (positiveAngle >= 195 && positiveAngle < 225) return 'arah jam 7';
    if (positiveAngle >= 225 && positiveAngle < 255) return 'arah jam 8';
    if (positiveAngle >= 255 && positiveAngle < 285) return 'arah jam 9 (samping kiri)';
    if (positiveAngle >= 285 && positiveAngle < 315) return 'arah jam 10';
    if (positiveAngle >= 315 && positiveAngle < 345) return 'arah jam 11';

    return 'arah jam 12';
  }

  /// Konversi hadap mata angin (Utara, Timur, Selatan, Barat)
  String headingToCardinal(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'Utara';
    if (heading >= 22.5 && heading < 67.5) return 'Timur Laut';
    if (heading >= 67.5 && heading < 112.5) return 'Timur';
    if (heading >= 112.5 && heading < 157.5) return 'Tenggara';
    if (heading >= 157.5 && heading < 202.5) return 'Selatan';
    if (heading >= 202.5 && heading < 247.5) return 'Barat Daya';
    if (heading >= 247.5 && heading < 292.5) return 'Barat';
    if (heading >= 292.5 && heading < 337.5) return 'Barat Laut';
    return 'Utara';
  }
}
