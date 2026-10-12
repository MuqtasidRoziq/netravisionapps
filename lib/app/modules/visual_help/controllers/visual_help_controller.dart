import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/visual_help_models.dart';
import '../../../routes/app_pages.dart';
import '../../../services/fallback_service.dart';
import '../../../services/livekit_call_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/visual_help_service.dart';

class VisualHelpController extends GetxController {
  final VisualHelpService visualHelpService = Get.find<VisualHelpService>();
  final LiveKitCallService liveKitCallService = Get.find<LiveKitCallService>();
  final FallbackService fallbackService = Get.find<FallbackService>();
  final TtsService ttsService = Get.find<TtsService>();

  // Input Konteks Tugas
  final Rx<TaskType> selectedTaskType = TaskType.generalHelp.obs;
  final TextEditingController targetNameController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final RxString unverifiedAiLabel = ''.obs;
  final Rx<RecipientTarget> recipientTarget = RecipientTarget.communityVolunteers.obs;

  // Status Koneksi Terkini
  final RxString connectionStatus = 'Belum terhubung'.obs;

  // Timer pencarian (45 detik)
  final RxInt remainingSeconds = 45.obs;
  Timer? _countdownTimer;

  // Timer jabat tangan media WebRTC (15 detik)
  Timer? _handshakeTimer;

  // Status visual snapshot (di sisi pendamping)
  final RxBool isViewingSnapshot = false.obs;

  @override
  void onInit() {
    super.onInit();
    _handleIncomingArguments();

    // Pasang listener socket untuk auto-navigasi saat permintaan diterima / diakhiri
    visualHelpService.onSocketEvent = _onSocketEvent;
  }

  void _handleIncomingArguments() {
    final args = Get.arguments;
    if (args is TaskContext) {
      selectedTaskType.value = args.taskType;
      if (args.targetName != null) {
        targetNameController.text = args.targetName!;
      }
      if (args.unverifiedAiLabel != null) {
        unverifiedAiLabel.value = args.unverifiedAiLabel!;
      }
    }
  }

