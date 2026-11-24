import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../utils/helpers/geo_math.dart';

/// Layanan posisi GPS (stream) untuk navigasi Mode Jalan dengan presisi tinggi.
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

  /// Stream posisi presisi tinggi real-time layaknya Google Maps navigasi.
  Stream<GeoPoint> positionStream() {
    LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(milliseconds: 800),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }
    return Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((position) => GeoPoint(
          position.latitude,
          position.longitude,
          accuracy: position.accuracy,
        ));
  }

  /// Ambil posisi terakhir yang tersimpan di sistem (instan tanpa menunggu sinyal satelit).
  Future<GeoPoint?> lastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return GeoPoint(
          position.latitude,
          position.longitude,
          accuracy: position.accuracy,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Ambil posisi sekali dengan tingkat akurasi tinggi (bestForNavigation).
  Future<GeoPoint?> currentPosition({
    Duration timeLimit = const Duration(seconds: 6),
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) async {
    try {
      LocationSettings settings;
      if (defaultTargetPlatform == TargetPlatform.android) {
        settings = AndroidSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
          forceLocationManager: false,
        );
      } else {
        settings = LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      return GeoPoint(
        position.latitude,
        position.longitude,
        accuracy: position.accuracy,
      );
    } catch (_) {
      return null;
    }
  }

  /// Mengambil posisi saat ini dengan memprioritaskan akurasi satelit tinggi (< 20 meter).
  Future<GeoPoint?> getAccuratePosition({
    Duration timeLimit = const Duration(seconds: 4),
  }) async {
    final fresh = await currentPosition(
      timeLimit: timeLimit,
      accuracy: LocationAccuracy.bestForNavigation,
    );
    if (fresh != null && (fresh.accuracy == null || fresh.accuracy! <= 20.0)) {
      return fresh;
    }
    final lastKnown = await lastKnownPosition();
    if (fresh != null) {
      if (lastKnown != null &&
          (lastKnown.accuracy ?? 100) < (fresh.accuracy ?? 100)) {
        return lastKnown;
      }
      return fresh;
    }
    return lastKnown;
  }
}
