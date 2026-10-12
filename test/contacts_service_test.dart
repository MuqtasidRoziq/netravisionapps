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

    test('Inisialisasi kontak memberikan setidaknya 1 kontak default jika penyimpanan kosong', () async {
      final service = ContactsService();
      await service.init();

      expect(service.contacts.length, greaterThanOrEqualTo(1));
      expect(service.contacts.first.name, contains('Keluarga'));
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
  });
}
