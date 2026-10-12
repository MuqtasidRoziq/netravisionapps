import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/visual_help_models.dart';

class ContactsService extends GetxService {
  static const String _storageKey = 'netravision_trusted_contacts';
  static const String _legacyPhoneKey = 'legacy_emergency_phone';

  final RxList<TrustedContact> contacts = <TrustedContact>[].obs;

  Future<ContactsService> init() async {
    await loadContacts();
    return this;
  }

  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw) as List;
        contacts.assignAll(
          decoded.map((item) => TrustedContact.fromJson(item as Map<String, dynamic>)).toList(),
        );
      } catch (_) {
        contacts.clear();
      }
    }

    // Periksa migrasi dari nomor darurat versi lama
    final legacyPhone = prefs.getString(_legacyPhoneKey);
    if (legacyPhone != null && legacyPhone.isNotEmpty) {
      await migrateLegacyNumber(legacyPhone);
      await prefs.remove(_legacyPhoneKey);
    }

    // Jika kontak masih kosong, inisialisasi kontak default sebagai contoh
    if (contacts.isEmpty) {
      final defaultContact = TrustedContact(
        id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Keluarga / Wali Terdekat',
        phoneNumber: '081234567890',
        relationship: 'Keluarga',
        isWhatsAppAvailable: true,
      );
      await addContact(defaultContact);
    }
  }

  Future<void> addContact(TrustedContact contact) async {
    contacts.add(contact);
    await _saveToStorage();
  }

  Future<void> updateContact(TrustedContact updated) async {
    final index = contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      contacts[index] = updated;
      await _saveToStorage();
    }
  }

  Future<void> deleteContact(String id) async {
    contacts.removeWhere((c) => c.id == id);
    await _saveToStorage();
  }

  Future<void> migrateLegacyNumber(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return;

    // Cegah duplikasi jika nomor sudah ada
    final exists = contacts.any((c) => c.phoneNumber.replaceAll(RegExp(r'\D'), '') == cleanPhone.replaceAll(RegExp(r'\D'), ''));
    if (!exists) {
      final migrated = TrustedContact(
        id: 'migrated_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Kontak Cadangan (Migrasi V1)',
        phoneNumber: cleanPhone,
        relationship: 'Kontak Pribadi',
        isWhatsAppAvailable: true,
      );
      contacts.add(migrated);
      await _saveToStorage();
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
