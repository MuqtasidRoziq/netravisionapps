import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/visual_help_models.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryBlue),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Kontak',
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryBlue),
            onPressed: () => _showAddContactDialog(context, contactsService),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Banner Panduan Pengisian oleh Orang Terdekat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volunteer_activism_rounded, color: AppColors.primaryBlue, size: 22),
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
                        child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primaryBlue, size: 38),
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _showAddContactDialog(context, contactsService),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          label: const Text(
                            'Minta Orang Terdekat Isi Nomor',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: list.map((contact) {
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => controller.showCallOptionsModal(
                        phoneNumber: contact.phoneNumber,
                        contactName: contact.name,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                IconButton(
                                  tooltip: 'Hapus kontak',
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                                  onPressed: () => contactsService.deleteContact(contact.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 3 Tombol Aksi Langsung: Telepon WA, Seluler, Chat
                            Row(
                              children: [
                                // 1. Telepon WhatsApp
                                Expanded(
                                  flex: 4,
                                  child: Semantics(
                                    label: 'Panggil ${contact.name} via Telepon WhatsApp',
                                    button: true,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF25D366),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 1,
                                      ),
                                      onPressed: () => controller.callContactWhatsAppVoice(
                                        contact.phoneNumber,
                                        contactName: contact.name,
                                      ),
                                      icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                                      label: const Text('Telepon WA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 2. Telepon Seluler (Pulsa Biasa)
                                Expanded(
                                  flex: 3,
                                  child: Semantics(
                                    label: 'Panggil ${contact.name} via Telepon Seluler',
                                    button: true,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryBlue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 1,
                                      ),
                                      onPressed: () => controller.callContactPhone(
                                        contact.phoneNumber,
                                        contactName: contact.name,
                                      ),
                                      icon: const Icon(Icons.phone_rounded, size: 18),
                                      label: const Text('Seluler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // 3. Chat WhatsApp
                                Expanded(
                                  flex: 3,
                                  child: Semantics(
                                    label: 'Kirim pesan WhatsApp ke ${contact.name}',
                                    button: true,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF128C7E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        elevation: 1,
                                      ),
                                      onPressed: () => controller.callContactWhatsApp(
                                        contact.phoneNumber,
                                        contactName: contact.name,
                                      ),
                                      icon: const Icon(Icons.chat_rounded, size: 18),
                                      label: const Text('Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
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
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 18),
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
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap Kontak',
                hintText: 'Misal: Ibu Ani, Kak Budi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon / WhatsApp',
                hintText: 'Misal: 081234567890',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relCtrl,
              decoration: const InputDecoration(
                labelText: 'Hubungan',
                hintText: 'Misal: Keluarga, Wali, Teman',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite_rounded),
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
        if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
          final newContact = TrustedContact(
            id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
            name: nameCtrl.text.trim(),
            phoneNumber: phoneCtrl.text.trim(),
            relationship: relCtrl.text.trim().isEmpty ? 'Keluarga' : relCtrl.text.trim(),
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
