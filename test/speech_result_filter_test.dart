import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/speech_result_filter.dart';

void main() {
  group('SpeechResultFilter.isEchoOfApp', () {
    test('mendeteksi gema pengumuman koordinat', () {
      expect(
        SpeechResultFilter.isEchoOfApp(
            'Titik koordinat terkunci: latitude -7.28, longitude 112.79'),
        isTrue,
      );
    });

    test('mendeteksi gema arahan navigasi', () {
      expect(SpeechResultFilter.isEchoOfApp('Menuju Warung, 300 meter'), isTrue);
      expect(SpeechResultFilter.isEchoOfApp('Anda telah tiba di tujuan'), isTrue);
    });

    test('ucapan pengguna biasa bukan gema', () {
      expect(SpeechResultFilter.isEchoOfApp('masjid terdekat'), isFalse);
      expect(SpeechResultFilter.isEchoOfApp('warung'), isFalse);
      expect(SpeechResultFilter.isEchoOfApp('menuju warung'), isFalse);
      expect(SpeechResultFilter.isEchoOfApp('ke indomaret'), isFalse);
    });
  });

  group('SpeechResultFilter.isUsable', () {
    test('terlalu pendek ditolak', () {
      expect(SpeechResultFilter.isUsable('ok'), isFalse);
      expect(SpeechResultFilter.isUsable(''), isFalse);
    });

    test('angka murni / koordinat ditolak', () {
      expect(SpeechResultFilter.isUsable('-7.28, 112.79'), isFalse);
      expect(SpeechResultFilter.isUsable('12345'), isFalse);
    });

    test('gema ditolak', () {
      expect(
        SpeechResultFilter.isUsable('silakan sebutkan tujuan anda'),
        isFalse,
      );
    });

    test('nama tempat valid diterima', () {
      expect(SpeechResultFilter.isUsable('stasiun gubeng'), isTrue);
      expect(SpeechResultFilter.isUsable('apotek terdekat'), isTrue);
      expect(SpeechResultFilter.isUsable('menuju warung'), isTrue);
      expect(SpeechResultFilter.isUsable('ke indomaret'), isTrue);
    });
  });
}
