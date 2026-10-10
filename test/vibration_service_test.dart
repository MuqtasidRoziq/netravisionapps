import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/services/vibration_service.dart';
import 'package:netravisionapps/app/utils/helpers/spatial_estimator.dart';

void main() {
  group('VibrationService.patternFor', () {
    test('bahaya mendapat pola denyut tegas', () {
      expect(
        VibrationService.patternFor(
          band: ProximityBand.dekat,
          dangerous: true,
        ),
        const [0, 350, 120, 350],
      );
    });

    test('sangat dekat mendapat pola lebih cepat', () {
      expect(
        VibrationService.patternFor(
          band: ProximityBand.sangatDekat,
          dangerous: false,
        ),
        const [0, 260, 160, 260],
      );
    });

    test('dekat mendapat pola lebih pelan', () {
      expect(
        VibrationService.patternFor(
          band: ProximityBand.dekat,
          dangerous: false,
        ),
        const [0, 200, 200, 300],
      );
    });

    test('sedang dan jauh tidak bergetar (null)', () {
      expect(
        VibrationService.patternFor(
          band: ProximityBand.sedang,
          dangerous: false,
        ),
        isNull,
      );
      expect(
        VibrationService.patternFor(
          band: ProximityBand.jauh,
          dangerous: false,
        ),
        isNull,
      );
    });
  });
}