import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/visual_help_controller.dart';

class VisualHelpCallView extends GetView<VisualHelpController> {
  const VisualHelpCallView({super.key});

  @override
  Widget build(BuildContext context) {
    final isCompanion = controller.visualHelpService.currentRole.value == 'companion';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await controller.endSession();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Tampilan Video Utama
              Obx(() {
                if (controller.isViewingSnapshot.value) {
                  return _buildSnapshotViewer();
                }

                final track = isCompanion
                    ? controller.liveKitCallService.remoteVideoTrack.value
                    : controller.liveKitCallService.localVideoTrack.value;

                if (track != null) {
                  return VideoTrackRenderer(
                    track,
                    fit: VideoViewFit.cover,
                  );
                }

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, size: 64, color: Colors.white54),
                      const SizedBox(height: 14),
                      Text(
                        isCompanion
                            ? 'Menunggu video kamera belakang pengguna...'
                            : 'Kamera belakang aktif & menyiarkan video.',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }),

              // 2. Banner Konteks Tugas & Status Koneksi di Bagian Atas
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: _buildHeaderBanner(isCompanion),
              ),

              // 3. Kontrol Aksesibel di Bagian Bawah
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: _buildControlBar(isCompanion),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================== HEADER BANNER ======================

  Widget _buildHeaderBanner(bool isCompanion) {
    return Obx(() {
      final req = controller.visualHelpService.activeRequest.value;
      final status = controller.liveKitCallService.connectionStatusText.value;
      final partnerName = isCompanion
          ? (req?.userName ?? 'Pengguna')
          : (req?.assignedCompanionName ?? 'Pendamping');

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mitra: $partnerName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            if (req != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tugas: ${req.taskContext.taskType.label}${req.taskContext.targetName != null ? " (${req.taskContext.targetName})" : ""}',
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ====================== CONTROL BAR ======================

  Widget _buildControlBar(bool isCompanion) {
    return Obx(() {
      final isMuted = controller.liveKitCallService.isMicMuted.value;
      final isCamPaused = controller.liveKitCallService.isCameraPaused.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Mute / Unmute Mic
            Semantics(
              label: isMuted ? 'Mikrofon mati. Ketuk untuk menyalakan.' : 'Mikrofon aktif. Ketuk untuk mematikan.',
              button: true,
              child: IconButton(
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: isMuted ? Colors.redAccent : Colors.white24,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => controller.toggleMic(),
                icon: Icon(isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
              ),
            ),

            // 2. Kontrol Spesifik Peran
            if (!isCompanion) ...[
              // Jeda / Lanjutkan Kamera (Pengguna)
              Semantics(
                label: isCamPaused ? 'Kamera dijeda. Ketuk untuk menyalakan.' : 'Kamera aktif. Ketuk untuk menjeda.',
                button: true,
                child: IconButton(
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: isCamPaused ? Colors.orangeAccent : Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => controller.toggleCamera(),
                  icon: Icon(isCamPaused ? Icons.videocam_off_rounded : Icons.videocam_rounded),
                ),
              ),
              // Bacakan Status Audio
              Semantics(
                label: 'Dengarkan status panggilan',
                button: true,
                child: IconButton(
                  iconSize: 32,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => controller.speakCurrentStatus(),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ),
            ] else ...[
              // Ambil Cuplikan Sementara / Snapshot (Pendamping)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => controller.takeSnapshot(),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text('Cuplikan', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],

            // 3. Tombol Akhiri Sesi
            Semantics(
              label: 'Akhiri sesi bantuan visual',
              button: true,
              child: IconButton(
                iconSize: 32,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.emergencyRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => controller.endSession(),
                icon: const Icon(Icons.call_end_rounded),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ====================== VIEWER CUPLIKAN SEMENTARA ======================

  Widget _buildSnapshotViewer() {
    return Obx(() {
      final snapshot = controller.liveKitCallService.currentSnapshot.value;
      final timeStr = snapshot != null
          ? '${snapshot.timestamp.hour.toString().padLeft(2, '0')}:${snapshot.timestamp.minute.toString().padLeft(2, '0')}:${snapshot.timestamp.second.toString().padLeft(2, '0')}'
          : '';

      return Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Penampil Interaktif dengan Zoom & Pan
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 6.0,
                child: snapshot != null
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey.shade900,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_rounded, size: 100, color: Colors.white70),
                            const SizedBox(height: 12),
                            Text(
                              'Cuplikan Foto Frame ($timeStr)',
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Gunakan cubitan dua jari untuk memperbesar (zoom)\ndan geser untuk memeriksa tulisan atau detail label.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Indikator: Cuplikan Sementara (Bukan Video Langsung)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CUPLIKAN SEMENTARA ($timeStr) — BUKAN VIDEO LANGSUNG',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tombol Kembali ke Video Langsung
            Positioned(
              bottom: 100,
              left: 32,
              right: 32,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => controller.returnToLiveVideo(),
                icon: const Icon(Icons.videocam_rounded),
                label: const Text(
                  'Kembali ke Video Langsung',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
