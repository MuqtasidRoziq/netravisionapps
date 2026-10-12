import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/detection_filter.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

YOLOResult _box({
  required int classIndex,
  required double confidence,
  required Rect normalized,
}) {
  return YOLOResult(
    classIndex: classIndex,
    className: 'class_$classIndex',
    confidence: confidence,
    boundingBox: Rect.zero,
    normalizedBox: normalized,
  );
}

void main() {
  group('DetectionFilter.isPlausibleMoneyBox', () {
    test('menolak kotak kosong / tidak valid', () {
      expect(DetectionFilter.isPlausibleMoneyBox(Rect.zero), isFalse);
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0, 0, -1, -1),
        ),
        isFalse,
      );
    });

    test('menolak uang yang terlalu kecil (jauh dari kamera)', () {
      // Luas = 1% frame → di bawah ambang 3%.
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.4, 0.4, 0.1, 0.1),
        ),
        isFalse,
      );
    });

    test('menolak uang yang terpotong tepi bingkai (parsial)', () {
      // Kotak menempel tepi kiri bawah.
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.0, 0.6, 0.3, 0.3),
        ),
        isFalse,
      );
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.4, 0.0, 0.3, 0.3),
        ),
        isFalse,
      );
    });

    test('menerima uang berukuran wajar di tengah bingkai', () {
      // Luas = 9% frame, tidak menempel tepi.
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.3, 0.3, 0.3, 0.3),
        ),
        isTrue,
      );
    });

    test('menolak objek dengan lebar/tinggi terlalu kecil (< 8% layar)', () {
      // Tombol keyboard kecil misalnya lebar 0.05
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.3, 0.3, 0.05, 0.05),
        ),
        isFalse,
      );
    });

    test('menolak koin lonjong / tombol keyboard (aspect ratio > 1.8)', () {
      // Objek memanjang: w=0.35, h=0.12 -> rasio 2.9 > 1.8
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.2, 0.2, 0.35, 0.12),
          label: 'coin_1000',
        ),
        isFalse,
      );
    });

    test('menerima koin asli mendekati lingkaran (aspect ratio <= 1.8)', () {
      // Objek koin: w=0.2, h=0.2 -> rasio 1.0 <= 1.8
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.4, 0.4, 0.2, 0.2),
          label: 'coin_1000',
        ),
        isTrue,
      );
    });

    test('menolak uang kertas sangat pipih / kabel / list meja (aspect ratio > 3.2)', () {
      // Objek garis sangat panjang: w=0.8, h=0.1 -> rasio 8.0 > 3.2
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.1, 0.4, 0.8, 0.1),
          label: '10000',
        ),
        isFalse,
      );
    });

    test('menerima uang kertas proporsional (aspect ratio <= 3.2)', () {
      // Uang kertas normal: w=0.5, h=0.25 -> rasio 2.0 <= 3.2
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.2, 0.3, 0.5, 0.25),
          label: '10000',
        ),
        isTrue,
      );
    });
  });

  group('DetectionFilter.selectBest', () {
    test('memilih skor confidence × luas tertinggi, bukan pertama', () {
      final smallHighConf = _box(
        classIndex: 0,
        confidence: 0.9,
        normalized: const Rect.fromLTWH(0.45, 0.45, 0.07, 0.07), // area 0.005
      );
      final bigMediumConf = _box(
        classIndex: 1,
        confidence: 0.62,
        normalized: const Rect.fromLTWH(0.3, 0.3, 0.4, 0.4), // area 0.16
      );

      final best = DetectionFilter.selectBest([smallHighConf, bigMediumConf]);
      expect(best, bigMediumConf);
    });
  });

  group('DetectionFilter.isStable', () {
    test('belum stabil bila jendela belum penuh', () {
      expect(DetectionFilter.isStable([1, 1], 1), isFalse);
    });

    test('stabil bila classIndex muncul 2 dari 3 frame terakhir', () {
      expect(DetectionFilter.isStable([1, 1, 2], 1), isTrue);
      expect(DetectionFilter.isStable([3, 1, 1], 1), isTrue);
    });

    test('tidak stabil bila hanya 1 dari 3 frame', () {
      expect(DetectionFilter.isStable([1, 2, 3], 1), isFalse);
    });
  });
}