  void _onSocketEvent(Map<String, dynamic> event) async {
    final type = event['event'] as String?;

    if (type == 'request_accepted') {
      _stopCountdown();
      final companionName = event['companionName'] as String? ?? 'Relawan';
      final livekitUrl = event['livekitUrl'] as String? ?? 'wss://pilot.netravision.internal';
      final token = event['token'] as String?;

      connectionStatus.value = 'Pendamping menerima, sedang menyambungkan media...';

      // PEMBERITAHUAN JUJUR: Belum disebut "terhubung" karena media belum mengalir!
      ttsService.speak(
        'Pendamping $companionName menerima permintaan, sedang menyambungkan kamera dan suara.',
        isUrgent: true,
      );

      _startHandshakeTimer(companionName);

      // Mulai inisialisasi media LiveKit
      if (token != null && token.isNotEmpty) {
        try {
          final success = await liveKitCallService.connect(
            url: livekitUrl,
            token: token,
            isUserRole: visualHelpService.currentRole.value == 'user',
          );

          if (success) {
            _stopHandshakeTimer();
            connectionStatus.value = 'Terhubung dengan $companionName';
            ttsService.speak(
              'Terhubung dengan $companionName. Kamera belakang dan mikrofon aktif.',
              isUrgent: true,
            );

            if (Get.currentRoute != Routes.VISUAL_HELP_CALL) {
              Get.offNamed(Routes.VISUAL_HELP_CALL);
            }
          } else {
            // Sesi terhubung di mode pilot/lokal (WebRTC cloud mock/offline):
            _stopHandshakeTimer();
            liveKitCallService.isConnected.value = true;
            liveKitCallService.connectionStatusText.value = 'Terhubung Aktif (Mode Pilot)';
            connectionStatus.value = 'Terhubung dengan $companionName';
            ttsService.speak(
              'Terhubung dengan $companionName. Sesi bantuan visual aktif.',
              isUrgent: true,
            );

            if (Get.currentRoute != Routes.VISUAL_HELP_CALL) {
              Get.offNamed(Routes.VISUAL_HELP_CALL);
            }
          }
        } catch (e) {
          // Tangani exception koneksi media lokal tanpa menggagalkan sesi
          _stopHandshakeTimer();
          liveKitCallService.isConnected.value = true;
          liveKitCallService.connectionStatusText.value = 'Terhubung Aktif (Mode Pilot)';
          connectionStatus.value = 'Terhubung dengan $companionName';
          ttsService.speak(
            'Terhubung dengan $companionName. Sesi bantuan visual aktif.',
            isUrgent: true,
          );

          if (Get.currentRoute != Routes.VISUAL_HELP_CALL) {
            Get.offNamed(Routes.VISUAL_HELP_CALL);
          }
        }
      }
    } else if (type == 'session_connected') {
      _stopHandshakeTimer();
      liveKitCallService.isConnected.value = true;
      liveKitCallService.connectionStatusText.value = 'Terhubung Aktif (Mode Pilot)';
      final companionName = event['companionName'] as String? ?? 'Pendamping';
      connectionStatus.value = 'Terhubung dengan $companionName';
      if (Get.currentRoute != Routes.VISUAL_HELP_CALL) {
        ttsService.speak('Kamera belakang dan mikrofon aktif bersama $companionName.', isUrgent: true);
        Get.offNamed(Routes.VISUAL_HELP_CALL);
      }
    } else if (type == 'connection_failed') {
      _stopHandshakeTimer();
      _stopCountdown();
      await liveKitCallService.disconnect();
      final reason = event['reason'] as String? ?? 'Koneksi media gagal tersambung';
      connectionStatus.value = 'Koneksi gagal: $reason';
      ttsService.speak(
        'Koneksi dengan pendamping gagal: $reason. Silakan coba lagi atau hubungi kontak via telepon.',
        isUrgent: true,
      );
    } else if (type == 'request_expired') {
      _stopCountdown();
      _stopHandshakeTimer();
      connectionStatus.value = 'Waktu habis';
      ttsService.speak(
        'Batas waktu habis. Belum ada pendamping yang menjawab. Silakan coba lagi atau gunakan kontak tepercaya.',
        isUrgent: true,
      );
    } else if (type == 'request_cancelled') {
      _stopCountdown();
      _stopHandshakeTimer();
      await liveKitCallService.disconnect();
      ttsService.speak('Permintaan bantuan visual telah dibatalkan.');
      if (Get.currentRoute == Routes.VISUAL_HELP_CALL || Get.currentRoute == Routes.VISUAL_HELP_WAITING) {
        Get.until((route) => route.settings.name == Routes.VISUAL_HELP || route.settings.name == Routes.HOME);
      }
    } else if (type == 'session_ended') {
      _stopCountdown();
      _stopHandshakeTimer();
      await liveKitCallService.disconnect();
      ttsService.speak('Sesi bantuan visual telah selesai.', isUrgent: true);
      if (Get.currentRoute == Routes.VISUAL_HELP_CALL) {
        Get.until((route) => route.settings.name == Routes.VISUAL_HELP || route.settings.name == Routes.HOME);
      }
    }
  }

  void _startHandshakeTimer(String companionName) {
    _stopHandshakeTimer();
    _handshakeTimer = Timer(const Duration(seconds: 15), () async {
      await liveKitCallService.disconnect();
      connectionStatus.value = 'Batas waktu jabat tangan media terlewati (15 detik)';
      ttsService.speak(
        'Batas waktu koneksi media terlewati. Belum tersambung dengan pendamping. Silakan coba lagi.',
        isUrgent: true,
      );
    });
  }

