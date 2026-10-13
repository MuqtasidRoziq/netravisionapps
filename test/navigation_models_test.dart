import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/geo_math.dart';
import 'package:netravisionapps/app/utils/helpers/navigation_models.dart';

RouteResult _simpleRoute() {
  // Langkah 1: lurus 111 m ke timur (0,0) → (0.001,0).
  const start = GeoPoint(0, 0);
  const corner = GeoPoint(0.001, 0);
  const dest = GeoPoint(0.001, -0.0003); // belok kiri dari titik corner.
  return RouteResult(
    steps: [
      RouteStep(
        instruction: 'Lurus terus menuju toko',
        maneuver: 'straight',
        distanceMeters: 111.2,
        start: start,
        end: corner,
        points: [start, corner],
      ),
      RouteStep(
        instruction: 'Belok kiri menuju jalan kecil',
        maneuver: 'turn-left',
        distanceMeters: 33.4,
        start: corner,
        end: dest,
        points: [corner, dest],
      ),
    ],
    overviewPoints: const [start, corner, dest],
    destination: dest,
    totalMeters: 144.6,
  );
}

// ~111,19 m per 0,001 derajat di khatulistiwa.
double _metersToDeg(double m) => m / 111195;


void main() {
  group('extractDestinationQuery', () {
    test('buang frase perintah, sisakan tujuan', () {
      expect(extractDestinationQuery('saya ingin pergi ke warung'), 'warung');
      expect(extractDestinationQuery('tolong antar saya ke rumah sakit'), 'rumah sakit');
      expect(extractDestinationQuery('saya mau ke pasar'), 'pasar');
      expect(extractDestinationQuery('carikan apotek'), 'apotek');
    });

    test('tanpa frase perintah = kalimat utuh', () {
      expect(extractDestinationQuery('warung sari'), 'warung sari');
    });
  });

  group('NavigationGuider.tick', () {
    final t0 = DateTime(2026, 1, 1, 0, 0, 0);

    test('berangkat: mengumumkan langkah pertama', () {
      final guider = NavigationGuider(_simpleRoute());
      final tick = guider.tick(const GeoPoint(0, 0), t0);
      expect(tick.arrived, isFalse);
      expect(tick.activeStepIndex, 0);
      expect(tick.speech, contains('Mulai berjalan'));
      expect(tick.remainingMeters, closeTo(144.6, 5));
    });

    test('mendekati belokan: sebutkan jarak', () {
      final guider = NavigationGuider(_simpleRoute());
      guider.tick(const GeoPoint(0, 0), t0);
      // 33 m sebelum titik belok.
      final pos = GeoPoint(_metersToDeg(111.2 - 33), 0);
      final tick = guider.tick(pos, t0.add(const Duration(seconds: 2)));
      expect(tick.speech, contains('33 meter lagi'));
    });

    test('di belokan: instruksi tegas', () {
      final guider = NavigationGuider(_simpleRoute());
      guider.tick(const GeoPoint(0, 0), t0);
      // 33 m → 15 m dari titik belok.
      var pos = GeoPoint(_metersToDeg(111.2 - 33), 0);
      guider.tick(pos, t0.add(const Duration(seconds: 2)));
      pos = GeoPoint(_metersToDeg(111.2 - 15), 0);
      final tick = guider.tick(pos, t0.add(const Duration(seconds: 4)));
      expect(tick.speech, contains('Belok kiri menuju jalan kecil sekarang'));
    });

    test('bergeser ke langkah berikutnya setelah melewati belokan', () {
      final guider = NavigationGuider(_simpleRoute());
      guider.tick(const GeoPoint(0, 0), t0);
      // Hanya 5 m setelah titik belok (dalam advanceRadius 10 m).
      final pos = GeoPoint(_metersToDeg(111.2 + 5), 0);
      final tick = guider.tick(pos, t0.add(const Duration(seconds: 6)));
      expect(tick.activeStepIndex, greaterThanOrEqualTo(1));
      expect(tick.speech, isNot(contains('Mulai berjalan')));
    });

    test('tiba saat dekat titik tujuan', () {
      final guider = NavigationGuider(_simpleRoute());
      final tick = guider.tick(
          const GeoPoint(0.001, -0.0003), t0.add(const Duration(seconds: 8)));
      expect(tick.arrived, isTrue);
      expect(tick.speech, contains('tiba'));
    });

    test('pengingat berkala "lanjutkan lurus" bila sudah lama di langkah yang sama', () {
      final guider = NavigationGuider(_simpleRoute());
      guider.tick(const GeoPoint(0, 0), t0);
      // Masih di langkah 1, jauh dari belokan, 31 detik sejak pengumuman.
      final pos = GeoPoint(_metersToDeg(22), 0);
      final tick =
          guider.tick(pos, t0.add(const Duration(seconds: 31)));
      expect(tick.speech, contains('Lanjutkan lurus'));
    });

    test('tidak bicara berulang tanpa alasan (diam saat tick biasa)', () {
      final guider = NavigationGuider(_simpleRoute());
      guider.tick(const GeoPoint(0, 0), t0);
      // Tick kedua tak lama kemudian, posisi hampir sama (di atas 40 m).
      final pos = GeoPoint(_metersToDeg(11), 0);
      final tick = guider.tick(pos, t0.add(const Duration(seconds: 2)));
      expect(tick.speech, isNull);
    });
  });

  group('NavigationGuider.cleanHtml', () {
    test('bersihkan tag html instruksi Google', () {
      expect(
        NavigationGuider.cleanHtml('Belok <b>kiri</b> menuju <b>Jl. Merdeka</b>'),
        'Belok kiri menuju Jl. Merdeka',
      );
    });
  });
}