import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/visual_help_controller.dart';

class VisualHelpHomeView extends GetView<VisualHelpController> {
  const VisualHelpHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 70,
        leading: Semantics(
          label: 'Kembali ke Menu Utama',
          hint: 'Ketuk untuk kembali',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryBlue),
            onPressed: () => Get.back(),
          ),
        ),
        title: const Text(
          'Bantuan Visual',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Tombol Beralih Peran (Tunanetra <-> Relawan)
          Obx(() {
            final isCompanion = controller.visualHelpService.currentRole.value == 'companion';
            return TextButton.icon(
              onPressed: () => _showRoleDialog(context),
              icon: Icon(
                isCompanion ? Icons.volunteer_activism_rounded : Icons.person_rounded,
                size: 20,
                color: AppColors.primaryBlue,
              ),
              label: Text(
                isCompanion ? 'Relawan' : 'Pengguna',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final isCompanion = controller.visualHelpService.currentRole.value == 'companion';
          return isCompanion ? _buildCompanionDashboard() : _buildUserView(context);
        }),
      ),
    );
  }

  // ====================== TAMPILAN PENGGUNA TUNANETRA ======================

  Widget _buildUserView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Banner Penjelasan Aksesibel
        Semantics(
          label: 'Fitur Bantuan Visual menghubungkan Anda dengan pendamping relawan melalui kamera dan percakapan dua arah.',
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Relawan akan membantu melihat benda atau tulisan di hadapan Anda secara langsung.',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Pilih Konteks Tugas
        const Text(
          'Pilih Kebutuhan Bantuan:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        Obx(() => Column(
          children: TaskType.values.map((type) {
            final isSelected = controller.selectedTaskType.value == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                label: '${type.label}. ${isSelected ? "Dipilih" : "Ketuk untuk memilih"}',
                button: true,
                child: Material(
                  color: isSelected ? AppColors.primaryBlue : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  elevation: isSelected ? 3 : 1,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => controller.selectedTaskType.value = type,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryBlue : AppColors.lightBlueBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _iconForTask(type),
                            color: isSelected ? Colors.white : AppColors.primaryBlue,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              type.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        )),
        const SizedBox(height: 12),

        // Input Target Spesifik (Opsional)
        Semantics(
          label: 'Input nama target atau benda yang dicari, opsional',
          child: TextField(
            controller: controller.targetNameController,
            decoration: InputDecoration(
              labelText: 'Nama Target (contoh: Dompet, Obat, Kunci)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.lightBlueBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.lightBlueBorder),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Pilihan Penerima (Komunitas vs Kontak Tepercaya)
        const Text(
          'Pilihan Penerima:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Obx(() => Row(
          children: [
            Expanded(
              child: _buildRecipientCard(
                label: 'Komunitas Pilot',
                icon: Icons.groups_rounded,
                isSelected: controller.recipientTarget.value == RecipientTarget.communityVolunteers,
                onTap: () => controller.recipientTarget.value = RecipientTarget.communityVolunteers,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildRecipientCard(
                label: 'Kontak Tepercaya',
                icon: Icons.star_rounded,
                isSelected: controller.recipientTarget.value == RecipientTarget.trustedContacts,
                onTap: () => controller.recipientTarget.value = RecipientTarget.trustedContacts,
              ),
            ),
          ],
        )),
        const SizedBox(height: 24),

        // TOMBOL UTAMA: Minta Bantuan Visual
        Semantics(
          label: 'Minta Bantuan Visual Sekarang',
          hint: 'Ketuk dua kali untuk mengirim permintaan ke relawan',
          button: true,
          child: Material(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => controller.submitHelpRequest(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Minta Bantuan Visual',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // TOMBOL SEKUNDER: Kontak Tepercaya / Fallback Langsung
        Semantics(
          label: 'Kelola Kontak Tepercaya dan Panggilan Langsung',
          hint: 'Ketuk untuk membuka daftar telepon dan WhatsApp darurat',
          button: true,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
            ),
            onPressed: () => Get.toNamed(Routes.TRUSTED_CONTACTS),
            icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.primaryBlue),
            label: const Text(
              'Kontak Tepercaya / Fallback WhatsApp',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? AppColors.lightBlue : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.lightBlueBorder,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== TAMPILAN PENDAMPING RELAWAN ======================

  Widget _buildCompanionDashboard() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Status Ketersediaan Switch
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Relawan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Pilih untuk menerima notifikasi',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Obx(() => Switch(
                value: controller.visualHelpService.isCompanionAvailable.value,
                activeThumbColor: AppColors.primaryBlue,
                onChanged: (val) => controller.visualHelpService.toggleCompanionAvailability(val),
              )),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Panduan Singkat Relawan
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightBlueBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panduan Pendamping:',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• Deskripsikan gambar secara spesifik dan tenang.\n'
                '• Tanyakan kebutuhan yang ingin diperiksa pengguna.\n'
                '• Bila gambar buram, minta pengguna memiringkan atau mendekatkan kamera perlahan.\n'
                '• Jangan menebak jika tulisan tidak terbaca.',
                style: TextStyle(color: AppColors.primaryBlue, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Permintaan Bantuan Masuk:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // Daftar Permintaan Masuk
        Obx(() {
          final requests = controller.visualHelpService.incomingRequests;
          if (requests.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 8),
                  Text(
                    'Belum ada permintaan bantuan saat ini.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: requests.map((req) {
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconForTask(req.taskContext.taskType), color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.taskContext.taskType.label,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (req.taskContext.targetName != null)
                                  Text(
                                    'Target: ${req.taskContext.targetName}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => controller.acceptHelpRequest(req.id),
                              child: const Text('Terima Bantuan', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  IconData _iconForTask(TaskType type) {
    switch (type) {
      case TaskType.findObject:
        return Icons.search_rounded;
      case TaskType.readLabel:
        return Icons.text_snippet_rounded;
      case TaskType.deviceDisplay:
        return Icons.devices_rounded;
      case TaskType.generalHelp:
        return Icons.visibility_rounded;
    }
  }

  void _showRoleDialog(BuildContext context) {
    Get.defaultDialog(
      title: 'Pilih Peran Aplikasi',
      content: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_rounded, color: AppColors.primaryBlue),
            title: const Text('Pengguna Tunanetra'),
            subtitle: const Text('Meminta bantuan visual'),
            onTap: () {
              controller.visualHelpService.switchRole('user');
              Get.back();
            },
          ),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_rounded, color: AppColors.primaryBlue),
            title: const Text('Pendamping / Relawan'),
            subtitle: const Text('Menerima panggilan bantuan'),
            onTap: () {
              controller.visualHelpService.switchRole('companion');
              Get.back();
            },
          ),
        ],
      ),
    );
  }
}
