import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/geo_math.dart';

void main() {
  group('haversineMeters', () {
    test('jarak dua titik sejajar khatulistiwa ~111,2 m per 0,001 derajat', () {
      final meters = haversineMeters(
        const GeoPoint(0, 0),
        const GeoPoint(0, 0.001),
      );
      expect(meters, closeTo(111.2, 1.0));
    });

    test('jarak antar titik sama = 0', () {
      expect(haversineMeters(const GeoPoint(-6.2, 106.8), const GeoPoint(-6.2, 106.8)),
          0);
    });
  });

  group('bearingDegrees', () {
    test('timur = 90, barat = 270, utara = 0', () {
      expect(bearingDegrees(const GeoPoint(0, 0), const GeoPoint(0, 0.1)),
          closeTo(90, 0.01));
      expect(bearingDegrees(const GeoPoint(0, 0), const GeoPoint(0, -0.1)),
          closeTo(270, 0.01));
      expect(bearingDegrees(const GeoPoint(0, 0), const GeoPoint(0.1, 0)),
          closeTo(0, 0.01));
    });
  });

  group('bearingDifference', () {
    test('selisih berarah dibatasi -180..180', () {
      expect(bearingDifference(10, 30), closeTo(20, 0.01));
      expect(bearingDifference(350, 10), closeTo(20, 0.01));
      expect(bearingDifference(20, 350), closeTo(-30, 0.01));
      expect(bearingDifference(0, 180), closeTo(180, 0.01));
    });
  });

  group('decodePolyline', () {
    test('contoh kanonik Google ter-decode ke koordinat yang benar', () {
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = decodePolyline(encoded);
      expect(points, hasLength(3));
      expect(points[0].lat, closeTo(38.5, 1e-4));
      expect(points[0].lng, closeTo(-120.2, 1e-4));
      expect(points[1].lat, closeTo(40.7, 1e-4));
      expect(points[1].lng, closeTo(-120.95, 1e-4));
      expect(points[2].lat, closeTo(43.252, 1e-4));
      expect(points[2].lng, closeTo(-126.453, 1e-4));
    });

    test('string kosong menghasilkan daftar kosong', () {
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('formatDistanceMeters', () {
    test('format meter dan kilometer alami', () {
      expect(formatDistanceMeters(350), '350 meter');
      expect(formatDistanceMeters(999), '999 meter');
      expect(formatDistanceMeters(1750), '1,8 kilometer');
      expect(formatDistanceMeters(2000), '2 kilometer');
    });
  });
}