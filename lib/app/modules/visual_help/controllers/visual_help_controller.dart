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

  // Timer pencarian (45 detik)
  final RxInt remainingSeconds = 45.obs;
  Timer? _countdownTimer;

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

      ttsService.speak(
        'Bantuan diterima oleh $companionName. Menyambungkan kamera belakang dan audio dua arah.',
        isUrgent: true,
      );

      // Hubungkan media LiveKit
      if (token != null && token.isNotEmpty) {
        await liveKitCallService.connect(
          url: livekitUrl,
          token: token,
          isUserRole: visualHelpService.currentRole.value == 'user',
        );
      }

      if (Get.currentRoute != Routes.VISUAL_HELP_CALL) {
        Get.offNamed(Routes.VISUAL_HELP_CALL);
      }
    } else if (type == 'request_expired') {
      _stopCountdown();
      ttsService.speak(
        'Batas waktu habis. Belum ada relawan yang tersedia saat ini. Silakan coba lagi atau gunakan kontak tepercaya.',
        isUrgent: true,
      );
    } else if (type == 'request_cancelled') {
      _stopCountdown();
      await liveKitCallService.disconnect();
      if (Get.currentRoute == Routes.VISUAL_HELP_CALL || Get.currentRoute == Routes.VISUAL_HELP_WAITING) {
        Get.until((route) => route.settings.name == Routes.VISUAL_HELP || route.settings.name == Routes.HOME);
      }
    } else if (type == 'session_ended') {
      _stopCountdown();
      await liveKitCallService.disconnect();
      ttsService.speak('Sesi bantuan visual telah selesai.', isUrgent: true);
      if (Get.currentRoute == Routes.VISUAL_HELP_CALL) {
        Get.until((route) => route.settings.name == Routes.VISUAL_HELP || route.settings.name == Routes.HOME);
      }
    }
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
      'Kamera belum dibagikan sebelum ada relawan yang menerima.',
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
      ttsService.speak('Gagal membuat permintaan bantuan. Periksa koneksi internet atau server pilot.');
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
    final req = visualHelpService.activeRequest.value;
    if (req != null) {
      await visualHelpService.cancelHelpRequest(req.id, reason: 'Dibatalkan oleh pengguna');
    }
    ttsService.speak('Permintaan bantuan visual dibatalkan.');
    Get.back();
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
      ttsService.speak('Laporan sesi telah dikirim kepada pengelola pilot.');
      Get.back();
    }
  }

  // ====================== FALLBACK LANGSUNG ======================

  Future<void> callContactPhone(String phoneNumber) async {
    HapticFeedback.mediumImpact();
    ttsService.speak('Membuka dialer telepon...');
    final launched = await fallbackService.launchPhoneDialer(phoneNumber);
    if (!launched) {
      ttsService.speak('Tidak dapat membuka aplikasi telepon di perangkat ini.');
    }
  }

  Future<void> callContactWhatsApp(String phoneNumber) async {
    HapticFeedback.mediumImpact();
    ttsService.speak('Membuka aplikasi WhatsApp...');
    final launched = await fallbackService.launchWhatsApp(phoneNumber);
    if (!launched) {
      ttsService.speak('Tidak dapat membuka aplikasi WhatsApp di perangkat ini.');
    }
  }

  @override
  void onClose() {
    _stopCountdown();
    targetNameController.dispose();
    notesController.dispose();
    super.onClose();
  }
}
