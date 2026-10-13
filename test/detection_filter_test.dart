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

    test('menerima uang kertas berukuran wajar di tengah bingkai', () {
      // Luas = 9.9% frame, rasio ~2.05 (proporsional uang Rupiah asli), di tengah bingkai.
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.25, 0.35, 0.45, 0.22),
          label: '5000',
        ),
        isTrue,
      );
    });

    test('menolak objek dengan lebar/tinggi terlalu kecil (< 14% sisi pendek)', () {
      // Tombol keyboard kecil atau noise misalnya lebar 0.08
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.3, 0.3, 0.08, 0.08),
          label: '5000',
        ),
        isFalse,
      );
    });

    test('menolak koin lonjong / tombol keyboard (aspect ratio > 1.25)', () {
      // Objek memanjang: w=0.35, h=0.20 -> rasio 1.75 > 1.25
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.3, 0.3, 0.35, 0.20),
          label: 'coin_1000',
        ),
        isFalse,
      );
    });

    test('menerima koin asli mendekati lingkaran (aspect ratio 0.85 s/d 1.25)', () {
      // Objek koin: w=0.25, h=0.25 -> rasio 1.0 (dalam rentang 0.85..1.25)
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.35, 0.35, 0.25, 0.25),
          label: 'coin_1000',
        ),
        isTrue,
      );
    });

    test('menolak uang kertas sangat pipih / kabel / list meja (aspect ratio > 2.65)', () {
      // Objek garis sangat panjang: w=0.8, h=0.15 -> rasio 5.3 > 2.65
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.1, 0.4, 0.8, 0.15),
          label: '10000',
        ),
        isFalse,
      );
    });

    test('menolak objek bujur sangkar / laptop / buku / kotak (aspect ratio < 1.35)', () {
      // Objek bujur sangkar w=0.3, h=0.3 -> rasio 1.0 < 1.35 (bukan uang kertas)
      expect(
        DetectionFilter.isPlausibleMoneyBox(
          const Rect.fromLTWH(0.3, 0.3, 0.3, 0.3),
          label: '5000',
        ),
        isFalse,
      );
    });

    test('menerima uang kertas proporsional (aspect ratio 1.35 s/d 2.65)', () {
      // Uang kertas normal: w=0.5, h=0.25 -> rasio 2.0 (sesuai uang Rupiah)
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

    test('stabil bila classIndex muncul 2 dari 3 frame terakhir (default)', () {
      expect(DetectionFilter.isStable([1, 1, 2], 1), isTrue);
      expect(DetectionFilter.isStable([3, 1, 1], 1), isTrue);
    });

    test('tidak stabil bila hanya 1 dari 3 frame', () {
      expect(DetectionFilter.isStable([1, 2, 3], 1), isFalse);
    });

    test('mode baca uang stabil bila muncul 3 dari 4 frame', () {
      expect(
        DetectionFilter.isStable(
          [5, 5, 5, 2],
          5,
          windowSize: DetectionFilter.currencyTemporalWindowSize,
          requiredHits: DetectionFilter.currencyTemporalRequiredHits,
        ),
        isTrue,
      );
      expect(
        DetectionFilter.isStable(
          [5, 5, 2, 3],
          5,
          windowSize: DetectionFilter.currencyTemporalWindowSize,
          requiredHits: DetectionFilter.currencyTemporalRequiredHits,
        ),
        isFalse,
      );
    });
  });
}