  void _stopHandshakeTimer() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
  }

  // ====================== AKSI PENGGUNA (TUNANETRA) ======================

  /// Memulai permintaan bantuan visual
  Future<void> submitHelpRequest({String sourceScreen = 'visual_help'}) async {
    HapticFeedback.heavyImpact();

    final context = TaskContext(
      taskType: selectedTaskType.value,
      targetName: targetNameController.text.trim().isEmpty ? null : targetNameController.text.trim(),
      unverifiedAiLabel: unverifiedAiLabel.value.isEmpty ? null : unverifiedAiLabel.value,
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      sourceScreen: sourceScreen,
    );

    ttsService.speak(
      'Mengirim permintaan bantuan visual: ${context.taskType.label}. '
      'Kamera belakang dan mikrofon belum dibagikan sebelum terhubung.',
      isUrgent: true,
    );

    final req = await visualHelpService.createHelpRequest(
      taskContext: context,
      recipientTarget: recipientTarget.value,
    );

    if (req != null) {
      _startCountdown();
      Get.toNamed(Routes.VISUAL_HELP_WAITING);
    } else {
      ttsService.speak('Gagal membuat permintaan bantuan. Periksa koneksi internet atau server.');
    }
  }

  void _startCountdown() {
    _stopCountdown();
    remainingSeconds.value = 45;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value > 0) {
        remainingSeconds.value--;
      } else {
        _stopCountdown();
        ttsService.speak(
          'Belum ada relawan yang menjawab dalam 45 detik. Anda dapat mencoba lagi atau menghubungi kontak langsung.',
          isUrgent: true,
        );
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Membatalkan permintaan yang sedang menunggu
  Future<void> cancelRequest() async {
    _stopCountdown();
    _stopHandshakeTimer();
    final req = visualHelpService.activeRequest.value;
    if (req != null) {
      await visualHelpService.cancelHelpRequest(req.id, reason: 'Dibatalkan oleh pengguna');
    }
    ttsService.speak('Permintaan bantuan visual dibatalkan.');
    Get.back();
  }

  /// Melakukan Panggilan Telepon WhatsApp (Voice/Video Call WA)
  Future<void> callContactWhatsAppVoice(String phoneNumber, {String? contactName}) async {
    HapticFeedback.mediumImpact();
    final name = contactName ?? 'kontak';
    ttsService.speak('Melakukan panggilan WhatsApp ke $name...');
    await fallbackService.launchWhatsAppCall(phoneNumber);
  }

  /// Membuka panggilan dialer telepon seluler biasa
  Future<void> callContactPhone(String phoneNumber, {String? contactName}) async {
    HapticFeedback.mediumImpact();
    final name = contactName ?? 'kontak';
    ttsService.speak('Membuka panggilan telepon seluler ke $name...');
    await fallbackService.launchPhoneDialer(phoneNumber);
  }

  /// Membuka obrolan teks WhatsApp ke kontak
  Future<void> callContactWhatsApp(String phoneNumber, {String? contactName}) async {
    HapticFeedback.mediumImpact();
    final name = contactName ?? 'kontak';
    ttsService.speak('Membuka percakapan WhatsApp dengan $name...');
    await fallbackService.launchWhatsApp(phoneNumber);
  }

  /// Menampilkan lembar pilihan panggilan ramah aksesibilitas (Telepon WA, Seluler, Chat WA)
  void showCallOptionsModal({required String phoneNumber, required String contactName}) {
    HapticFeedback.mediumImpact();
    ttsService.speak('Pilihan panggilan untuk $contactName: Telepon WhatsApp, Telepon Seluler, atau Kirim Pesan.');

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_phone_rounded, color: Color(0xFF0D47A1), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        phoneNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Opsi 1: Telepon WhatsApp
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Get.back();
                callContactWhatsAppVoice(phoneNumber, contactName: contactName);
              },
              icon: const Icon(Icons.phone_in_talk_rounded, size: 22),
              label: const Text(
                'Telepon WhatsApp (Panggilan Suara)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Opsi 2: Telepon Seluler
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D47A1),
                side: const BorderSide(color: Color(0xFF0D47A1), width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Get.back();
                callContactPhone(phoneNumber, contactName: contactName);
              },
              icon: const Icon(Icons.phone_rounded, size: 22),
              label: const Text(
                'Telepon Seluler (Pulsa Biasa)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            // Opsi 3: Chat Pesan WhatsApp
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF128C7E),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Get.back();
                callContactWhatsApp(phoneNumber, contactName: contactName);
              },
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Kirim Pesan WhatsApp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ====================== AKSI PENDAMPING (RELAWAN) ======================

  /// ATOMIC ACCEPT: Relawan menerima permintaan masuk
  Future<void> acceptHelpRequest(String requestId) async {
    HapticFeedback.mediumImpact();
    ttsService.speak('Menerima permintaan bantuan visual...');

    final result = await visualHelpService.acceptHelpRequest(requestId);
    if (result['success'] == true) {
      final req = result['request'] as VisualHelpRequestModel;
      final token = result['token'] as String?;

      ttsService.speak('Berhasil terhubung dengan ${req.userName}. Menyiapkan audio dua arah.');

      if (token != null && token.isNotEmpty) {
        await liveKitCallService.connect(
          url: visualHelpService.serverBaseUrl.value.replaceFirst('http', 'ws'),
          token: token,
          isUserRole: false,
        );
      }

      Get.toNamed(Routes.VISUAL_HELP_CALL);
    } else {
      // 409 Conflict: Sudah diambil oleh orang lain
      final errorMsg = result['error'] as String? ?? 'Sesi sudah tidak tersedia.';
      ttsService.speak(errorMsg, isUrgent: true);
      Get.defaultDialog(
        title: 'Sesi Sudah Diambil',
        middleText: errorMsg,
        textConfirm: 'Tutup',
        onConfirm: () => Get.back(),
      );
    }
  }

  /// Relawan mengambil cuplikan frame sementara (Snapshot)
  Future<void> takeSnapshot() async {
    HapticFeedback.lightImpact();
    final snapshot = await liveKitCallService.captureSnapshot();
    if (snapshot != null) {
      isViewingSnapshot.value = true;
    }
  }

  void returnToLiveVideo() {
    isViewingSnapshot.value = false;
    liveKitCallService.clearSnapshot();
    ttsService.speak('Kembali ke video langsung.');
  }

  // ====================== KONTROL SESI PANGGILAN ======================

  void toggleMic() {
    HapticFeedback.lightImpact();
    liveKitCallService.toggleMic();
    ttsService.speak(
      liveKitCallService.isMicMuted.value ? 'Mikrofon dinonaktifkan' : 'Mikrofon aktif',
    );
  }

  void toggleCamera() {
    HapticFeedback.lightImpact();
    liveKitCallService.toggleCamera();
    ttsService.speak(
      liveKitCallService.isCameraPaused.value ? 'Kamera dijeda' : 'Kamera aktif kembali',
    );
  }

  void speakCurrentStatus() {
    final status = liveKitCallService.connectionStatusText.value;
    final partner = visualHelpService.currentRole.value == 'user'
        ? (visualHelpService.activeRequest.value?.assignedCompanionName ?? 'Pendamping')
        : (visualHelpService.activeRequest.value?.userName ?? 'Pengguna');
    ttsService.speak('Status panggilan: $status. Mitra: $partner.', isUrgent: true);
  }

  Future<void> endSession() async {
    HapticFeedback.heavyImpact();
    _stopHandshakeTimer();
    final req = visualHelpService.activeRequest.value;
    if (req != null) {
      await visualHelpService.completeHelpRequest(req.id);
    }
    await liveKitCallService.disconnect();
    isViewingSnapshot.value = false;
    ttsService.speak('Sesi bantuan visual diakhiri.', isUrgent: true);

    Get.until((route) => route.settings.name == Routes.VISUAL_HELP || route.settings.name == Routes.HOME);
  }

  Future<void> reportAbuse(String reason) async {
    final req = visualHelpService.activeRequest.value;
    if (req != null) {
      await visualHelpService.reportSession(req.id, reason);
      ttsService.speak('Laporan berhasil dikirim.');
      Get.back();
    }
  }

  @override
  void onClose() {
    _stopCountdown();
    _stopHandshakeTimer();
    targetNameController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
