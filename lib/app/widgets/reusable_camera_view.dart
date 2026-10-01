import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../services/camera_service.dart';
import '../utils/constants/app_colors.dart';

/// Komponen Kamera Universal (Reusable Camera Component)
/// Digunakan oleh semua fitur: Mode Indoor, Mode Outdoor, dan Mode Baca Uang.
class ReusableCameraView extends StatelessWidget {
  final String title;
  final String statusText;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onTapScreen;
  final VoidCallback? onTogglePause;
  final bool isPaused;
  final Widget? overlayContent;

  const ReusableCameraView({
    super.key,
    required this.title,
    required this.statusText,
    this.subtitle,
    this.onBack,
    this.onTapScreen,
    this.onTogglePause,
    this.isPaused = false,
    this.overlayContent,
  });

  @override
  Widget build(BuildContext context) {
    final cameraService = Get.find<CameraService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Kamera Preview / Layar Sentuh Utama
            Obx(() {
              if (cameraService.errorMessage.isNotEmpty) {
                return _buildErrorState(cameraService);
              }

              if (!cameraService.isInitialized.value ||
                  cameraService.controller == null) {
                return _buildLoadingState();
              }

              return Semantics(
                label: 'Layar Kamera $title aktif. Ketuk sekali untuk mengulang info objek di hadapan Anda.',
                hint: 'Ketuk layar untuk mendengarkan objek terbaru',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTapScreen?.call();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Camera Preview Aspect Ratio
                      Center(
                        child: CameraPreview(cameraService.controller!),
                      ),

                      // Overlay Custom (Bounding Box / Sensor)
                      ?overlayContent,

                      // Status Pause Overlay
                      if (isPaused)
                        Container(
                          color: Colors.black.withOpacity(0.6),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pause_circle_filled, size: 72, color: Colors.white),
                                SizedBox(height: 12),
                                Text(
                                  'Deteksi Dijeda',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),

            // 2. Header Kontrol Atas (Tombol Kembali & Pause)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _buildTopBar(context),
            ),

            // 3. Status Bar Audio / Teks di Bawah (Kontras Tinggi Putih-Biru)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _buildBottomStatusBar(),
            ),
          ],
        ),
      ),
    );
  }

  /// Header Bar dengan Tombol Back Berukuran Besar (Ramah Aksesibilitas)
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tombol Kembali Besar
        Semantics(
          label: 'Kembali ke Menu Utama',
          hint: 'Ketuk untuk menutup kamera dan kembali',
          button: true,
          child: Material(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(16),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.mediumImpact();
                if (onBack != null) {
                  onBack!();
                } else {
                  Get.back();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Kembali',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Judul Mode
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30, width: 1.5),
          ),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Tombol Pause / Lanjutkan
        if (onTogglePause != null)
          Semantics(
            label: isPaused ? 'Lanjutkan Deteksi' : 'Jeda Deteksi',
            button: true,
            child: Material(
              color: isPaused ? AppColors.yellowAccent : Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTogglePause?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: isPaused ? Colors.black : Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Banner Status Bawah (Kombinasi Putih-Biru Kontras Tinggi)
  Widget _buildBottomStatusBar() {
    return Semantics(
      label: 'Status deteksi: $statusText',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryBlue, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.volume_up,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? 'Ketuk layar kapan saja untuk mengulang suara',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
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

  /// Tampilan Loading Kamera
  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              strokeWidth: 4,
            ),
            SizedBox(height: 20),
            Text(
              'Menghubungkan Kamera...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan Error Kamera
  Widget _buildErrorState(CameraService cameraService) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: AppColors.emergencyRed),
            const SizedBox(height: 16),
            Text(
              cameraService.errorMessage.value,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => cameraService.initializeCamera(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Sambungkan Lagi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
