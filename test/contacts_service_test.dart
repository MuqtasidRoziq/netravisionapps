import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/data/models/visual_help_models.dart';
import 'package:netravisionapps/app/services/contacts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ContactsService & Migration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Inisialisasi kontak bersih tanpa nomor palsu jika penyimpanan kosong', () async {
      final service = ContactsService();
      await service.init();

      expect(service.contacts.isEmpty, true);
      expect(service.primaryEmergencyContact, isNull);
      expect(service.hasFamilyContact, false);
    });

    test('Menambah, memperbarui, dan menghapus kontak tepercaya', () async {
      final service = ContactsService();
      await service.init();

      final newContact = TrustedContact(
        id: 'contact_custom_01',
        name: 'Relawan Komunitas Budi',
        phoneNumber: '085712345678',
        relationship: 'Sahabat',
        isWhatsAppAvailable: true,
      );

      await service.addContact(newContact);
      expect(service.contacts.any((c) => c.id == 'contact_custom_01'), true);

      // Perbarui
      const updated = TrustedContact(
        id: 'contact_custom_01',
        name: 'Relawan Komunitas Budi (Updated)',
        phoneNumber: '085712345678',
        relationship: 'Sahabat',
        isWhatsAppAvailable: true,
      );
      await service.updateContact(updated);
      expect(
        service.contacts.firstWhere((c) => c.id == 'contact_custom_01').name,
        'Relawan Komunitas Budi (Updated)',
      );

      // Hapus
      await service.deleteContact('contact_custom_01');
      expect(service.contacts.any((c) => c.id == 'contact_custom_01'), false);
    });

    test('Migrasi nomor legacy V1 tanpa kehilangan data dan tanpa ganda', () async {
      SharedPreferences.setMockInitialValues({
        'legacy_emergency_phone': '089912349999',
      });

      final service = ContactsService();
      await service.init();

      // Memverifikasi nomor legacy termigrasi ke list
      expect(service.contacts.any((c) => c.phoneNumber == '089912349999'), true);

      // Migrasi ulang nomor yang sama tidak boleh membuat entri ganda
      await service.migrateLegacyNumber('089912349999');
      final matches = service.contacts.where((c) => c.phoneNumber == '089912349999');
      expect(matches.length, 1);
    });

    test('Pembersihan data kontak Ilma lama dari penyimpanan sistem', () async {
      SharedPreferences.setMockInitialValues({
        'netravision_trusted_contacts': '[{"id":"contact_ilma_primary","name":"Ilma","phoneNumber":"0895422727533","relationship":"Keluarga","isWhatsAppAvailable":true}]',
      });

      final service = ContactsService();
      await service.init();

      // Memastikan kontak Ilma lama dihapus bersih dari sistem
      expect(service.contacts.any((c) => c.name.toLowerCase().contains('ilma')), false);
      expect(service.contacts.any((c) => c.phoneNumber.contains('895422727533')), false);
    });

    test('Validasi nomor seluler (isValidMobileNumber) mencegah nomor salah', () {
      expect(ContactsService.isValidMobileNumber('0895422727533'), true);
      expect(ContactsService.isValidMobileNumber('+6281234567890'), true);
      expect(ContactsService.isValidMobileNumber('6285712345678'), true);
      expect(ContactsService.isValidMobileNumber('081123456'), true); // Nomor 9 digit Halo/Mentari

      // Nomor tidak valid / telepon rumah / darurat yang harus ditolak
      expect(ContactsService.isValidMobileNumber('112'), false);
      expect(ContactsService.isValidMobileNumber('123'), false);
      expect(ContactsService.isValidMobileNumber('0217654321'), false); // Telepon rumah Jakarta
      expect(ContactsService.isValidMobileNumber('0221234567'), false); // Telepon rumah Bandung
      expect(ContactsService.isValidMobileNumber('12345'), false);
    });

    test('Pencarian kontak berdasarkan suara query, nomor telepon, dan normalisasi nomor', () async {
      final service = ContactsService();
      await service.init();

      await service.addContact(
        const TrustedContact(
          id: 'c1',
          name: 'Siti Rahma',
          phoneNumber: '085811223344',
          relationship: 'Keluarga',
          isWhatsAppAvailable: true,
        ),
      );

      await service.addContact(
        const TrustedContact(
          id: 'c2',
          name: 'Budi Santoso',
          phoneNumber: '081234567890',
          relationship: 'Sahabat',
          isWhatsAppAvailable: true,
        ),
      );

      // Cari dengan ucapan suara "Cari Siti"
      final results1 = await service.searchContacts('Cari Siti');
      expect(results1.length, 1);
      expect(results1.first.name, 'Siti Rahma');

      // Cari dengan ucapan suara "Tolong telepon Budi"
      final results2 = await service.searchContacts('Tolong telepon Budi');
      expect(results2.length, 1);
      expect(results2.first.name, 'Budi Santoso');

      // Cari dengan sebagian nomor telepon "085811"
      final resultsNum = await service.searchContacts('085811');
      expect(resultsNum.length, 1);
      expect(resultsNum.first.name, 'Siti Rahma');

      // Normalisasi nomor telepon
      expect(ContactsService.normalizePhoneNumber('0895-4227-27533'), '62895422727533');
      expect(ContactsService.normalizePhoneNumber('+62 812 3456 7890'), '6281234567890');
    });

    test('Dua kontak dengan nama berbeda yang memiliki nomor sama keduanya tetap tersedia', () async {
      final service = ContactsService();
      await service.init();

      await service.addContact(
        const TrustedContact(
          id: 'c_rumah',
          name: 'Keluarga Rumah',
          phoneNumber: '081234567899',
          relationship: 'Rumah',
          isWhatsAppAvailable: true,
        ),
      );

      await service.addContact(
        const TrustedContact(
          id: 'c_ayah',
          name: 'Ayah',
          phoneNumber: '081234567899',
          relationship: 'Orang Tua',
          isWhatsAppAvailable: true,
        ),
      );

      // Keduanya harus tetap ada di allAvailableContacts
      expect(service.allAvailableContacts.length, 2);
      expect(service.allAvailableContacts.any((c) => c.name == 'Keluarga Rumah'), true);
      expect(service.allAvailableContacts.any((c) => c.name == 'Ayah'), true);

      // Dan keduanya bisa dicari secara terpisah
      final searchAyah = await service.searchContacts('Ayah');
      expect(searchAyah.length, 1);
      expect(searchAyah.first.name, 'Ayah');

      final searchRumah = await service.searchContacts('Keluarga Rumah');
      expect(searchRumah.length, 1);
      expect(searchRumah.first.name, 'Keluarga Rumah');
    });

    test('Pencarian kontak spesifik (misal: "Ibu" hanya menghasilkan "Ibu", dan sebaliknya)', () async {
      final service = ContactsService();
      await service.init();

      await service.addContact(
        const TrustedContact(
          id: 'c_ibu',
          name: 'Ibu',
          phoneNumber: '081111111111',
          relationship: 'Orang Tua',
          isWhatsAppAvailable: true,
        ),
      );

      await service.addContact(
        const TrustedContact(
          id: 'c_ibu_santi',
          name: 'Ibu Santi',
          phoneNumber: '082222222222',
          relationship: 'Guru',
          isWhatsAppAvailable: true,
        ),
      );

      await service.addContact(
        const TrustedContact(
          id: 'c_ibu_guru',
          name: 'Ibu Guru Ani',
          phoneNumber: '083333333333',
          relationship: 'Sekolah',
          isWhatsAppAvailable: true,
        ),
      );

      // 1. Saat mencari "Ibu", HANYA kontak "Ibu" yang muncul (bukan Ibu Santi atau Ibu Guru Ani)
      final resultsIbu = await service.searchContacts('Cari Ibu');
      expect(resultsIbu.length, 1);
      expect(resultsIbu.first.name, 'Ibu');

      // 2. Saat mencari "Ibu Santi", HANYA kontak "Ibu Santi" yang muncul (bukan Ibu atau Ibu Guru Ani)
      final resultsIbuSanti = await service.searchContacts('Tolong telepon Ibu Santi');
      expect(resultsIbuSanti.length, 1);
      expect(resultsIbuSanti.first.name, 'Ibu Santi');
    });

    test('Filter kontak WhatsApp (isContactRegisteredOnWhatsApp) membedakan kontak WhatsApp dan non-WhatsApp', () {
      final waContact = Contact(
        id: '1',
        displayName: 'Siti WA',
        phones: [Phone('081234567890')],
        accounts: [Account('raw1', 'com.whatsapp', 'siti@wa', ['vnd.android.cursor.item/vnd.com.whatsapp.profile'])],
      );

      final nonWaContact = Contact(
        id: '2',
        displayName: 'Pak RT Non-WA',
        phones: [Phone('0217654321')],
        accounts: [Account('raw2', 'com.google', 'user@gmail.com', ['vnd.android.cursor.item/phone_v2'])],
      );

      // 1. Kontak dengan akun WhatsApp
      expect(
        ContactsService.isContactRegisteredOnWhatsApp(waContact, '081234567890'),
        true,
      );

      // 2. Kontak non-WhatsApp tanpa nomor di database WhatsApp
      expect(
        ContactsService.isContactRegisteredOnWhatsApp(nonWaContact, '0217654321'),
        false,
      );

      // 3. Kontak non-WhatsApp tapi nomornya terdaftar di database WhatsApp
      expect(
        ContactsService.isContactRegisteredOnWhatsApp(
          nonWaContact,
          '081234567890',
          registeredNumbers: {'6281234567890'},
        ),
        true,
      );
    });
  });
}
