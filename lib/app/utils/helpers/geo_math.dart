import 'dart:math' as math;

/// Titik koordinat ringan (tanpa ketergantungan platform channel),
/// agar logika navigasi bisa diuji unit secara murni.
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint(this.lat, this.lng);

  bool get isValid => lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      (other.lat - lat).abs() < 1e-9 &&
      (other.lng - lng).abs() < 1e-9;

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode;

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Jarak dua titik dalam meter (rumus Haversine, akurasi cukup untuk
/// jarak pejalan kaki).
double haversineMeters(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  final lat1 = _toRad(a.lat);
  final lat2 = _toRad(b.lat);
  final dLat = _toRad(b.lat - a.lat);
  final dLng = _toRad(b.lng - a.lng);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Arah (bearing) dari [a] ke [b] dalam derajat 0–360 (utara = 0).
double bearingDegrees(GeoPoint a, GeoPoint b) {
  final lat1 = _toRad(a.lat);
  final lat2 = _toRad(b.lat);
  final dLng = _toRad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}

/// Selisih arah berarah (signed) antara [from] dan [to] dalam derajat,
/// dibatasi -180..180. Negatif ≈ belok kiri, positif ≈ belok kanan.
double bearingDifference(double from, double to) {
  var diff = (to - from) % 360;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return diff;
}

/// Decode encoded polyline Google ke daftar titik (presisi default 5 digit).
List<GeoPoint> decodePolyline(String encoded, {int precision = 5}) {
  final list = <GeoPoint>[];
  final factor = math.pow(10.0, precision).toDouble();
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    var shift = 0;
    var result = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    list.add(GeoPoint(lat / factor, lng / factor));
  }
  return list;
}

double _toRad(double deg) => deg * math.pi / 180;

/// Format jarak alami untuk TTS, mis. "350 meter" atau "1,8 kilometer".
String formatDistanceMeters(double meters) {
  if (meters < 1000) {
    final rounded = meters.round().clamp(1, 9999);
    return '$rounded meter';
  }
  final km = meters / 1000;
  final rounded = (km * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kilometer';
}