import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
          children: [
            // 1. KARTU RAKSASA HERO (62% Layar): Panggil Relawan Sekarang
            Expanded(
              flex: 6,
              child: Obx(() {
                final isSelected = controller.selectedButtonIndex.value == 0;
                return Semantics(
                  label: 'Tombol Utama: Panggil Relawan. Menghubungi relawan terdekat melalui siaran kamera dan suara. ${isSelected ? "Sedang dipilih. Ketuk dua kali untuk memanggil." : "Ketuk dua kali untuk mendengarkan penjelasan dan memanggil."}',
                  hint: isSelected ? 'Ketuk dua kali untuk langsung memanggil relawan' : 'Ketuk dua kali untuk mendengarkan penjelasan fitur',
                  button: true,
                  selected: isSelected,
                  child: Material(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(28),
                    elevation: isSelected ? 6 : 4,
                    shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => controller.handleVolunteerButtonTap(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: isSelected ? 3.5 : 0,
                          ),
                        ),
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
                            if (isSelected) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app_rounded, color: AppColors.primaryBlue, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Ketuk sekali lagi untuk memanggil',
                                      style: TextStyle(
                                        color: AppColors.primaryBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // 2. KARTU HERO KEDUA (38% Layar): Kontak Keluarga / Tepercaya
            Expanded(
              flex: 4,
              child: Obx(() {
                final isSelected = controller.selectedButtonIndex.value == 1;
                return Semantics(
                  label: 'Tombol Kedua: Kontak Keluarga Tepercaya. Hubungi keluarga via WhatsApp atau telepon darurat. ${isSelected ? "Sedang dipilih. Ketuk dua kali untuk membuka." : "Ketuk dua kali untuk mendengarkan penjelasan dan membuka."}',
                  hint: isSelected ? 'Ketuk dua kali untuk membuka daftar kontak keluarga' : 'Ketuk dua kali untuk mendengarkan penjelasan fitur',
                  button: true,
                  selected: isSelected,
                  child: Material(
                    color: isSelected ? AppColors.lightBlue.withValues(alpha: 0.45) : AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    elevation: isSelected ? 4 : 2,
                    shadowColor: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.25) : AppColors.cardShadow,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => controller.handleContactsButtonTap(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : AppColors.lightBlueBorder,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryBlue : AppColors.lightBlue,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.family_restroom_rounded,
                                color: isSelected ? Colors.white : AppColors.primaryBlue,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kontak Keluarga',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isSelected
                                        ? 'Ketuk sekali lagi untuk membuka'
                                        : 'Panggilan langsung WhatsApp / telepon.\nMinta orang terdekat mengisi nomor.',
                                    style: TextStyle(
                                      color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                              color: AppColors.primaryBlue,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
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
