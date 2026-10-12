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
        // 1. TOMBOL UTAMA BESAR: Satu Ketukan Ramah Aksesibilitas TalkBack
        Semantics(
          label: 'Minta Bantuan Visual. Mengirim permintaan kepada kontak tepercaya atau relawan. Kamera dan mikrofon belum dibagikan.',
          hint: 'Ketuk dua kali untuk mengirim permintaan ke pendamping sekarang',
          button: true,
          child: Material(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(22),
            elevation: 4,
            shadowColor: AppColors.primaryBlue.withValues(alpha: 0.35),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => controller.submitHelpRequest(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minta Bantuan Visual',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hubungi pendamping via kamera & suara',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Banner Privasi Aksesibel
        Semantics(
          label: 'Privasi Terlindungi: Kamera belakang dan mikrofon baru akan aktif setelah pendamping menerima permintaan Anda.',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: AppColors.primaryBlue, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Privasi Terjaga: Kamera belakang dan mikrofon baru akan aktif setelah pendamping menerima permintaan Anda.',
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
        ),
        const SizedBox(height: 20),

        // 3. Pilihan Penerima Bantuan
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
        const SizedBox(height: 20),

        // 4. Pilih Konteks Tugas (Opsional, Default General Help)
        const Text(
          'Kebutuhan Bantuan (Opsional):',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        Obx(() => Column(
          children: TaskType.values.map((type) {
            final isSelected = controller.selectedTaskType.value == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                label: '${type.label}. ${isSelected ? "Dipilih" : "Ketuk untuk memilih"}',
                button: true,
                child: Material(
                  color: isSelected ? AppColors.surface : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => controller.selectedTaskType.value = type,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryBlue : AppColors.lightBlueBorder.withValues(alpha: 0.5),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _iconForTask(type),
                            color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              type.label,
                              style: TextStyle(
                                color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        )),
        const SizedBox(height: 16),

        // 5. TOMBOL SEKUNDER: Kontak Tepercaya / Fallback Panggilan Langsung
        Semantics(
          label: 'Kelola Kontak Tepercaya dan Panggilan Langsung',
          hint: 'Ketuk untuk membuka daftar nomor telepon dan WhatsApp darurat',
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
              'Kontak Tepercaya / Fallback Panggilan',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 15,
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
        const SizedBox(height: 20),

        // Daftar Panggilan Masuk
        const Text(
          'Permintaan Masuk:',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        Obx(() {
          final requests = controller.visualHelpService.incomingRequests;
          if (requests.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.lightBlueBorder.withValues(alpha: 0.5)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada panggilan masuk',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Notifikasi akan muncul saat ada pengguna yang butuh bantuan.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: requests.map((req) => _buildIncomingRequestCard(req)).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildIncomingRequestCard(VisualHelpRequestModel req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryBlue, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                req.userName,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  req.taskContext.taskType.label,
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (req.taskContext.targetName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Target: ${req.taskContext.targetName}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
          if (req.taskContext.unverifiedAiLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              'AI Deteksi: ${req.taskContext.unverifiedAiLabel}',
              style: const TextStyle(color: AppColors.emergencyRed, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => controller.acceptHelpRequest(req.id),
              icon: const Icon(Icons.call_rounded),
              label: const Text(
                'Terima Panggilan Bantuan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForTask(TaskType type) {
    switch (type) {
      case TaskType.findObject:
        return Icons.search_rounded;
      case TaskType.readLabel:
        return Icons.description_rounded;
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
