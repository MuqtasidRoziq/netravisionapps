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

            // 2b. Kartu titik koordinat pengguna (khusus Mode Jalan) — selalu
            //      terlihat agar posisi GPS & alamat terkini jelas.
            if (controller.mode == VisionMode.outdoor)
              Positioned(
                top: 70,
                left: 14,
                right: 14,
                child: _buildCoordinateCard(),
              ),

            // 3. Banner status bawah (kontras tinggi putih-biru, reaktif mandiri).
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: _buildBottomStatusBar(),
            ),

            // 4. Peta navigasi — tampil sejak Mode Jalan dibuka (agar titik
            //    koordinat & posisi pengguna langsung terlihat), mengecil
            //    otomatis setelah rute terbentuk.
            if (controller.mode == VisionMode.outdoor)
              Obx(() {
                final isExpanded = controller.mapExpanded.value;
                return AnimatedPositioned(
                  key: const ValueKey('navigation_map_embed_pos'),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  left: isExpanded ? 14 : null,
                  right: 14,
                  top: 160,
                  bottom: isExpanded ? 85 : null,
                  width: isExpanded ? null : 145,
                  height: isExpanded ? null : 145,
                  child: NavigationMapEmbed(
                    key: const ValueKey('navigation_map_embed_instance'),
                    controller: controller,
                  ),
                );
              }),


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

  /// Header kontrol atas: hanya tombol Kembali dan indikator mode aktif (bersih dan mudah diakses).
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tombol Kembali (Lebih besar, ramah sentuhan)
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
                    Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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

        // Badge Indikator Mode Kamera Aktif
        Semantics(
          label: 'Mode aktif: ${controller.mode.title}',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
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
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  controller.mode.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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

  Widget _buildCoordinateCard() {
    return Obx(() {
      final available = controller.locationAvailable.value;
      final pos = controller.userPosition.value;
      final address = controller.currentAddress.value;

      String coords;
      String status;
      bool ok;
      if (!available) {
        ok = false;
        coords = 'Lokasi tidak aktif';
        status = 'Izinkan akses lokasi pada perangkat';
      } else if (pos == null) {
        ok = false;
        coords = 'Mengunci sinyal GPS...';
        status = 'Menunggu satelit';
      } else {
        ok = true;
        coords =
            '${pos.lat.toStringAsFixed(5)}, ${pos.lng.toStringAsFixed(5)}';
        final acc = pos.accuracy;
        status = (acc != null && acc > 0)
            ? 'GPS aktif · akurasi ±${acc.round()} m'
            : 'GPS aktif';
      }

      return Semantics(
        label: 'Titik koordinat Anda. $coords. $status.'
            '${address.isNotEmpty ? ' $address.' : ''}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ok ? AppColors.successGreen : Colors.white30,
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Icon(
                ok ? Icons.my_location_rounded : Icons.location_searching_rounded,
                color: ok ? AppColors.successGreen : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      coords,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.isNotEmpty ? '$status · $address' : status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomStatusBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instruksi Navigasi Jalan (Hanya tampil jika sedang dalam rute perjalanan aktif)
        if (controller.mode == VisionMode.outdoor)
          Obx(() {
            final navText = controller.navStatus.value;
            if (navText.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, color: AppColors.primaryBlue, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      navText,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

        // Tombol Sebutkan Tujuan / Mikrofon (Khusus Mode Jalan)
        if (controller.mode == VisionMode.outdoor)
          Obx(() {
            final isListening = controller.isListeningDestination.value;
            final hasDestination = controller.destinationPoint.value != null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                label: isListening
                    ? 'Mikrofon sedang mendengarkan tujuan. Ketuk untuk berhenti.'
                    : (hasDestination
                        ? 'Ganti Tujuan Rute. Ketuk untuk berbicara dan mengganti tujuan.'
                        : 'Sebutkan Tujuan Rute. Ketuk untuk mengaktifkan mikrofon dan menyebutkan tempat tujuan.'),
                button: true,
                child: Material(
                  color: isListening ? const Color(0xFFE65100) : AppColors.successGreen,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      if (isListening) {
                        controller.stopDestinationListening();
                      } else {
                        controller.startDestinationListening(announcePrompt: false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isListening ? Icons.mic : Icons.mic_none_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              isListening
                                  ? 'Mendengarkan... (Ketuk Batal)'
                                  : (hasDestination
                                      ? 'Ganti Tujuan Rute (Bicara)'
                                      : 'Sebutkan Tujuan (Mikrofon)'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
            );
          }),

        // Tombol Aksesibel Minta Bantuan Relawan (Besar, Jelas, dan Mudah Dijangkau)
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
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Minta Bantuan Relawan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
