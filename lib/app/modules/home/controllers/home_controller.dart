import '../../../data/models/visual_help_models.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/vision_mode.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';
import '../../detector/controllers/detector_controller.dart';

class HomeController extends GetxController {
  final RxInt activeMenuIndex = 0.obs;

  final List<String> menuTitles = [
    'Mode Dalam Ruangan, mendeteksi perabotan dan pintu',
    'Mode Luar Ruangan, mendeteksi rintangan dan jalan di luar',
    'Mode Baca Uang, memindai nominal uang rupiah',
    'Bantuan Relawan, panggilan langsung ke pendamping manusia',
  ];

  void nextMenu() {
    activeMenuIndex.value = (activeMenuIndex.value + 1) % menuTitles.length;
    HapticFeedback.selectionClick();
    _announceSelectedMenu();
  }

  void previousMenu() {
    activeMenuIndex.value = (activeMenuIndex.value - 1 + menuTitles.length) % menuTitles.length;
    HapticFeedback.selectionClick();
    _announceSelectedMenu();
  }

  void _announceSelectedMenu() {
    final idx = activeMenuIndex.value;
    final total = menuTitles.length;
    _ttsService.speak('Pilihan ${idx + 1} dari $total: ${menuTitles[idx]}. Ketuk dua kali untuk memilih.');
  }

  void activateCurrentMenu() {
    switch (activeMenuIndex.value) {
      case 0:
        openMode(VisionMode.indoor);
        break;
      case 1:
        openMode(VisionMode.outdoor);
        break;
      case 2:
        openMode(VisionMode.currency);
        break;
      case 3:
        openVisualHelp();
        break;
    }
  }

  // Status Hitung Mundur Darurat (SOS)
  final RxBool isSosCountdownActive = false.obs;
  final RxInt sosCountdownSeconds = 3.obs;
  Timer? _sosCountdownTimer;

  void triggerEmergencySOS() {
    if (isSosCountdownActive.value) return;

    isSosCountdownActive.value = true;
    sosCountdownSeconds.value = 3;
    HapticFeedback.heavyImpact();

    _ttsService.speak(
      'Peringatan darurat aktif. Menghubungi relawan dalam tiga detik. Ketuk layar sekali untuk membatalkan.',
      isUrgent: true,
    );

    _sosCountdownTimer?.cancel();
    _sosCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      sosCountdownSeconds.value--;
      HapticFeedback.heavyImpact();

      if (sosCountdownSeconds.value <= 0) {
        timer.cancel();
        _dispatchSosCall();
      }
    });
  }

  void cancelEmergencySOS() {
    if (!isSosCountdownActive.value) return;

    _sosCountdownTimer?.cancel();
    isSosCountdownActive.value = false;
    HapticFeedback.mediumImpact();
    _ttsService.speak('Panggilan darurat dibatalkan.', isUrgent: true);
  }

  void _dispatchSosCall() {
    isSosCountdownActive.value = false;
    HapticFeedback.heavyImpact();
    _ttsService.speak('Menghubungkan panggilan darurat sekarang...', isUrgent: true);

    Get.toNamed(
      Routes.VISUAL_HELP,
      arguments: const TaskContext(
        taskType: TaskType.generalHelp,
        targetName: '🚨 PANGGILAN DARURAT (SOS)',
        sourceScreen: 'emergency_sos',
      ),
    );
  }


  final TtsService _ttsService = Get.find<TtsService>();

  @override
  void onReady() {
    super.onReady();
    // Sambutan awal saat aplikasi pertama kali terbuka
    _ttsService.speak(
      'Selamat datang di NetraVision. Usap atau ketuk menu untuk memilih fitur deteksi.',
    );
  }

  /// Membuka kamera dengan mode yang dipilih
  void openMode(VisionMode mode) {
    HapticFeedback.mediumImpact();
    _ttsService.speak('Membuka ${mode.title}');
    // Buang controller detector sesi sebelumnya (jika masih ada) agar mode
    // baru selalu dibuat segar sesuai argumen. Tanpa ini, controller lama —
    // mis. sisa Mode Baca Uang — bisa dipakai ulang dan membuat Mode Outdoor
    // ikut mendeteksi/membacakan uang.
    Get.delete<DetectorController>(force: true);
    Get.toNamed(Routes.DETECTOR, arguments: mode);
  }

  /// Fitur Bantuan Visual
  void openVisualHelp() {
    HapticFeedback.mediumImpact();
    _ttsService.speak('Membuka menu Bantuan Visual');
    Get.toNamed(Routes.VISUAL_HELP);
  }

  /// Panduan suara pengantar bagi tunanetra
  void playGuide() {
    HapticFeedback.lightImpact();
    _ttsService.speak(
      'Panduan NetraVision. Menu satu: Mode Indoor untuk mendeteksi perabotan di dalam rumah. '
      'Menu dua: Mode Outdoor untuk mendeteksi jalan dan rintangan luar ruangan. '
      'Menu tiga: Mode Baca Uang untuk memindai uang rupiah. '
      'Menu empat: Bantuan Visual untuk meminta bantuan relawan via kamera dan audio. '
      'Ketuk dua kali menu mana saja untuk mengaktifkannya.',
      isUrgent: true,
    );
  }
}
