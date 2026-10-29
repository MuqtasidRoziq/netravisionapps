import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:netravisionapps/app/data/models/navigation_models.dart';
import 'package:netravisionapps/app/services/location_service.dart';

void main() {
  group('LocationService kalkulasi sudut & kompas', () {
    late LocationService service;

    setUp(() {
      service = LocationService();
    });

    test('calculateRelativeBearing membungkus sudut ke -180..+180', () {
      // Menghadap 350° (sedikit ke kiri dari utara), target di 10° (sedikit ke kanan dari utara)
      final diff1 = service.calculateRelativeBearing(350, 10);
      expect(diff1, 20.0);

      // Menghadap 10°, target di 350°
      final diff2 = service.calculateRelativeBearing(10, 350);
      expect(diff2, -20.0);

      // Menghadap 90°, target 90°
      final diff3 = service.calculateRelativeBearing(90, 90);
      expect(diff3, 0.0);
    });

    test('bearingToClockFace mengonversi sudut relatif ke analogi jam yang tepat', () {
      // 0° = lurus depan = jam 12
      expect(service.bearingToClockFace(0), 'arah jam 12 (lurus depan)');
      expect(service.bearingToClockFace(5), 'arah jam 12 (lurus depan)');
      expect(service.bearingToClockFace(-10), 'arah jam 12 (lurus depan)');

      // +30° = jam 1
      expect(service.bearingToClockFace(30), 'arah jam 1');

      // +60° = jam 2
      expect(service.bearingToClockFace(60), 'arah jam 2');

      // +90° = jam 3 (samping kanan)
      expect(service.bearingToClockFace(90), 'arah jam 3 (samping kanan)');

      // +180° = jam 6 (putar balik)
      expect(service.bearingToClockFace(180), 'arah jam 6 (putar balik ke belakang)');
      expect(service.bearingToClockFace(-180), 'arah jam 6 (putar balik ke belakang)');

      // -90° (atau 270°) = jam 9 (samping kiri)
      expect(service.bearingToClockFace(-90), 'arah jam 9 (samping kiri)');

      // -30° (atau 330°) = jam 11
      expect(service.bearingToClockFace(-30), 'arah jam 11');
    });

    test('headingToCardinal mengonversi derajat ke mata angin Indonesia', () {
      expect(service.headingToCardinal(0), 'Utara');
      expect(service.headingToCardinal(45), 'Timur Laut');
      expect(service.headingToCardinal(90), 'Timur');
      expect(service.headingToCardinal(135), 'Tenggara');
      expect(service.headingToCardinal(180), 'Selatan');
      expect(service.headingToCardinal(225), 'Barat Daya');
      expect(service.headingToCardinal(270), 'Barat');
      expect(service.headingToCardinal(315), 'Barat Laut');
      expect(service.headingToCardinal(359), 'Utara');
    });
  });

  group('NavigationModels testing', () {
    test('NearbyPlaceModel format jarak dan ucapan ramah suara', () {
      const place1 = NearbyPlaceModel(
        id: '1',
        name: 'Halte Transjakarta UI',
        category: PlaceCategory.transport,
        point: LatLng(-6.365, 106.831),
        distanceMeters: 65.4,
        relativeBearing: 30.0,
        clockDirection: 'arah jam 1',
      );

      expect(place1.formattedDistance, '65 meter');
      expect(place1.speechAnnouncement, 'Halte Transjakarta UI, berjarak 65 meter, di arah jam 1 Anda.');

      const place2 = NearbyPlaceModel(
        id: '2',
        name: 'Stasiun Universitas Indonesia',
        category: PlaceCategory.transport,
        point: LatLng(-6.360, 106.830),
        distanceMeters: 1250.0,
        relativeBearing: 0.0,
        clockDirection: 'arah jam 12',
      );

      expect(place2.formattedDistance, '1,3 km');
    });

    test('NavigationRoute format total jarak dan estimasi waktu', () {
      const route = NavigationRoute(
        totalDistanceMeters: 250.0,
        estimatedDurationSeconds: 180.0, // 3 menit
        polylinePoints: [LatLng(-6.36, 106.83), LatLng(-6.361, 106.831)],
        steps: [],
        destinationName: 'Indomaret Sawo',
      );

      expect(route.formattedTotalDistance, '250 meter');
      expect(route.formattedEstimatedTime, 'sekitar 3 menit');
    });
  });
}
