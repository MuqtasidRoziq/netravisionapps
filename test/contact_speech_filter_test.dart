import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/contact_speech_filter.dart';

void main() {
  group('ContactSpeechFilter Tests', () {
    test('Ekstraksi nama kontak dari berbagai variasi ucapan suara', () {
      expect(ContactSpeechFilter.extractContactName('Cari Ilma'), 'ilma');
      expect(ContactSpeechFilter.extractContactName('Tolong telepon Ibu'), 'ibu');
      expect(ContactSpeechFilter.extractContactName('Cari kontak Ibu dong'), 'ibu');
      expect(ContactSpeechFilter.extractContactName('Tolong telepon Budi ya'), 'budi');
      expect(ContactSpeechFilter.extractContactName('Cari kontak yang namanya Ilma'), 'ilma');
      expect(ContactSpeechFilter.extractContactName('Video call Budi Santoso'), 'budi santoso');
      expect(ContactSpeechFilter.extractContactName('Hubungi ke Ayah'), 'ayah');
      expect(ContactSpeechFilter.extractContactName('Tolong carikan kontak Dokter Rina'), 'dokter rina');
      expect(ContactSpeechFilter.extractContactName('VC sama Ilma'), 'ilma');
      expect(ContactSpeechFilter.extractContactName('Ilma'), 'ilma');
    });

    test('Menolak gema TTS / instruksi aplikasi', () {
      expect(ContactSpeechFilter.extractContactName('halaman kontak'), '');
      expect(ContactSpeechFilter.extractContactName('sedang mendengarkan'), '');
      expect(ContactSpeechFilter.extractContactName('sebutkan nama'), '');
      expect(ContactSpeechFilter.extractContactName('cari'), '');
      expect(ContactSpeechFilter.extractContactName('telepon'), '');
    });

    test('Pencocokan nama kontak presisi dan pencegahan salah nama (isMatch)', () {
      expect(ContactSpeechFilter.isMatch('ilma', 'Ilma'), true);
      expect(ContactSpeechFilter.isMatch('budi', 'Budi Santoso'), true);
      expect(ContactSpeechFilter.isMatch('santoso', 'Budi Santoso'), true);
      expect(ContactSpeechFilter.isMatch('ayah', 'Ayah Kandung'), true);
      expect(ContactSpeechFilter.isMatch('dokter', 'dr. Siti'), true);

      // Pencegahan salah kontak (false positives)
      expect(ContactSpeechFilter.isMatch('adi', 'Radit'), false);
      expect(ContactSpeechFilter.isMatch('dina', 'Indah'), false);
      expect(ContactSpeechFilter.isMatch('yahya', 'Budi Santoso'), false);

      // Spesifik: pencarian spesifik 'Ibu Santi' menolak kontak 'Ibu' saja
      expect(ContactSpeechFilter.isMatch('Ibu Santi', 'Ibu'), false);
    });

    test('Skor kecocokan spesifik (matchScore)', () {
      expect(ContactSpeechFilter.matchScore('Ibu', 'Ibu'), 100);
      expect(ContactSpeechFilter.matchScore('Ibu', 'Ibu Santi'), 80);
      expect(ContactSpeechFilter.matchScore('Ibu Santi', 'Ibu Santi'), 100);
      expect(ContactSpeechFilter.matchScore('Ibu Santi', 'Ibu'), 0);

      // Sapaan/gelar kehormatan di awal nama tetap cocok dengan nama inti
      expect(ContactSpeechFilter.matchScore('Mas Agus', 'Agus'), 95);
      expect(ContactSpeechFilter.matchScore('Agus', 'Mas Agus'), 95);
      expect(ContactSpeechFilter.matchScore('Pak Budi Santoso', 'Budi Santoso'), 95);

      // Catatan kurung dalam kontak dibersihkan
      expect(ContactSpeechFilter.matchScore('Budi', 'Budi (Kantor)'), 100);

      // Substring nama
      expect(ContactSpeechFilter.matchScore('Slamet', 'Slametriyadi'), 78);

      // Sinonim panggilan keluarga
      expect(ContactSpeechFilter.matchScore('Ibu', 'Mama'), 92);
      expect(ContactSpeechFilter.matchScore('Ayah', 'Papa'), 92);
      expect(ContactSpeechFilter.matchScore('Ayah', 'Bapak'), 92);

      // Toleransi salah dengar STT 1 huruf (Levenshtein)
      expect(ContactSpeechFilter.matchScore('Budy', 'Budi'), 85);
      expect(ContactSpeechFilter.matchScore('Rakhmat', 'Rahmat'), 85);
    });
  });
}
