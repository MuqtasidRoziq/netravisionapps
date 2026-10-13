import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/data/models/vision_mode.dart';
import 'package:netravisionapps/app/data/models/vision_model_config.dart';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

void main() {
  group('VisionModelConfig mapping model ↔ fitur', () {
    test('Mode Baca Uang memakai model rupiah dengan task detect', () {
      final config = VisionModelConfig.forMode(VisionMode.currency);
      expect(config.modelPath, 'assets/models/rupiah/best.tflite');
      expect(config.task, YOLOTask.detect);
    });

    test('Mode Outdoor memakai model indoor detect 80 kelas', () {
      final config = VisionModelConfig.forMode(VisionMode.outdoor);
      expect(config.modelPath, 'assets/models/indoor/indoor_objects.tflite');
      expect(config.task, YOLOTask.detect);
    });

    test('Mode Indoor memakai model indoor khusus (detect 80 kelas)', () {
      final config = VisionModelConfig.forMode(VisionMode.indoor);
      expect(config.modelPath, 'assets/models/indoor/indoor_objects.tflite');
      expect(config.task, YOLOTask.detect);
    });

    test('Mode Baca Uang punya ambang confidence lebih ketat (> 0.55)', () {
      final currency = VisionModelConfig.forMode(VisionMode.currency);
      final outdoor = VisionModelConfig.forMode(VisionMode.outdoor);
      expect(currency.confidenceThreshold, 0.65);
      expect(currency.confidenceThreshold, greaterThan(outdoor.confidenceThreshold));
    });
  });
}