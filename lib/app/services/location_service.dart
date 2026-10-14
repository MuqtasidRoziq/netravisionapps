import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../utils/helpers/geo_math.dart';

/// Layanan posisi GPS (stream) untuk navigasi Mode Jalan.
class LocationService extends GetxService {
  /// Meminta izin lokasi + memastikan GPS aktif. True bila posisi bisa didapat.
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Stream posisi (interval ringan, jarak filter 2 m agar tidak boros baterai).
  Stream<GeoPoint> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).map((position) => GeoPoint(position.latitude, position.longitude,
        accuracy: position.accuracy));
  }

  /// Ambil posisi terakhir yang tersimpan di sistem (instan tanpa menunggu sinyal satelit).
  Future<GeoPoint?> lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return GeoPoint(position.latitude, position.longitude,
            accuracy: position.accuracy);
      }
    } catch (_) {}
    return null;
  }

  /// Ambil posisi sekali (mis. saat membuat rute awal).
  Future<GeoPoint?> currentPosition({
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return GeoPoint(position.latitude, position.longitude,
          accuracy: position.accuracy);
    } catch (_) {
      return null;
    }
  }
}