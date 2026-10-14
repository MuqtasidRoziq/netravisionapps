import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/models/visual_help_models.dart';
import '../../../services/auto_click_service.dart';
import '../../../services/contacts_service.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/visual_help_controller.dart';

class TrustedContactsView extends GetView<VisualHelpController> {
  const TrustedContactsView({super.key});

  @override
  Widget build(BuildContext context) {
    final contactsService = Get.find<ContactsService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.speakTrustedContactsIntro();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak Keluarga & Darurat'),
        leading: Semantics(
          label: 'Kembali ke Menu Bantuan Relawan.',
          hint: 'Aktifkan untuk kembali',
          button: true,
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryBlue,
            ),
            onPressed: () => controller.handleContactsBackButtonTap(),
          ),
        ),
        actions: [
          Semantics(
            label: 'Tambah Kontak Baru.',
            hint: 'Aktifkan untuk membuka formulir',
            button: true,
            child: IconButton(
              tooltip: 'Tambah Kontak',
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primaryBlue,
              ),
              onPressed: () => controller.handleAddContactButtonTap(
                () => _showAddContactDialog(context, contactsService),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Banner Status Layanan Auto-Klik Aksesibilitas
            Obx(() {
              final autoClick = Get.isRegistered<AutoClickService>()
                  ? Get.find<AutoClickService>()
                  : null;
              final isEnabled =
                  autoClick?.isAccessibilityGranted.value ?? false;
              if (isEnabled) return const SizedBox.shrink();

              return Semantics(
                label: 'Perhatian: Layanan Auto-Klik WhatsApp belum aktif. Ketuk untuk membuka menu Pengaturan Aksesibilitas ponsel dan mengaktifkannya.',
                button: true,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFB300),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: Color(0xFFF57C00),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Auto-Klik WhatsApp Belum Aktif',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Aktifkan Layanan Aksesibilitas NetraVision agar video call & pesan WA otomatis tertekan tanpa perlu meraba layar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5D4037),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF57C00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () {
                                autoClick?.requestPermission();
                              },
                              child: const Text(
                                'Aktifkan Sekarang',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Banner Panduan Pengisian oleh Orang Terdekat
            Semantics(
              label: 'Panduan: Minta bantuan keluarga atau orang terdekat untuk mengetikkan nomor WhatsApp dan telepon Anda di sini melalui tombol Tambah Kontak di atas agar siap dihubungi kapan saja.',
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: AppColors.primaryBlue,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Panduan Pengisian Nomor',
                            style: TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Minta bantuan keluarga atau orang terdekat untuk mengetikkan nomor WhatsApp dan telepon Anda di sini melalui tombol "Tambah Kontak" (+) di atas agar siap dihubungi kapan saja.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daftar Kontak Tepercaya
            Obx(() {
              final list = contactsService.contacts;
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lightBlueBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.primaryBlue,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Kontak Tersimpan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Silakan minta bantuan keluarga atau orang terdekat untuk mengisikan nomor WhatsApp atau telepon mereka agar Anda dapat menghubungi mereka dengan cepat.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Obx(() {
                        final isSelected =
                            controller.selectedContactActionKey.value ==
                            'add_contact';
                        return Semantics(
                          label: 'Minta Orang Terdekat Isi Nomor Baru.',
                          hint: 'Aktifkan untuk membuka formulir',
                          button: true,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: isSelected
                                      ? const BorderSide(
                                          color: AppColors.yellowAccent,
                                          width: 3,
                                        )
                                      : BorderSide.none,
                                ),
                                elevation: isSelected ? 4 : 1,
                              ),
                              onPressed: () =>
                                  controller.handleAddContactButtonTap(
                                    () => _showAddContactDialog(
                                      context,
                                      contactsService,
                                    ),
                                  ),
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 22,
                              ),
                              label: Text(
                                isSelected
                                    ? 'Konfirmasi Buka Formulir'
                                    : 'Minta Orang Terdekat Isi Nomor',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }

              return Column(
                children: list.map((contact) {
                  return Obx(() {
                    final isCardSelected =
                        controller.selectedContactActionKey.value ==
                        'card_${contact.id}';
                    return Card(
                      elevation: isCardSelected ? 4 : 2,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: isCardSelected
                            ? const BorderSide(
                                color: AppColors.primaryBlue,
                                width: 2.5,
                              )
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => controller.handleContactCardTap(contact),
                        child: Semantics(
                          label:
                              'Kontak ${contact.name}, ${contact.relationship}, nomor ${contact.phoneNumber}.',
                          hint: 'Aktifkan untuk membuka pilihan panggilan',
                          button: true,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            contact.name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${contact.relationship} • ${contact.phoneNumber}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Obx(() {
                                      final isDeleteSelected =
                                          controller
                                              .selectedContactActionKey
                                              .value ==
                                          'delete_${contact.id}';
                                      return Semantics(
                                        label: 'Hapus kontak ${contact.name}.',
                                        hint: 'Aktifkan untuk menghapus kontak',
                                        button: true,
                                        child: IconButton(
                                          tooltip: 'Hapus kontak',
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: isDeleteSelected
                                                ? AppColors.emergencyRed
                                                : Colors.grey,
                                            size: isDeleteSelected ? 28 : 24,
                                          ),
                                          onPressed: () => controller
                                              .handleDeleteContactTap(contact),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // 3 Tombol Aksi Langsung: 1. Telepon Seluler (Langsung), 2. Telepon WA, 3. Chat
                                Row(
                                  children: [
                                    // 1. Telepon Seluler (Panggilan Langsung Tanpa Chat)
                                    Expanded(
                                      flex: 4,
                                      child: Obx(() {
                                        final isPhoneSelected =
                                            controller
                                                .selectedContactActionKey
                                                .value ==
                                            'phone_${contact.id}';
                                        return Semantics(
                                          label:
                                              'Panggil ${contact.name} via Telepon Seluler langsung tanpa chat.',
                                          hint: 'Aktifkan untuk memanggil langsung',
                                          button: true,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryBlue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: isPhoneSelected
                                                    ? const BorderSide(
                                                        color: Colors.white,
                                                        width: 2.5,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              elevation: isPhoneSelected
                                                  ? 4
                                                  : 1,
                                            ),
                                            onPressed: () => controller
                                                .handleContactPhoneTap(contact),
                                            icon: const Icon(
                                              Icons.phone_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isPhoneSelected
                                                  ? 'Panggil'
                                                  : 'Telepon',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. VC WhatsApp (Video Call Langsung ke Keluarga)
                                    Expanded(
                                      flex: 4,
                                      child: Obx(() {
                                        final isWaSelected =
                                            controller
                                                .selectedContactActionKey
                                                .value ==
                                            'wa_voice_${contact.id}';
                                        return Semantics(
                                          label:
                                              'Panggil ${contact.name} via Video Call WhatsApp langsung.',
                                          hint: 'Aktifkan untuk memulai video call',
                                          button: true,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF25D366,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: isWaSelected
                                                    ? const BorderSide(
                                                        color: Colors.white,
                                                        width: 2.5,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              elevation: isWaSelected ? 4 : 1,
                                            ),
                                            onPressed: () => controller
                                                .handleContactWhatsAppVoiceTap(
                                                  contact,
                                                ),
                                            icon: const Icon(
                                              Icons.videocam_rounded,
                                              size: 20,
                                            ),
                                            label: Text(
                                              isWaSelected
                                                  ? 'Panggil VC'
                                                  : 'VC WA',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. Chat WhatsApp
                                    Expanded(
                                      flex: 3,
                                      child: Obx(() {
                                        final isChatSelected =
                                            controller
                                                .selectedContactActionKey
                                                .value ==
                                            'chat_${contact.id}';
                                        return Semantics(
                                          label:
                                              'Kirim pesan WhatsApp ke ${contact.name}.',
                                          hint: 'Aktifkan untuk membuka pesan',
                                          button: true,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF128C7E,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: isChatSelected
                                                    ? const BorderSide(
                                                        color: Colors.white,
                                                        width: 2.5,
                                                      )
                                                    : BorderSide.none,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              elevation: isChatSelected ? 4 : 1,
                                            ),
                                            onPressed: () => controller
                                                .handleContactChatTap(contact),
                                            icon: const Icon(
                                              Icons.chat_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              isChatSelected
                                                  ? 'Buka Chat'
                                                  : 'Chat',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, ContactsService service) {
    controller.speakAddContactHelp();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Keluarga');

    Get.defaultDialog(
      title: 'Tambah Kontak Keluarga / Tepercaya',
      titleStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlue,
      ),
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bantu pengguna dengan mengetikkan nama dan nomor WhatsApp atau telepon yang aktif.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'Kolom teks: Nama Lengkap Kontak. Ketik nama orang terdekat atau keluarga.',
              textField: true,
              child: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap Kontak',
                  hintText: 'Misal: Ibu Ani, Kak Budi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Kolom teks: Nomor Telepon atau WhatsApp. Masukkan nomor kontak aktif.',
              textField: true,
              child: TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon / WhatsApp',
                  hintText: 'Misal: 081234567890',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Kolom teks: Hubungan keluarga atau kerabat.',
              textField: true,
              child: TextField(
                controller: relCtrl,
                decoration: const InputDecoration(
                  labelText: 'Hubungan',
                  hintText: 'Misal: Keluarga, Wali, Teman',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.favorite_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
      textConfirm: 'Simpan Kontak',
      textCancel: 'Batal',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primaryBlue,
      onConfirm: () {
        if (nameCtrl.text.trim().isNotEmpty &&
            phoneCtrl.text.trim().isNotEmpty) {
          final newContact = TrustedContact(
            id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
            name: nameCtrl.text.trim(),
            phoneNumber: phoneCtrl.text.trim(),
            relationship: relCtrl.text.trim().isEmpty
                ? 'Keluarga'
                : relCtrl.text.trim(),
          );
          service.addContact(newContact);
          controller.ttsService.speak(
            'Kontak ${newContact.name} berhasil disimpan.',
            isUrgent: true,
          );
          Get.back();
        } else {
          controller.ttsService.speak(
            'Nama dan nomor telepon harus diisi.',
            isUrgent: true,
          );
        }
      },
    );
  }
}
