import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/data/models/vision_mode.dart';
import 'package:netravisionapps/app/utils/helpers/object_speech_helper.dart';

void main() {
  group('ObjectSpeechHelper.shouldAnnounce', () {
    test('mengabaikan label latar yang tidak perlu dibacakan', () {
      for (final label in ['langit', 'tanah', 'latar belakang', 'luar area']) {
        expect(ObjectSpeechHelper.shouldAnnounce(label, VisionMode.outdoor),
            isFalse,
            reason: '$label harus diabaikan');
      }
    });

    test('menerima objek yang layak diumumkan', () {
      expect(
          ObjectSpeechHelper.shouldAnnounce('mobil', VisionMode.outdoor),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('tangga', VisionMode.indoor),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('kursi', VisionMode.indoor),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('kucing', VisionMode.indoor),
          isTrue);
    });

    test('mengabaikan kelas outdoor, kendaraan, hewan liar, dan olahraga saat Mode Indoor', () {
      final ignoredIndoor = [
        'mobil',
        'sepeda',
        'sepeda motor',
        'pesawat terbang',
        'bus',
        'truk',
        'perahu',
        'lampu lalu lintas',
        'hidran kebakaran',
        'rambu berhenti',
        'meteran parkir',
        'bangku',
        'burung',
        'gajah',
        'zebra',
        'jerapah',
        'kuda',
        'frisbee',
        'ski',
        'papan salju',
        'papan selancar',
        'raket tenis',
      ];
      for (final label in ignoredIndoor) {
        expect(
          ObjectSpeechHelper.shouldAnnounce(label, VisionMode.indoor),
          isFalse,
          reason: '$label harus diabaikan di Mode Indoor',
        );
      }
    });
  });

  group('ObjectSpeechHelper.isDangerousObstacle', () {
    test('mengenali rintangan berbahaya (huruf besar/kecil tidak masalah)', () {
      for (final label in [
        'jalan berlubang',
        'tangga',
        'tiang',
        'mobil',
        'bus',
        'Truk',
      ]) {
        expect(ObjectSpeechHelper.isDangerousObstacle(label), isTrue,
            reason: '$label harus dianggap berbahaya');
      }
    });

    test('objek biasa bukan rintangan berbahaya', () {
      expect(ObjectSpeechHelper.isDangerousObstacle('pohon dan tanaman'),
          isFalse);
      expect(ObjectSpeechHelper.isDangerousObstacle('gedung'), isFalse);
    });
  });

  group('ObjectSpeechHelper.formatForTts', () {
    setUpAll(() {
      // SystemChrome diset agar HapticFeedback tidak butuh device nyata.
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('mode uang memetakan nominal ke kalimat fasih', () {
      expect(
        ObjectSpeechHelper.formatForTts('10000', VisionMode.currency),
        'Uang sepuluh ribu rupiah',
      );
      expect(
        ObjectSpeechHelper.formatForTts('100000', VisionMode.currency),
        'Uang seratus ribu rupiah',
      );
    });

    test('rintangan berbahaya memunculkan peringatan', () {
      expect(
        ObjectSpeechHelper.formatForTts('mobil', VisionMode.outdoor),
        'Awas, ada mobil di depan!',
      );
    });

    test('objek biasa dibacakan natural tanpa letupan getar', () {
      expect(
        ObjectSpeechHelper.formatForTts('kursi', VisionMode.indoor),
        'Ada kursi di depan',
      );
    });
  });

  group('ObjectSpeechHelper.formatDisplayName', () {
    test('memformat nominal uang menjadi label rupiah yang rapi untuk UI', () {
      expect(
        ObjectSpeechHelper.formatDisplayName('1000', VisionMode.currency),
        'Uang Rp 1.000',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('10000', VisionMode.currency),
        'Uang Rp 10.000',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('100000', VisionMode.currency),
        'Uang Rp 100.000',
      );
    });

    test('mempertahankan label non-mata uang apa adanya', () {
      expect(
        ObjectSpeechHelper.formatDisplayName('mobil', VisionMode.outdoor),
        'mobil',
      );
    });
  });
}