import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../data/models/vision_mode.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/detector_controller.dart';
import 'widgets/navigation_map_embed.dart';

class DetectorView extends GetView<DetectorController> {
  const DetectorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Kamera + overlay deteksi native (bounding box & label).
            Semantics(
              label:
                  'Layar Kamera ${controller.mode.title} aktif. Ketuk sekali untuk mengulang info objek di hadapan Anda.',
              hint: 'Ketuk layar untuk mendengarkan objek terbaru',
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  controller.handleScreenTap();
                },
                onLongPress: () => controller.triggerEmergencySOS(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        YOLOView(
                          modelPath: controller.modelConfig.modelPath,
                          task: controller.modelConfig.task,
                          controller: controller.yoloController,
                          cameraResolution: '720p',
                          // Batasi inferensi native ke 5 fps: HP terasa ringan, tidak
                          // panas, dan pratinjau kamera tetap halus 30 fps tanpa lag.
                          streamingConfig: const YOLOStreamingConfig(
                            includeDetections: true,
                            includeClassifications: false,
                            includeProcessingTimeMs: false,
                            includeFps: false,
                            includeMasks: false,
                            includePoses: false,
                            includeOBB: false,
                            includeOriginalImage: false,
                            inferenceFrequency: 5,
                            throttleInterval: Duration(milliseconds: 200),
                            analysisResolution: Size(480, 480),
                          ),
                          useGpu: true,
                          confidenceThreshold:
                              controller.modelConfig.confidenceThreshold,
                          iouThreshold: controller.modelConfig.iouThreshold,
                          onResult: controller.handleResults,
                          onModelLoad: controller.handleModelLoad,
                          onModelError: controller.handleModelError,
                        ),

                        // Bounding box tervalidasi presisi untuk Mode Baca Uang
                        if (controller.mode == VisionMode.currency)
                          _buildCustomDetectionBox(constraints),

                        // Overlay status jeda (lokal Obx agar tidak me-reload kamera).
                        Obx(() {
                          if (!controller.isPaused.value) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            color: Colors.black.withValues(alpha: 0.6),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pause_circle_filled,
                                      size: 72, color: Colors.white),
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
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
            ),

            // 2. Header kontrol atas (tombol kembali, status mode, dan aksi).
            Positioned(
              top: 12,
              left: 14,
              right: 14,
              child: _buildTopBar(context),
            ),

            // 3. Banner status bawah (kontras tinggi putih-biru, reaktif mandiri).
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: _buildBottomStatusBar(),
            ),

            // 4. Peta navigasi — hanya Mode Jalan (di pojok kanan bawah).
            if (controller.mode == VisionMode.outdoor)
              Obx(
                () {
                  final isExpanded = controller.mapExpanded.value;
                  if (isExpanded) {
                    return Positioned(
                      left: 14,
                      right: 14,
                      top: 75,
                      bottom: 165,
                      child: NavigationMapEmbed(controller: controller),
                    );
                  } else {
                    return Positioned(
                      right: 14,
                      bottom: 165,
                      width: 145,
                      height: 145,
                      child: NavigationMapEmbed(controller: controller),
                    );
                  }
                },
              ),

            // 5. Overlay Darurat SOS (Tampil saat hitung mundur 5 detik)
            Obx(() {
              if (!controller.isSosCountdownActive.value) {
                return const SizedBox.shrink();
              }
              return Positioned.fill(
                child: Semantics(
                  label:
                      'Peringatan Darurat SOS Aktif. Menghubungi bantuan dalam ${controller.sosCountdownSeconds.value} detik. Ketuk layar sekali untuk membatalkan.',
                  button: true,
                  child: GestureDetector(
                    onTap: () => controller.cancelEmergencySOS(),
                    child: Container(
                      color: AppColors.emergencyRed.withValues(alpha: 0.95),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 30),
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${controller.sosCountdownSeconds.value}',
                                    style: const TextStyle(
                                      color: AppColors.emergencyRed,
                                      fontSize: 50,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                '🚨 PANGGILAN DARURAT',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Ketuk layar di mana saja untuk membatalkan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Header kontrol atas yang responsif untuk semua ukuran layar HP.
  /// Memisahkan tombol navigasi/aksi dengan badge mode agar tidak saling berebut lebar layar.
  Widget _buildTopBar(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Baris 1: Kontrol Navigasi & Aksi (Kembali, SOS, Jeda)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tombol Kembali
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
                    Get.back();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Kembali',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tombol Aksi Kanan: SOS + Jeda
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tombol Darurat SOS di Layar Kamera
                Semantics(
                  label: 'Panggilan Darurat SOS',
                  hint: 'Ketuk untuk memicu peringatan darurat lima detik',
                  button: true,
                  child: Material(
                    color: AppColors.emergencyRed,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 4,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        controller.triggerEmergencySOS();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Tombol Jeda / Lanjutkan Deteksi (lokal Obx)
                Obx(() => Semantics(
                  label: controller.isPaused.value ? 'Lanjutkan Deteksi' : 'Jeda Deteksi',
                  button: true,
                  child: Material(
                    color: controller.isPaused.value
                        ? AppColors.yellowAccent
                        : Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        controller.togglePause();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          controller.isPaused.value ? Icons.play_arrow : Icons.pause,
                          color: controller.isPaused.value ? Colors.black : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Baris 2: Badge Indikator Mode Kamera Aktif (Tengah & Responsif)
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white30, width: 1.2),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getModeIcon(controller.mode),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    controller.mode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getModeIcon(VisionMode mode) {
    switch (mode) {
      case VisionMode.indoor:
        return Icons.meeting_room_rounded;
      case VisionMode.outdoor:
        return Icons.explore_rounded;
      case VisionMode.currency:
        return Icons.payments_rounded;
      case VisionMode.itemSearch:
        return Icons.manage_search_rounded;
    }
  }

  Widget _buildBottomStatusBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Obx(() {
          final subtitle = controller.mode == VisionMode.currency
              ? 'Ketuk layar kapan saja untuk mengulang nominal uang'
              : controller.mode == VisionMode.outdoor
                  ? (controller.navStatus.value.isNotEmpty
                      ? controller.navStatus.value
                      : 'Ketuk mikrofon pada peta untuk menyebutkan tujuan')
                  : 'Ketuk layar kapan saja untuk cek rintangan';

          return Semantics(
            label: 'Status deteksi: ${controller.currentStatusText.value}',
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.currentStatusText.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        // Tombol Aksesibel Minta Bantuan Relawan
        Semantics(
          label: 'Minta Bantuan Relawan. Hubungi relawan untuk membantu memeriksa kamera.',
          button: true,
          child: Material(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(16),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => controller.requestVisualHelp(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Minta Bantuan Relawan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDetectionBox(BoxConstraints constraints) {
    return Obx(() {
      final box = controller.activeDetectionBox.value;
      if (box == null || box.isEmpty) return const SizedBox.shrink();

      final left = (box.left * constraints.maxWidth).clamp(0.0, constraints.maxWidth - 20);
      final top = (box.top * constraints.maxHeight).clamp(0.0, constraints.maxHeight - 20);
      final width = (box.width * constraints.maxWidth).clamp(20.0, constraints.maxWidth - left);
      final height = (box.height * constraints.maxHeight).clamp(20.0, constraints.maxHeight - top);

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.greenAccent, width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.greenAccent.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                '${controller.activeDetectionLabel.value} (Tervalidasi)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
