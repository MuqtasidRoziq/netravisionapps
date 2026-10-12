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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Kontak Tepercaya & Cadangan',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            // Banner Penjelasan Fallback
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
                      'Kontak tepercaya dapat dihubungi langsung via Telepon seluler atau WhatsApp jika relawan online tidak tersedia.',
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
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
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
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                                onPressed: () => contactsService.deleteContact(contact.id),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Tombol Cepat: Telepon & WhatsApp
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => controller.callContactPhone(contact.phoneNumber),
                                  icon: const Icon(Icons.phone_rounded, size: 18),
                                  label: const Text('Telepon', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () => controller.callContactWhatsApp(contact.phoneNumber),
                                  icon: const Icon(Icons.chat_rounded, size: 18),
                                  label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
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
