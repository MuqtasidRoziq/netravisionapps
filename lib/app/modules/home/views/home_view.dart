import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/vision_mode.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 80,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo_no_bg.png',
                width: 36,
                height: 36,
              ),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NetraVision',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Asisten Mobilitas Mandiri',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Tombol Bantuan / Panduan Suara
          Semantics(
            label: 'Dengarkan panduan suara aplikasi',
            hint: 'Ketuk dua kali untuk mendengarkan panduan audio',
            button: true,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                iconSize: 32,
                tooltip: 'Panduan Suara',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.lightBlue,
                  foregroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.lightBlueBorder, width: 1.5),
                  ),
                ),
                onPressed: () => controller.playGuide(),
                icon: const Icon(Icons.volume_up_rounded),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Status Info Banner
            Semantics(
              label: 'Kamera dan suara siap digunakan.',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryBlue,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pilih salah satu menu di bawah untuk mulai memindai.',
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

            // Card 1: Mode Indoor
            _buildMenuCard(
              index: '1',
              title: '1. Mode Indoor',
              subtitle: 'Deteksi rintangan, perabotan & pintu',
              icon: Icons.meeting_room_rounded,
              onTap: () => controller.openMode(VisionMode.indoor),
              accessibilityHint: 'Ketuk dua kali untuk membuka kamera deteksi perabotan dalam ruangan',
            ),
            const SizedBox(height: 16),

            // Card 2: Mode Outdoor
            _buildMenuCard(
              index: '2',
              title: '2. Mode Outdoor',
              subtitle: 'Navigasi jalan raya, trotoar & bahaya',
              icon: Icons.explore_rounded,
              onTap: () => controller.openMode(VisionMode.outdoor),
              accessibilityHint: 'Ketuk dua kali untuk membuka kamera navigasi jalan luar ruangan',
            ),
            const SizedBox(height: 16),

            // Card 3: Mode Baca Uang
            _buildMenuCard(
              index: '3',
              title: '3. Mode Baca Uang',
              subtitle: 'Pindai nominal uang kertas rupiah',
              icon: Icons.payments_rounded,
              onTap: () => controller.openMode(VisionMode.currency),
              accessibilityHint: 'Ketuk dua kali untuk membuka kamera pembaca uang rupiah',
            ),
            const SizedBox(height: 16),

            // Card 4: Bantuan Relawan (SOS)
            _buildSosCard(
              index: '4',
              title: '4. Bantuan Relawan / SOS',
              subtitle: 'Hubungi relawan pendamping darurat',
              icon: Icons.phone_in_talk_rounded,
              onTap: () => controller.triggerSos(),
              accessibilityHint: 'Ketuk dua kali untuk melakukan panggilan darurat ke relawan',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Komponen Kartu Menu Standar (Desain Putih-Biru Kontras Tinggi)
  Widget _buildMenuCard({
    required String index,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required String accessibilityHint,
  }) {
    return Semantics(
      label: '$title. $subtitle.',
      hint: accessibilityHint,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        elevation: 2,
        shadowColor: AppColors.cardShadow,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          splashColor: AppColors.lightBlue,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.lightBlueBorder.withOpacity(0.6), width: 1.5),
            ),
            child: Row(
              children: [
                // Kotak Ikon Biru
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primaryBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // Teks Judul & Deskripsi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Panah Navigasi
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Komponen Kartu Bantuan Darurat / SOS (Merah Aksen Kontras Tinggi)
  Widget _buildSosCard({
    required String index,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required String accessibilityHint,
  }) {
    return Semantics(
      label: '$title. $subtitle. Panggilan darurat.',
      hint: accessibilityHint,
      button: true,
      child: Material(
        color: AppColors.emergencyRed,
        borderRadius: BorderRadius.circular(22),
        elevation: 4,
        shadowColor: AppColors.emergencyRed.withOpacity(0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          splashColor: Colors.white24,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24, width: 1.5),
            ),
            child: Row(
              children: [
                // Kotak Ikon SOS
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // Teks Judul & Deskripsi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Panggil
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.call,
                    color: AppColors.emergencyRed,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}