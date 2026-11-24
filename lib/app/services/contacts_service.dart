import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/visual_help_models.dart';
import '../utils/helpers/contact_speech_filter.dart';

class ContactsService extends GetxService {
  static const String _storageKey = 'netravision_trusted_contacts';
  static const String _legacyPhoneKey = 'legacy_emergency_phone';
  static const MethodChannel _whatsAppChannel = MethodChannel('com.netravision.apps/whatsapp');

  /// Daftar kontak keluarga & darurat utama yang tersimpan di aplikasi
  final RxList<TrustedContact> contacts = <TrustedContact>[].obs;

  /// Daftar kontak yang disinkronisasi dari buku telepon ponsel
  final RxList<TrustedContact> deviceContacts = <TrustedContact>[].obs;

  /// Status izin akses kontak
  final RxBool hasContactsPermission = false.obs;

  /// Status sedang memuat kontak dari HP
  final RxBool isSyncingDeviceContacts = false.obs;

  Future<ContactsService> init() async {
    // Pastikan seluruh kontak Android (termasuk kontak SIM, penyimpanan internal, dan akun non-grup) diikutsertakan
    FlutterContacts.config.includeNonVisibleOnAndroid = true;
    await loadContacts();
    // Auto-sync kontak HP di latar belakang saat service diinisialisasi
    autoSyncIfPermitted();
    return this;
  }

  Future<void> autoSyncIfPermitted() async {
    try {
      FlutterContacts.config.includeNonVisibleOnAndroid = true;
      final permitted = await FlutterContacts.requestPermission(readonly: true);
      hasContactsPermission.value = permitted;
      if (permitted) {
        await syncDeviceContacts();
      }
    } catch (_) {}
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

    // Bersihkan kontak fiktif dummy, 112, kontak pengujian Yahya, atau kontak bawaan Ilma
    final initialLen = contacts.length;
    contacts.removeWhere((c) {
      final digits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final name = c.name.toLowerCase();
      return digits == '081234567890' ||
          digits == '112' ||
          name.contains('yahya') ||
          digits.contains('85540116690') ||
          name.contains('ilma') ||
          digits.contains('895422727533');
    });
    if (contacts.length != initialLen) {
      await _saveToStorage();
    }
  }

  /// Kontak darurat utama: nomor kontak keluarga/wali yang didaftarkan pengguna
  TrustedContact? get primaryEmergencyContact {
    if (contacts.isNotEmpty) return contacts.first;
    if (deviceContacts.isNotEmpty) return deviceContacts.first;
    return null;
  }

  /// True jika pengguna memiliki kontak keluarga pribadi atau kontak ponsel
  bool get hasFamilyContact => contacts.isNotEmpty || deviceContacts.isNotEmpty;

  /// Seluruh kontak yang dapat dihubungi (kombinasi kontak tepercaya dan kontak buku telepon HP)
  List<TrustedContact> get allAvailableContacts {
    final List<TrustedContact> list = [];
    final Set<String> seenKeys = {};

    for (final c in contacts) {
      final key = '${c.name.trim().toLowerCase()}_${normalizePhoneNumber(c.phoneNumber)}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        list.add(c);
      }
    }

