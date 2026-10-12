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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kontak Tepercaya & Panggilan Langsung'),
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
            // Banner Penjelasan Fallback & Aksesibilitas
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.lightBlueBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pilih "Telepon WA" untuk panggilan suara WhatsApp langsung, "Seluler" untuk telepon pulsa biasa, atau "Chat" untuk mengirim pesan.',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Belum ada kontak tepercaya tersimpan.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
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
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: 'Keluarga');

    Get.defaultDialog(
      title: 'Tambah Kontak Tepercaya',
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor Telepon / WhatsApp'),
            ),
            TextField(
              controller: relCtrl,
              decoration: const InputDecoration(labelText: 'Hubungan (contoh: Wali, Sahabat)'),
            ),
          ],
        ),
      ),
      textConfirm: 'Simpan',
      textCancel: 'Batal',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primaryBlue,
      onConfirm: () {
        if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
          service.addContact(
            TrustedContact(
              id: 'contact_${DateTime.now().millisecondsSinceEpoch}',
              name: nameCtrl.text.trim(),
              phoneNumber: phoneCtrl.text.trim(),
              relationship: relCtrl.text.trim(),
            ),
          );
          Get.back();
        }
      },
    );
  }
}
