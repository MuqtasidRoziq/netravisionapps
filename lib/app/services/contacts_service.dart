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

    // Bersihkan kontak fiktif dummy, 112, atau kontak pengujian Yahya
    final initialLen = contacts.length;
    contacts.removeWhere((c) {
      final digits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final name = c.name.toLowerCase();
      return digits == '081234567890' ||
          digits == '112' ||
          name.contains('yahya') ||
          digits.contains('85540116690');
    });
    if (contacts.length != initialLen) {
      await _saveToStorage();
    }
  }

  /// Memastikan kontak Ilma (0895422727533) tersedia di daftar kontak keluarga
  Future<void> ensureIlmaContact() async {
    final beforeCount = contacts.length;
    contacts.removeWhere((c) {
      final digits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final name = c.name.toLowerCase();
      return name.contains('yahya') || digits.contains('85540116690');
    });
    bool changed = contacts.length != beforeCount;

    final ilmaIndex = contacts.indexWhere((c) => c.phoneNumber.replaceAll(RegExp(r'\D'), '').contains('895422727533'));
    if (ilmaIndex < 0) {
      final ilmaContact = TrustedContact(
        id: 'contact_ilma_primary',
        name: 'Ilma',
        phoneNumber: '0895422727533',
        relationship: 'Keluarga',
        isWhatsAppAvailable: true,
      );
      contacts.insert(0, ilmaContact);
      changed = true;
    } else if (ilmaIndex > 0) {
      final ilma = contacts.removeAt(ilmaIndex);
      contacts.insert(0, ilma);
      changed = true;
    }

    if (changed) {
      await _saveToStorage();
    }
  }

  /// Kontak darurat utama: nomor kontak keluarga/wali yang didaftarkan pengguna
  TrustedContact? get primaryEmergencyContact {
    if (contacts.isNotEmpty) return contacts.first;
    return null;
  }

  /// True jika pengguna sudah mendaftarkan kontak keluarga pribadi
  bool get hasFamilyContact => contacts.isNotEmpty;

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