    for (final dc in deviceContacts) {
      final key = '${dc.name.trim().toLowerCase()}_${normalizePhoneNumber(dc.phoneNumber)}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        list.add(dc);
      }
    }

    return list;
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

  /// Meminta izin membaca kontak ponsel dan langsung melakukan sinkronisasi otomatis
  Future<bool> requestContactsPermission() async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      hasContactsPermission.value = granted;
      if (granted) {
        await syncDeviceContacts();
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Memvalidasi apakah nomor telepon merupakan nomor seluler wajar (untuk WhatsApp/Telepon)
  static bool isValidMobileNumber(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    // Nomor HP Indonesia: 08xx (9-14 digit), 628xx (10-15 digit), 8xx (9-13 digit)
    if (digits.startsWith('08') && digits.length >= 9 && digits.length <= 14) {
      return true;
    }
    if (digits.startsWith('628') && digits.length >= 10 && digits.length <= 15) {
      return true;
    }
    if (digits.startsWith('8') && digits.length >= 9 && digits.length <= 13) {
      return true;
    }
    // Format nomor internasional lainnya yang valid (10-16 digit, bukan telepon rumah area 021/022)
    if (digits.length >= 10 &&
        digits.length <= 16 &&
        !digits.startsWith('021') &&
        !digits.startsWith('022') &&
        !digits.startsWith('031')) {
      return true;
    }
    return false;
  }

  /// Memeriksa apakah kontak terdaftar di WhatsApp berdasarkan akun kontak atau nomor terdaftar
  static bool isContactRegisteredOnWhatsApp(
    Contact rc,
    String phoneDigits, {
    Set<String>? registeredNumbers,
  }) {
    // 1. Cek apakah salah satu akun pada raw contacts adalah akun WhatsApp resmi (com.whatsapp / com.whatsapp.w4b)
    final hasWaAccount = rc.accounts.any((a) {
      final t = a.type.toLowerCase();
      final hasWaType = t.contains('whatsapp') || t.contains('w4b');
      final hasWaMime = a.mimetypes.any((m) => m.toLowerCase().contains('whatsapp'));
      return hasWaType || hasWaMime;
    });
    if (hasWaAccount) return true;

    // 2. Cek apakah nomor telepon cocok dengan nomor yang terdaftar di database WhatsApp Android
    if (registeredNumbers != null && registeredNumbers.isNotEmpty) {
      final clean = normalizePhoneNumber(phoneDigits);
      final suffix8 = clean.length >= 8 ? clean.substring(clean.length - 8) : clean;
      for (final waNum in registeredNumbers) {
        if (waNum == clean || (suffix8.isNotEmpty && waNum.endsWith(suffix8))) {
          return true;
        }
      }
    }

    return false;
  }

  /// Membaca dan menyinkronkan seluruh kontak dari buku telepon HP
  /// Hanya kontak yang terdaftar di WhatsApp yang akan dimasukkan ke dalam sistem
  Future<List<TrustedContact>> syncDeviceContacts() async {
    FlutterContacts.config.includeNonVisibleOnAndroid = true;
    if (isSyncingDeviceContacts.value) return deviceContacts;
    isSyncingDeviceContacts.value = true;

    try {
      final rawContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withAccounts: true,
        withPhoto: false,
      );

      // Ambil daftar nomor terdaftar WhatsApp dari Android ContentProvider
      Set<String> waNumbers = {};
      try {
        final List<dynamic>? raw = await _whatsAppChannel.invokeMethod('getWhatsAppRegisteredNumbers');
        if (raw != null) {
          waNumbers = raw.map((e) => e.toString().replaceAll(RegExp(r'\D'), '')).toSet();
        }
      } catch (_) {}

      // Periksa apakah perangkat memiliki data WhatsApp yang dapat dijadikan acuan filter
      final bool hasWaFilterData = waNumbers.isNotEmpty ||
          rawContacts.any((rc) => rc.accounts.any((a) => a.type.toLowerCase().contains('whatsapp')));

      final List<TrustedContact> list = [];
      final Set<String> seenKeys = {};

      for (final rc in rawContacts) {
        if (rc.phones.isEmpty) continue;

        // Ambil display name, fallback ke nama depan/belakang, organisasi, atau nomor telepon
        var displayName = rc.displayName.trim();
        if (displayName.isEmpty) {
          displayName = '${rc.name.first} ${rc.name.last}'.trim();
        }
        if (displayName.isEmpty && rc.organizations.isNotEmpty) {
          displayName = rc.organizations.first.company.trim();
        }
        if (displayName.isEmpty && rc.phones.isNotEmpty) {
          displayName = rc.phones.first.number.trim();
        }
        if (displayName.isEmpty) continue;

        // Muat setiap nomor telepon yang dimiliki kontak
        for (final p in rc.phones) {
          final trimmed = p.number.trim();
          final cleanDigits = trimmed.replaceAll(RegExp(r'\D'), '');
          if (cleanDigits.length < 4) continue;

          // FILTER WHATSAPP: Hanya sertakan kontak yang terdaftar di WhatsApp jika data filter tersedia
          if (hasWaFilterData) {
            final isWaUser = isContactRegisteredOnWhatsApp(
              rc,
              cleanDigits,
              registeredNumbers: waNumbers,
            );
            if (!isWaUser) {
              continue; // Abaikan kontak yang tidak terdaftar di WhatsApp
            }
          }

          final key = '${displayName.toLowerCase()}_${normalizePhoneNumber(trimmed)}';
          if (seenKeys.contains(key)) continue;
          seenKeys.add(key);

          list.add(TrustedContact(
            id: 'device_${rc.id}_$cleanDigits',
            name: displayName,
            phoneNumber: trimmed,
            relationship: 'Kontak WhatsApp',
            isWhatsAppAvailable: true,
          ));
        }
      }

      // Urutkan alfabetis sesuai nama
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      deviceContacts.assignAll(list);
      hasContactsPermission.value = true;
      return list;
    } catch (_) {
      return deviceContacts;
    } finally {
      isSyncingDeviceContacts.value = false;
    }
  }

  /// Mencari kontak (berdasarkan suara ucapan, nama teks, atau nomor telepon)
  /// Menggabungkan kontak tepercaya aplikasi dan kontak buku telepon HP secara cerdas
  Future<List<TrustedContact>> searchContacts(String rawQuery) async {
    final clean = rawQuery.trim();
    if (clean.isEmpty) return [];

    final targetName = ContactSpeechFilter.extractContactName(clean);
    final queryText = targetName.isNotEmpty ? targetName : ContactSpeechFilter.normalize(clean);

    final queryDigits = clean.replaceAll(RegExp(r'\D'), '');
    final bool isNumberQuery = queryDigits.length >= 3;

    final List<MapEntry<TrustedContact, int>> scored = [];
    final Set<String> seenKeys = {};

    void evaluateCandidate(TrustedContact c, {bool isTrusted = false}) {
      final key = '${c.name.trim().toLowerCase()}_${normalizePhoneNumber(c.phoneNumber)}';
      if (seenKeys.contains(key)) return;

      int score = 0;
      if (queryText.isNotEmpty) {
        score = ContactSpeechFilter.matchScore(queryText, c.name);
      }

      // Dukungan pencarian jika user menyebut/mengetik nomor telepon
      if (isNumberQuery) {
        final phoneDigits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
        if (phoneDigits.contains(queryDigits)) {
          final numScore = phoneDigits == queryDigits ? 100 : 80;
          if (numScore > score) score = numScore;
        }
      }

      if (score >= 60) {
        seenKeys.add(key);
        final bonus = (isTrusted && score < 100) ? 2 : 0;
        scored.add(MapEntry(c, score + bonus));
      }
    }

    // 1. Cek di kontak tepercaya
    for (final c in contacts) {
      evaluateCandidate(c, isTrusted: true);
    }

    // 2. Cek di kontak buku telepon ponsel
    for (final dc in deviceContacts) {
      evaluateCandidate(dc, isTrusted: false);
    }

    if (scored.isEmpty) return [];

    // Urutkan dari skor kecocokan tertinggi
    scored.sort((a, b) => b.value.compareTo(a.value));

    final highestScore = scored.first.value;

    // JIKA ADA KANDIDAT EXACT MATCH (skor >= 100):
    // HANYA kontak yang benar-benar persis sama yang dimunculkan!
    // Contoh: User cari "Ibu" -> HANYA "Ibu" yang muncul (menolak "Ibu Santi", "Ibu Guru")
    // Dan sebaliknya: User cari "Ibu Santi" -> HANYA "Ibu Santi" yang muncul
    if (highestScore >= 100) {
      return scored.where((e) => e.value >= 100).map((e) => e.key).toList();
    }

    // JIKA TIDAK ADA EXACT MATCH:
    // Tampilkan SEMUA kandidat yang cocok (skor >= 65), diurutkan dari skor tertinggi.
    return scored.where((e) => e.value >= 65).map((e) => e.key).toList();
  }

  /// Normalisasi nomor telepon ke format standar (hanya angka, 08... menjadi 628...)
  static String normalizePhoneNumber(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }
    return digits;
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
