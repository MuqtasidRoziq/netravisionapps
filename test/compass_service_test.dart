import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/services/compass_service.dart';

void main() {
  group('CompassService.headingToCardinalDirection', () {
    test('utara for 0, 360, 350, 10 degrees', () {
      expect(CompassService.headingToCardinalDirection(0), 'utara');
      expect(CompassService.headingToCardinalDirection(360), 'utara');
      expect(CompassService.headingToCardinalDirection(350), 'utara');
      expect(CompassService.headingToCardinalDirection(10), 'utara');
    });

    test('timur laut for 45 degrees', () {
      expect(CompassService.headingToCardinalDirection(45), 'timur laut');
    });

    test('timur for 90 degrees', () {
      expect(CompassService.headingToCardinalDirection(90), 'timur');
    });

    test('tenggara for 135 degrees', () {
      expect(CompassService.headingToCardinalDirection(135), 'tenggara');
    });

    test('selatan for 180 degrees', () {
      expect(CompassService.headingToCardinalDirection(180), 'selatan');
    });

    test('barat daya for 225 degrees', () {
      expect(CompassService.headingToCardinalDirection(225), 'barat daya');
    });

    test('barat for 270 degrees', () {
      expect(CompassService.headingToCardinalDirection(270), 'barat');
    });

    test('barat laut for 315 degrees', () {
      expect(CompassService.headingToCardinalDirection(315), 'barat laut');
    });
  });
}

