import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../../data/models/vision_mode.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/detector_controller.dart';

class DetectorView extends GetView<DetectorController> {
  const DetectorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final subtitle = controller.mode == VisionMode.currency
          ? 'Ketuk layar kapan saja untuk mengulang nominal uang'
          : 'Ketuk layar kapan saja untuk cek rintangan';

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
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      YOLOView(
                        modelPath: controller.modelConfig.modelPath,
                        task: controller.modelConfig.task,
                        controller: controller.yoloController,
                        cameraResolution: '720p',
                        // Batasi inferensi native ke 10 fps: HP low-end tidak
                        // kepanasan & kamera terasa jauh lebih responsif.
                        // Pengumuman tetap fokus karena Dart sudah men-throttle
                        // ke ±2 fps via DetectorController.
                        streamingConfig: const YOLOStreamingConfig(
                          inferenceFrequency: 10,
                        ),
                        useGpu: true,
                        confidenceThreshold:
                            controller.modelConfig.confidenceThreshold,
                        iouThreshold: controller.modelConfig.iouThreshold,
                        onResult: controller.handleResults,
                        onModelLoad: controller.handleModelLoad,
                        onModelError: controller.handleModelError,
                      ),

                      // Overlay status jeda.
                      if (controller.isPaused.value)
                        Container(
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
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Header kontrol atas (tombol kembali & jeda).
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: _buildTopBar(context),
              ),

              // 3. Banner status bawah (kontras tinggi putih-biru).
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: _buildBottomStatusBar(subtitle),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 24),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30, width: 1.5),
          ),
          child: Text(
            controller.mode.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Semantics(
          label: controller.isPaused.value ? 'Lanjutkan Deteksi' : 'Jeda Deteksi',
          button: true,
          child: Material(
            color: controller.isPaused.value
                ? AppColors.yellowAccent
                : Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                controller.togglePause();
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  controller.isPaused.value ? Icons.play_arrow : Icons.pause,
                  color: controller.isPaused.value ? Colors.black : Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomStatusBar(String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Status deteksi: ${controller.currentStatusText.value}',
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
                        controller.currentStatusText.value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
        ),
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
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Minta Bantuan Relawan',
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
      ],
    );
  }
}
