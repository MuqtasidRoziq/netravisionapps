import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/spatial_estimator.dart';

void main() {
  group('SpatialEstimator klasifikasi zona', () {
    test('horizontal: kiri/depan/kanan', () {
      expect(SpatialEstimator.classifyHorizontal(const Rect.fromLTRB(0.0, 0.1, 0.3, 0.2)),
          HorizontalZone.kiri);
      expect(SpatialEstimator.classifyHorizontal(const Rect.fromLTRB(0.3, 0, 0.7, 0.4)),
          HorizontalZone.depan);
      expect(SpatialEstimator.classifyHorizontal(const Rect.fromLTRB(0.7, 0, 1.0, 0.3)),
          HorizontalZone.kanan);
    });

    test('vertikal: atas/tengah/bawah', () {
      expect(SpatialEstimator.classifyVertical(const Rect.fromLTRB(0.1, 0.0, 0.2, 0.3)),
          VerticalZone.atas);
      expect(SpatialEstimator.classifyVertical(const Rect.fromLTRB(0.1, 0.3, 0.2, 0.7)),
          VerticalZone.tengah);
      expect(SpatialEstimator.classifyVertical(const Rect.fromLTRB(0.1, 0.7, 0.2, 1.0)),
          VerticalZone.bawah);
    });

    test('band kedekatan dari luas kotak', () {
      expect(SpatialEstimator.classifyProximity(const Rect.fromLTRB(0, 0, 0.5, 0.5)),
          ProximityBand.sangatDekat);
      expect(SpatialEstimator.classifyProximity(const Rect.fromLTRB(0, 0, 0.3, 0.3)),
          ProximityBand.dekat);
      expect(SpatialEstimator.classifyProximity(const Rect.fromLTRB(0, 0, 0.2, 0.2)),
          ProximityBand.sedang);
      expect(SpatialEstimator.classifyProximity(const Rect.fromLTRB(0, 0, 0.1, 0.1)),
          ProximityBand.jauh);
    });
  });
}
