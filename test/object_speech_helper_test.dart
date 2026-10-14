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
    });

    test('mode baca uang HANYA menerima 13 kelas pecahan rupiah resmi', () {
      expect(
          ObjectSpeechHelper.shouldAnnounce('10000', VisionMode.currency),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('coin_1000', VisionMode.currency),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('75000', VisionMode.currency),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('keyboard', VisionMode.currency),
          isFalse);
      expect(
          ObjectSpeechHelper.shouldAnnounce('laptop', VisionMode.currency),
          isFalse);
      expect(
          ObjectSpeechHelper.shouldAnnounce('mobil', VisionMode.currency),
          isFalse);
      expect(
          ObjectSpeechHelper.shouldAnnounce('meja', VisionMode.currency),
          isFalse);
    });
  });

  group('ObjectSpeechHelper.shouldAnnounce (whitelist uang)', () {
    test('mode uang hanya meloloskan nominal kertas', () {
      for (final label in [
        '1000',
        '2000',
        '5000',
        '10000',
        '20000',
        '50000',
        '75000',
        '100000',
      ]) {
        expect(
          ObjectSpeechHelper.shouldAnnounce(label, VisionMode.currency),
          isTrue,
          reason: '$label harus diumumkan di Mode Baca Uang',
        );
      }
    });

    test('mode uang hanya meloloskan koin (coin_<nominal>)', () {
      for (final label in [
        'coin_1000',
        'coin_500',
        'coin_200',
        'coin_100',
        'coin_50',
      ]) {
        expect(
          ObjectSpeechHelper.shouldAnnounce(label, VisionMode.currency),
          isTrue,
          reason: '$label harus diumumkan di Mode Baca Uang',
        );
      }
    });

    test('mode uang menolak label non-uang (fallback class N, objek lain)', () {
      for (final label in ['class 0', 'class 1', 'class 13', 'mobil',
          'orang', 'uang', 'kursi', '']) {
        expect(
          ObjectSpeechHelper.shouldAnnounce(label, VisionMode.currency),
          isFalse,
          reason: '$label bukan uang sehingga harus ditolak',
        );
      }
    });

    test('whitelist uang tidak mengubah mode lain', () {
      expect(
          ObjectSpeechHelper.shouldAnnounce('mobil', VisionMode.outdoor),
          isTrue);
      expect(
          ObjectSpeechHelper.shouldAnnounce('class 0', VisionMode.indoor),
          isTrue);
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
        ObjectSpeechHelper.formatDisplayName('75000', VisionMode.currency),
        'Uang Rp 75.000',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('100000', VisionMode.currency),
        'Uang Rp 100.000',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('coin_1000', VisionMode.currency),
        'Koin Rp 1.000',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('coin_50', VisionMode.currency),
        'Koin Rp 50',
      );
    });

    test('mempertahankan label non-mata uang apa adanya', () {
      expect(
        ObjectSpeechHelper.formatDisplayName('mobil', VisionMode.outdoor),
        'mobil',
      );
    });

    test('menerjemahkan class index outdoor ke nama Indonesia', () {
      expect(
        ObjectSpeechHelper.formatDisplayName('class 2', VisionMode.outdoor),
        'mobil',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('car', VisionMode.outdoor),
        'mobil',
      );
      expect(
        ObjectSpeechHelper.formatDisplayName('tree_trunk', VisionMode.outdoor),
        'batang pohon',
      );
    });
  });

  group('ObjectSpeechHelper.resolveLabel (Outdoor Translation)', () {
    test('menerjemahkan string fallback "class X" ke Bahasa Indonesia', () {
      expect(ObjectSpeechHelper.resolveLabel('class 0'), 'skuter atau sepeda');
      expect(ObjectSpeechHelper.resolveLabel('class 1'), 'bus');
      expect(ObjectSpeechHelper.resolveLabel('class 2'), 'mobil');
      expect(ObjectSpeechHelper.resolveLabel('class 5'), 'sepeda motor');
      expect(ObjectSpeechHelper.resolveLabel('class 7'), 'orang');
      expect(ObjectSpeechHelper.resolveLabel('class 8'), 'truk');
      expect(ObjectSpeechHelper.resolveLabel('class 10'), 'barikade jalan');
      expect(ObjectSpeechHelper.resolveLabel('class 12'), 'tiang pembatas trotoar');
      expect(ObjectSpeechHelper.resolveLabel('class 16'), 'tiang');
      expect(ObjectSpeechHelper.resolveLabel('class 21'), 'lampu lalu lintas');
      expect(ObjectSpeechHelper.resolveLabel('class 22'), 'rambu lalu lintas');
      expect(ObjectSpeechHelper.resolveLabel('class 23'), 'batang pohon');
    });

    test('menerjemahkan nama kelas bahasa Inggris ke Bahasa Indonesia', () {
      expect(ObjectSpeechHelper.resolveLabel('car'), 'mobil');
      expect(ObjectSpeechHelper.resolveLabel('motorcycle'), 'sepeda motor');
      expect(ObjectSpeechHelper.resolveLabel('tree_trunk'), 'batang pohon');
      expect(ObjectSpeechHelper.resolveLabel('tree trunk'), 'batang pohon');
      expect(ObjectSpeechHelper.resolveLabel('traffic_sign'), 'rambu lalu lintas');
      expect(ObjectSpeechHelper.resolveLabel('person'), 'orang');
    });

    test('mendukung resolusi via parameter classIndex numerik', () {
      expect(ObjectSpeechHelper.resolveLabel('', classIndex: 2), 'mobil');
      expect(ObjectSpeechHelper.resolveLabel('', classIndex: 5), 'sepeda motor');
      expect(ObjectSpeechHelper.resolveLabel('', classIndex: 23), 'batang pohon');
    });

    test('rintangan berbahaya teridentifikasi walau inputnya "class X" atau Inggris', () {
      expect(ObjectSpeechHelper.isDangerousObstacle('class 2'), isTrue); // mobil
      expect(ObjectSpeechHelper.isDangerousObstacle('car'), isTrue);
      expect(ObjectSpeechHelper.isDangerousObstacle('class 5'), isTrue); // motor
      expect(ObjectSpeechHelper.isDangerousObstacle('class 23'), isTrue); // pohon
      expect(ObjectSpeechHelper.isDangerousObstacle('class 7'), isFalse); // orang
    });

    test('TTS berbicara nama Indonesia yang ramah ketika input class X', () {
      expect(
        ObjectSpeechHelper.formatForTts('class 2', VisionMode.outdoor),
        'Awas, ada mobil di depan!',
      );
      expect(
        ObjectSpeechHelper.formatForTts('class 7', VisionMode.outdoor),
        'Ada orang di depan',
      );
    });
  });
}