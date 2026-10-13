import 'package:flutter_compass/flutter_compass.dart';
import 'package:get/get.dart';

/// Arah hadap pengguna dari kompas (magnetometer), dengan pemulusan sederhana.
///
/// Peta ditampilkan "utara di atas", panah pengguna berputar mengikuti heading
/// ini. Heading kompas goyah di dekat logam, jadi dilicinkan (EMA).
class CompassService extends GetxService {
  double _smoothed = 0;
  bool _hasValue = false;

  /// Heading saat ini (0–360, utara = 0). Null bila kompas tak tersedia.
  double? get lastHeading => _hasValue ? _smoothed : null;

  Stream<double> headingStream() {
    final events = FlutterCompass.events;
    if (events == null) return const Stream.empty();

    var haveValue = false;
    var smoothed = 0.0;

    return events.map<num?>((event) {
      final heading = event.heading;
      if (heading == null) return null;
      final next = _normalize(heading);
      if (!haveValue) {
        smoothed = next;
        haveValue = true;
      } else {
        var diff = (next - smoothed + 540) % 360 - 180;
        smoothed = _normalize(smoothed + diff * 0.25);
      }
      _hasValue = haveValue;
      _smoothed = smoothed;
      return smoothed;
    }).where((h) => h != null).map((h) => h!.toDouble());
  }

  static double _normalize(double deg) {
    var d = deg % 360;
    if (d < 0) d += 360;
    return d;
  }
}