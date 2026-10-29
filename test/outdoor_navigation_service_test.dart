import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/services/directions_service.dart';
import 'package:netravisionapps/app/services/places_service.dart';
import 'package:netravisionapps/app/utils/helpers/geo_math.dart';
import 'package:netravisionapps/app/utils/helpers/navigation_models.dart';

void main() {
  group('PlacesService & DirectionsService Fallback Tests', () {
    test('DirectionsService direct-line fallback generates valid route', () {
      const origin = GeoPoint(-7.28, 112.79);
      const destination = GeoPoint(-7.285, 112.795);

      final result = DirectionsService.getDirectLineRoute(
        origin: origin,
        destination: destination,
      );

      expect(result.steps.length, 1);
      expect(result.steps.first.maneuver, 'depart');
      expect(result.steps.first.instruction, contains('Mulai berjalan'));
      expect(result.destination, destination);
      expect(result.totalMeters, greaterThan(0));
    });

    test('DirectionsService OSRM maneuver mapping', () {
      expect(DirectionsService.osrmManeuverToGoogle('depart', ''), 'depart');
      expect(DirectionsService.osrmManeuverToGoogle('arrive', ''), 'arrive');
      expect(DirectionsService.osrmManeuverToGoogle('turn', 'left'), 'turn-left');
      expect(DirectionsService.osrmManeuverToGoogle('turn', 'right'), 'turn-right');
      expect(DirectionsService.osrmManeuverToGoogle('turn', 'slight left'), 'turn-slight-left');
      expect(DirectionsService.osrmManeuverToGoogle('turn', 'sharp right'), 'turn-sharp-right');
      expect(DirectionsService.osrmManeuverToGoogle('turn', 'uturn'), 'u-turn');
    });

    test('DirectionsService OSRM instruction formatting', () {
      expect(
        DirectionsService.formatOsrmInstruction('turn', 'left', 'Jalan Teknik Kimia'),
        'Belok kiri ke Jalan Teknik Kimia',
      );
      expect(
        DirectionsService.formatOsrmInstruction('turn', 'right', ''),
        'Belok kanan',
      );
      expect(
        DirectionsService.formatOsrmInstruction('depart', '', 'Jalan Despro'),
        'Mulai berjalan di Jalan Despro',
      );
      expect(
        DirectionsService.formatOsrmInstruction('arrive', '', ''),
        'Anda telah tiba di tujuan',
      );
    });

    test('PlacesService synonyms for generic queries', () {
      final synMakan = PlacesService.synonymsForQuery('makan');
      expect(synMakan, contains('warung'));

      final synMasjid = PlacesService.synonymsForQuery('masjid');
      expect(synMasjid, contains('musholla'));

      final synMinimarket = PlacesService.synonymsForQuery('minimarket');
      expect(synMinimarket, contains('indomaret'));
    });
  });

  group('PlacesService.selectNearest', () {
    test('memilih kandidat dengan jarak terdekat, bukan urutan pertama', () {
      // Meniru kasus "cari PT": hasil pertama = kantor pusat yang jauh,
      // hasil kedua = cabang dekat. Harus memilih cabang dekat.
      final candidates = [
        const GeoPlace(
          name: 'PT Contoh (Kantor Pusat)',
          point: GeoPoint(-6.2, 106.816666),
          distanceMeters: 42000,
        ),
        const GeoPlace(
          name: 'PT Contoh Cabang',
          point: GeoPoint(-7.28, 112.79),
          distanceMeters: 320,
        ),
      ];

      final chosen = PlacesService.selectNearest(candidates);
      expect(chosen, isNotNull);
      expect(chosen!.name, 'PT Contoh Cabang');
      expect(chosen.distanceMeters, 320);
    });

    test('kandidat tanpa jarak dianggap paling jauh', () {
      final candidates = [
        const GeoPlace(
          name: 'Tanpa Jarak',
          point: GeoPoint(-6.2, 106.816666),
        ),
        const GeoPlace(
          name: 'Ada Jarak',
          point: GeoPoint(-7.28, 112.79),
          distanceMeters: 1500,
        ),
      ];

      expect(PlacesService.selectNearest(candidates)!.name, 'Ada Jarak');
    });

    test('daftar kosong mengembalikan null', () {
      expect(PlacesService.selectNearest(const []), isNull);
    });
  });

  group('PlacesService radius lokal', () {
    test('tahapan radius meningkat & tidak melebihi batas keras 15 km', () {
      final tiers = PlacesService.radiusTiers;
      expect(tiers, isNotEmpty);
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], greaterThan(tiers[i - 1]));
      }
      expect(tiers.last, PlacesService.maxRadiusMeters);
      expect(
        PlacesService.localRadiusMeters,
        lessThanOrEqualTo(tiers.first),
      );
    });

    test('PlaceSearchResult tanpa place tidak dianggap ditemukan', () {
      const empty = PlaceSearchResult(place: null, beyondLocal: false);
      expect(empty.found, isFalse);
    });
  });
}

