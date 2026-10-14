import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NetraVision',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Asisten Mobilitas Mandiri',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
        child: Obx(() {
          final isSosActive = controller.isSosCountdownActive.value;
          final countdown = controller.sosCountdownSeconds.value;

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (isSosActive) controller.cancelEmergencySOS();
                },
                onHorizontalDragEnd: (details) {
                  if (isSosActive) return;
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -150) {
                      controller.nextMenu();
                    } else if (details.primaryVelocity! > 150) {
                      controller.previousMenu();
                    }
                  }
                },
                onLongPress: () => controller.triggerEmergencySOS(),
                child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Card 1: Mode Indoor
            Obx(() => _buildMenuCard(
              index: 0,
              numberLabel: '1',
              title: 'Mode Dalam Ruangan',
              subtitle: 'Deteksi rintangan, perabotan & pintu',
              icon: Icons.meeting_room_rounded,
              isSelected: controller.selectedMenuIndex.value == 0,
              onTap: () => controller.handleMenuTap(0),
              accessibilityHint: controller.selectedMenuIndex.value == 0
                  ? 'Ketuk dua kali untuk masuk ke kamera deteksi dalam ruangan'
                  : 'Ketuk dua kali untuk mendengarkan penjelasan fitur dan memilih',
            )),
            const SizedBox(height: 16),

            // Card 2: Mode Outdoor
            Obx(() => _buildMenuCard(
              index: 1,
              numberLabel: '2',
              title: 'Mode Jalan',
              subtitle: 'Navigasi jalan raya, trotoar & bahaya',
              icon: Icons.explore_rounded,
              isSelected: controller.selectedMenuIndex.value == 1,
              onTap: () => controller.handleMenuTap(1),
              accessibilityHint: controller.selectedMenuIndex.value == 1
                  ? 'Ketuk dua kali untuk masuk ke kamera navigasi luar ruangan'
                  : 'Ketuk dua kali untuk mendengarkan penjelasan fitur dan memilih',
            )),
            const SizedBox(height: 16),

            // Card 3: Mode Baca Uang
            Obx(() => _buildMenuCard(
              index: 2,
              numberLabel: '3',
              title: 'Mode Baca Uang',
              subtitle: 'Pindai nominal uang kertas rupiah',
              icon: Icons.payments_rounded,
              isSelected: controller.selectedMenuIndex.value == 2,
              onTap: () => controller.handleMenuTap(2),
              accessibilityHint: controller.selectedMenuIndex.value == 2
                  ? 'Ketuk dua kali untuk masuk ke kamera pembaca uang rupiah'
                  : 'Ketuk dua kali untuk mendengarkan penjelasan fitur dan memilih',
            )),
            const SizedBox(height: 16),

            // Card 4: Cari Barang (Voice Search)
            Obx(() => _buildMenuCard(
              index: 3,
              numberLabel: '4',
              title: 'Cari Barang',
              subtitle: 'Ucapkan nama barang untuk mendeteksinya',
              icon: Icons.manage_search_rounded,
              isSelected: controller.selectedMenuIndex.value == 3,
              onTap: () => controller.handleMenuTap(3),
              accessibilityHint: controller.selectedMenuIndex.value == 3
                  ? 'Ketuk dua kali untuk masuk ke pencarian barang dengan suara'
                  : 'Ketuk dua kali untuk mendengarkan penjelasan fitur dan memilih',
            )),
            const SizedBox(height: 16),

            // Card 5: Bantuan Visual
            Obx(() => _buildVisualHelpCard(
              index: 4,
              numberLabel: '5',
              title: 'Panggil Relawan',
              subtitle: 'Panggilan langsung ke pendamping manusia',
              icon: Icons.volunteer_activism_rounded,
              isSelected: controller.selectedMenuIndex.value == 4,
              onTap: () => controller.handleMenuTap(4),
              accessibilityHint: controller.selectedMenuIndex.value == 4
                  ? 'Ketuk dua kali untuk memanggil pendamping manusia'
                  : 'Ketuk dua kali untuk mendengarkan penjelasan fitur dan memilih',
            )),
            const SizedBox(height: 24),
          ],
        ),
              ),

              // Overlay Darurat SOS (Tampil saat hitung mundur 5 detik)
              if (isSosActive)
                Positioned.fill(
                  child: Semantics(
                    label: 'Peringatan Darurat SOS Aktif. Menghubungi bantuan dalam $countdown detik. Ketuk layar sekali untuk membatalkan.',
                    button: true,
                    child: GestureDetector(
                      onTap: () => controller.cancelEmergencySOS(),
                      child: Container(
                        color: AppColors.emergencyRed.withValues(alpha: 0.95),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$countdown',
                                      style: const TextStyle(
                                        color: AppColors.emergencyRed,
                                        fontSize: 54,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  '🚨 PANGGILAN DARURAT',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Menghubungi relawan siaga secara otomatis...\n\nKetuk di mana saja di layar untuk MEMBATALKAN.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 36),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.emergencyRed,
                                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () => controller.cancelEmergencySOS(),
                                  icon: const Icon(Icons.cancel_rounded, size: 24),
                                  label: const Text(
                                    'Batalkan Panggilan',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  /// Komponen Kartu Menu Standar (Desain Putih-Biru Kontras Tinggi dengan Dukungan 2 Ketukan)
  Widget _buildMenuCard({
    required int index,
    required String numberLabel,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String accessibilityHint,
  }) {
    return Semantics(
      label: '$title. $subtitle. ${isSelected ? "Sedang dipilih. Ketuk dua kali untuk masuk." : "Ketuk dua kali untuk mendengarkan penjelasan fitur."}',
      hint: accessibilityHint,
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.lightBlue.withValues(alpha: 0.45) : AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        elevation: isSelected ? 4 : 2,
        shadowColor: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.25) : AppColors.cardShadow,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          splashColor: AppColors.lightBlue,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? AppColors.primaryBlue : AppColors.lightBlueBorder.withValues(alpha: 0.6),
                width: isSelected ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              children: [
                // Kotak Ikon Biru
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryBlue : AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryBlue : AppColors.lightBlueBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : AppColors.primaryBlue,
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
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: AppColors.primaryBlue, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Ketuk sekali lagi untuk masuk',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Panah Navigasi / Status
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryBlue : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                    color: isSelected ? Colors.white : AppColors.primaryBlue,
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

  /// Komponen Kartu Bantuan Visual (Aksen Biru Kontras Tinggi dengan Dukungan 2 Ketukan)
  Widget _buildVisualHelpCard({
    required int index,
    required String numberLabel,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String accessibilityHint,
  }) {
    return Semantics(
      label: '$title. $subtitle. ${isSelected ? "Sedang dipilih. Ketuk dua kali untuk memanggil." : "Ketuk dua kali untuk mendengarkan penjelasan fitur."}',
      hint: accessibilityHint,
      button: true,
      selected: isSelected,
      child: Material(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(22),
        elevation: isSelected ? 6 : 4,
        shadowColor: AppColors.primaryBlue.withValues(alpha: 0.4),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          splashColor: Colors.white24,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 3.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                // Kotak Ikon Bantuan Visual
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
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
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Ketuk sekali lagi untuk memanggil',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Tombol Panah / Cek
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
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
}