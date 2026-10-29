import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/data/models/vision_mode.dart';
import 'package:netravisionapps/app/data/models/vision_model_config.dart';
import 'package:netravisionapps/app/utils/helpers/object_speech_helper.dart';
import 'package:netravisionapps/app/utils/helpers/single_object_search_catalog.dart';
import 'package:netravisionapps/app/utils/helpers/spatial_estimator.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SingleObjectSearchCatalog', () {
    test('quickTargets memuat barang penting harian', () {
      final labels =
          SingleObjectSearchCatalog.quickTargets.map((t) => t.label).toSet();
      expect(labels.contains('tas punggung'), isTrue);
      expect(labels.contains('ponsel'), isTrue);
      expect(labels.contains('botol'), isTrue);
      expect(labels.contains('cangkir'), isTrue);
      expect(labels.contains('kursi'), isTrue);
      expect(labels.contains('sendok'), isTrue);
      expect(labels.contains('laptop'), isTrue);
      expect(labels.contains('buku'), isTrue);
      expect(labels.contains('gunting'), isTrue);
      expect(labels.contains('payung'), isTrue);
      expect(labels.contains('tas tangan'), isTrue);
    });

    test('seluruh 50 target memiliki label unik dan valid', () {
      final seenLabels = <String>{};
      expect(SingleObjectSearchCatalog.allTargets.length, 50);
      for (final t in SingleObjectSearchCatalog.allTargets) {
        expect(t.label.isNotEmpty, isTrue);
        expect(t.displayName.isNotEmpty, isTrue);
        expect(t.category.isNotEmpty, isTrue);
        expect(seenLabels.contains(t.label), isFalse,
            reason: 'Label ${t.label} tidak boleh duplikat');
        seenLabels.add(t.label);
      }
    });

    test('getDisplayName mengembalikan nama ramah Indonesia', () {
      expect(SingleObjectSearchCatalog.getDisplayName('tas punggung'),
          'Tas Ransel / Punggung');
      expect(SingleObjectSearchCatalog.getDisplayName('ponsel'), 'Ponsel / HP');
      expect(SingleObjectSearchCatalog.getDisplayName('botol'), 'Botol Minum');
      expect(SingleObjectSearchCatalog.getDisplayName('cangkir'),
          'Cangkir / Gelas');
      expect(SingleObjectSearchCatalog.getDisplayName('kursi'), 'Kursi');
      expect(SingleObjectSearchCatalog.getDisplayName('laptop'), 'Laptop');
      expect(SingleObjectSearchCatalog.getDisplayName('kulkas'), 'Kulkas');
      expect(SingleObjectSearchCatalog.getDisplayName('televisi'), 'Televisi');
    });
  });

  group('ObjectSpeechHelper - Single Object Search', () {
    test('formatForTts saat target belum terlihat', () {
      final speech = ObjectSpeechHelper.formatForTts(
        'ponsel',
        VisionMode.findObject,
        spatial: null,
        targetObject: 'ponsel',
      );
      expect(speech, 'ponsel belum terlihat di kamera.');
    });

    test('formatForTts saat target terdeteksi dengan arah dan jarak', () {
      const spatial = SpatialInfo(
        horizontal: HorizontalZone.kanan,
        vertical: VerticalZone.tengah,
        band: ProximityBand.dekat,
        meters: 1.5,
      );

      final speech = ObjectSpeechHelper.formatForTts(
        'ponsel',
        VisionMode.findObject,
        spatial: spatial,
        targetObject: 'ponsel',
      );

      expect(
        speech,
        'ponsel ditemukan! Ada di samping kanan, sekitar 1,5 meter di depan Anda.',
      );
    });

    test('formatForTts saat target sangat dekat dan siap dijangkau', () {
      const spatial = SpatialInfo(
        horizontal: HorizontalZone.depan,
        vertical: VerticalZone.tengah,
        band: ProximityBand.sangatDekat,
        meters: 0.4,
      );

      final speech = ObjectSpeechHelper.formatForTts(
        'botol',
        VisionMode.findObject,
        spatial: spatial,
        targetObject: 'botol',
      );

      expect(
        speech,
        'botol sangat dekat di depan Anda, siap dijangkau!',
      );
    });

    test('formatDisplayName memformat indikator status UI dengan rapi', () {
      const spatial = SpatialInfo(
        horizontal: HorizontalZone.kiri,
        vertical: VerticalZone.atas,
        band: ProximityBand.dekat,
        meters: 2.0,
      );

      final display = ObjectSpeechHelper.formatDisplayName(
        'kursi',
        VisionMode.findObject,
        spatial: spatial,
        targetObject: 'kursi',
      );

      expect(display, '🎯 kursi · kiri · atas · 2 m');
    });
  });

  group('VisionModelConfig untuk Single Object Search', () {
    test('menggunakan model indoor_objects.tflite dengan threshold terkalibrasi',
        () {
      final config = VisionModelConfig.forMode(VisionMode.findObject);
      expect(config.modelPath, 'assets/models/indoor/indoor_objects.tflite');
      expect(config.task, YOLOTask.detect);
      expect(config.confidenceThreshold, 0.25);
      expect(config.iouThreshold, 0.45);
    });
  });

  group('SingleObjectSearchCatalog.matches', () {
    test('mencocokkan tas ransel / tas punggung / backpack secara fleksibel', () {
      expect(SingleObjectSearchCatalog.matches('tas punggung', 'tas punggung'), isTrue);
      expect(SingleObjectSearchCatalog.matches('backpack', 'tas punggung'), isTrue);
      expect(SingleObjectSearchCatalog.matches('tas ransel', 'tas punggung'), isTrue);
      expect(SingleObjectSearchCatalog.matches('tas', 'tas punggung'), isTrue);
      expect(SingleObjectSearchCatalog.matches('botol', 'tas punggung'), isFalse);
    });

    test('mencocokkan ponsel / phone / hp', () {
      expect(SingleObjectSearchCatalog.matches('phone', 'ponsel'), isTrue);
      expect(SingleObjectSearchCatalog.matches('ponsel', 'ponsel'), isTrue);
      expect(SingleObjectSearchCatalog.matches('smartphone', 'hp'), isTrue);
      expect(SingleObjectSearchCatalog.matches('laptop', 'ponsel'), isFalse);
    });

    test('mencocokkan kunci / keys dan dompet / wallet', () {
      expect(SingleObjectSearchCatalog.matches('keys', 'kunci'), isTrue);
      expect(SingleObjectSearchCatalog.matches('wallet', 'dompet'), isTrue);
      expect(SingleObjectSearchCatalog.matches('glasses', 'kacamata'), isTrue);
      expect(SingleObjectSearchCatalog.matches('medicine', 'obat'), isTrue);
    });
  });
}
