import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../routes/app_pages.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/visual_help_controller.dart';

/// Tampilan Menu Bantuan Visual Ramah Tunanetra (Zero Friction 2-Button Hero).
///
/// Dirancang khusus untuk tunanetra:
/// - Tanpa formulir atau dropdown yang membingungkan.
/// - 2 Tombol raksasa kontras tinggi memenuhi layar (Panggil Relawan & Kontak Keluarga).
/// - Mendukung gestur ketuk 2x di mana saja di layar untuk langsung memanggil bantuan.
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
        toolbarHeight: 64,
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
          'Bantuan Relawan',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Tombol Beralih Peran (Opsional / Admin / Relawan)
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
          return isCompanion ? _buildCompanionDashboard() : _buildSimplifiedUserView(context);
        }),
      ),
    );
  }

  // ====================== TAMPILAN PENGGUNA TUNANETRA ULTRA-SIMPLE ======================

  Widget _buildSimplifiedUserView(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () {
        HapticFeedback.heavyImpact();
        controller.recipientTarget.value = RecipientTarget.communityVolunteers;
        controller.submitHelpRequest();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // 1. KARTU RAKSASA HERO (62% Layar): Panggil Relawan Sekarang
            Expanded(
              flex: 6,
              child: Semantics(
                label: 'Tombol Utama: Panggil Relawan. Menghubungi relawan terdekat melalui siaran kamera dan suara. Kamera baru akan aktif setelah relawan menjawab.',
                hint: 'Ketuk dua kali di mana saja untuk langsung memanggil relawan sekarang.',
                button: true,
                child: Material(
                  color: AppColors.primaryBlue,
                  borderRadius: BorderRadius.circular(28),
                  elevation: 4,
                  shadowColor: AppColors.primaryBlue.withValues(alpha: 0.35),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      controller.recipientTarget.value = RecipientTarget.communityVolunteers;
                      controller.submitHelpRequest();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'PANGGIL RELAWAN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Hubungi relawan terdekat sekarang.\nKamera dan suara otomatis terhubung.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 2. KARTU HERO KEDUA (38% Layar): Kontak Keluarga / Tepercaya
            Expanded(
              flex: 4,
              child: Semantics(
                label: 'Tombol Kedua: Kontak Keluarga Tepercaya. Hubungi keluarga via WhatsApp atau telepon darurat. Minta orang terdekat untuk mengisi nomor bila belum ada.',
                hint: 'Ketuk dua kali untuk membuka kontak keluarga.',
                button: true,
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  elevation: 2,
                  shadowColor: AppColors.cardShadow,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      controller.speakTrustedContactsIntro();
                      Get.toNamed(Routes.TRUSTED_CONTACTS);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.lightBlueBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: AppColors.lightBlue,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.family_restroom_rounded,
                              color: AppColors.primaryBlue,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kontak Keluarga',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Panggilan langsung WhatsApp / telepon.\nMinta orang terdekat mengisi nomor.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.primaryBlue,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Info Privasi Ringkas & Bersih
            Semantics(
              label: 'Privasi Terjamin: Kamera belakang hanya aktif setelah relawan menjawab panggilan.',
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded, size: 16, color: AppColors.primaryBlue),
                  SizedBox(width: 6),
                  Text(
                    'Privasi Terjaga: Kamera aktif setelah panggilan dijawab',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                activeColor: AppColors.primaryBlue,
                onChanged: (val) => controller.visualHelpService.toggleCompanionAvailability(val),
              )),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Info Portal Web untuk Relawan
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Portal Web Relawan NetraVision',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Relawan disarankan mendampingi melalui portal laptop di netravision-portal.vercel.app untuk layar yang lebih luas dan kontrol suara instan.',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Beralih Peran'),
        content: const Text(
          'Pilih peran Anda saat ini:\n\n'
          'â€¢ Pengguna: Tunanetra yang membutuhkan panduan visual.\n'
          'â€¢ Relawan: Pendamping yang siap membantu melihat layar/kamera.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.visualHelpService.switchRole('user');
              Get.back();
            },
            child: const Text('Sebagai Pengguna'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              controller.visualHelpService.switchRole('companion');
              Get.back();
            },
            child: const Text('Sebagai Relawan'),
          ),
        ],
      ),
    );
  }
}
