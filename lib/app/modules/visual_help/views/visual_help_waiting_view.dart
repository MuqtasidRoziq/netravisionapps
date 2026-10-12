import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../routes/app_pages.dart';
import '../../../services/contacts_service.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/visual_help_controller.dart';

class VisualHelpWaitingView extends GetView<VisualHelpController> {
  const VisualHelpWaitingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Mencari Relawan',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.primaryBlue),
          onPressed: () => controller.cancelRequest(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Obx(() {
            final secondsLeft = controller.remainingSeconds.value;
            final isExpired = secondsLeft == 0;
            final req = controller.visualHelpService.activeRequest.value;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Indikator Animasi / Ikon
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: isExpired ? AppColors.surface : AppColors.lightBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isExpired ? AppColors.textSecondary : AppColors.primaryBlue,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: isExpired
                        ? const Icon(Icons.timer_off_rounded, size: 54, color: AppColors.textSecondary)
                        : Text(
                            '$secondsLeft',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Teks Status
                Text(
                  isExpired ? 'Belum Ada Relawan Tersedia' : 'Menghubungkan ke Relawan Pilot...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isExpired ? AppColors.emergencyRed : AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                // Konfirmasi Privasi
                Text(
                  isExpired
                      ? 'Tidak ada relawan yang menjawab dalam 45 detik. Anda dapat mencoba lagi atau menghubungi kontak langsung via WhatsApp/Telepon.'
                      : 'Kamera belakang Anda BELUM dibagikan. Berbagi kamera baru akan aktif setelah relawan menerima permintaan.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Konteks Tugas yang Dikirim
                if (req != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lightBlueBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Konteks yang dibagikan:',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          req.taskContext.taskType.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (req.taskContext.targetName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Target: ${req.taskContext.targetName}',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                const Spacer(),

                // Tombol Aksi
                if (!isExpired)
                  Semantics(
                    label: 'Batalkan Permintaan Bantuan',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.emergencyRed, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => controller.cancelRequest(),
                        child: const Text(
                          'Batalkan Permintaan',
                          style: TextStyle(
                            color: AppColors.emergencyRed,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  // Opsi 1: Panggilan Cepat WhatsApp Kontak Tepercaya jika ada
                  Builder(
                    builder: (context) {
                      final contactsService = Get.isRegistered<ContactsService>()
                          ? Get.find<ContactsService>()
                          : null;
                      final primaryContact = contactsService?.contacts.firstOrNull;

                      if (primaryContact != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => controller.showCallOptionsModal(
                                phoneNumber: primaryContact.phoneNumber,
                                contactName: primaryContact.name,
                              ),
                              icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
                              label: Text(
                                'Telepon ${primaryContact.name} (WA / Seluler)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Opsi 2: Coba Minta Bantuan Lagi
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Get.back();
                        controller.submitHelpRequest();
                      },
                      child: const Text(
                        'Coba Minta Bantuan Lagi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Opsi 3: Buka Daftar Kontak Tepercaya
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Get.offNamed(Routes.TRUSTED_CONTACTS),
                      icon: const Icon(Icons.contacts_rounded, color: AppColors.primaryBlue),
                      label: const Text(
                        'Buka Semua Kontak Tepercaya',
                        style: TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            );
          }),
        ),
      ),
    );
  }
}
