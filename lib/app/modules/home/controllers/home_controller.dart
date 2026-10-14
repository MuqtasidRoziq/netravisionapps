import '../../../data/models/visual_help_models.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/models/vision_mode.dart';
import '../../../routes/app_pages.dart';
import '../../../services/location_service.dart';
import '../../../services/tts_service.dart';
import '../../detector/controllers/detector_controller.dart';

class HomeController extends GetxController {
  final RxInt activeMenuIndex = 0.obs;

  // Penjelasan fitur untuk navigasi menu melalui gestur geser.
  final List<String> menuExplanations = [
    'Kenali Barang Sekitar. Mengenali benda dan memberi peringatan untuk objek dekat, serta membacakan ringkasan sekitar saat layar diketuk. Tetap gunakan tongkat.',
    'Mode Luar Ruangan. Memandu navigasi jalan, trotoar, dan rintangan di luar ruangan.',
    'Mode Baca Uang. Memindai dan membacakan nominal uang rupiah secara otomatis.',
    'Cari Barang. Membantu mencari benda tertentu dengan menyebutkan namanya melalui suara.',
    'Bantuan Relawan. Menghubungkan Anda ke pendamping manusia secara langsung melalui video dan suara.',
  ];

  final List<String> menuTitles = [
    'Kenali Barang Sekitar, mengenali benda, peringatan rintangan dekat, dan ringkasan sekitar',
    'Mode Luar Ruangan, mendeteksi rintangan dan jalan di luar',
    'Mode Baca Uang, memindai nominal uang rupiah',
    'Cari Barang, ucapkan nama barang untuk mendeteksinya',
    'Bantuan Relawan, panggilan langsung ke pendamping manusia',
  ];

  /// Satu aktivasi langsung membuka menu yang dipilih.
  void handleMenuTap(int index) {
    if (isSosCountdownActive.value) {
      cancelEmergencySOS();
      return;
    }

    activeMenuIndex.value = index;
    HapticFeedback.heavyImpact();
    activateMenuIndex(index);
  }

  void nextMenu() {
    activeMenuIndex.value =
        (activeMenuIndex.value + 1) % menuExplanations.length;
    HapticFeedback.selectionClick();
    _announceSelectedMenu();
  }

  void previousMenu() {
    activeMenuIndex.value =
        (activeMenuIndex.value - 1 + menuExplanations.length) %
        menuExplanations.length;
    HapticFeedback.selectionClick();
    _announceSelectedMenu();
  }

  void _announceSelectedMenu() {
    final idx = activeMenuIndex.value;
    final total = menuExplanations.length;
    _ttsService.speak(
      'Pilihan ${idx + 1} dari $total: ${menuExplanations[idx]}',
      isUrgent: true,
    );
  }

  void activateMenuIndex(int index) {
    switch (index) {
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
        openItemSearch();
        break;
      case 4:
        openVisualHelp();
        break;
    }
  }

  void activateCurrentMenu() {
    activateMenuIndex(activeMenuIndex.value);
  }

  // Status hitung mundur permintaan bantuan mendesak. Ini bukan pengganti
  // nomor layanan darurat atau pendamping manusia di lokasi.
  final RxBool isSosCountdownActive = false.obs;
  final RxInt sosCountdownSeconds = 5.obs;
  Timer? _sosCountdownTimer;

  void triggerEmergencySOS() {
    if (isSosCountdownActive.value) return;

    isSosCountdownActive.value = true;
    sosCountdownSeconds.value = 5;
    HapticFeedback.heavyImpact();

    _ttsService.speak(
      'Permintaan bantuan mendesak aktif. Ketuk layar untuk membatalkan.',
      isUrgent: true,
    );

    _sosCountdownTimer?.cancel();
    _sosCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      sosCountdownSeconds.value--;
      HapticFeedback.heavyImpact();

      if (sosCountdownSeconds.value > 0) {
        _ttsService.speak('${sosCountdownSeconds.value}', isUrgent: true);
      } else {
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
    _ttsService.speak('Permintaan bantuan dibatalkan.', isUrgent: true);
  }

  void _dispatchSosCall() async {
    isSosCountdownActive.value = false;
    HapticFeedback.heavyImpact();
    _ttsService.speak(
      'Menghubungkan ke relawan bantuan visual. Ini bukan panggilan layanan darurat.',
      isUrgent: true,
    );

    String? locationNotes;
    try {
      if (Get.isRegistered<LocationService>()) {
        final loc = await Get.find<LocationService>().currentPosition();
        if (loc != null) {
          locationNotes =
              'Lokasi: https://maps.google.com/?q=${loc.lat},${loc.lng}';
        }
      }
    } catch (_) {}

    Get.toNamed(
      Routes.VISUAL_HELP,
      arguments: TaskContext(
        taskType: TaskType.generalHelp,
        targetName: 'Permintaan bantuan mendesak',
        sourceScreen: 'emergency_sos',
        notes: locationNotes,
      ),
    );
  }

  final TtsService _ttsService = Get.find<TtsService>();

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

  /// Membuka halaman Cari Barang (speech-to-search)
  void openItemSearch() {
    HapticFeedback.mediumImpact();
    _ttsService.speak(
      'Membuka Cari Barang. Gunakan suara untuk mencari barang.',
    );
    Get.toNamed(Routes.ITEM_SEARCH);
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
      'Panduan NetraVision. Menu satu: Kenali Barang Sekitar untuk mengenali benda, memberi peringatan objek dekat, dan membacakan ringkasan sekitar. Tetap gunakan tongkat. '
      'Menu dua: Mode Outdoor untuk mendeteksi jalan dan rintangan luar ruangan. '
      'Menu tiga: Mode Baca Uang untuk memindai uang rupiah. '
      'Menu empat: Cari Barang, ucapkan nama barang yang ingin dicari. '
      'Menu lima: Bantuan Visual untuk meminta bantuan relawan via kamera dan audio. '
      'Aktifkan salah satu menu untuk mulai menggunakan fitur.',
      isUrgent: true,
    );
  }

  @override
  void onClose() {
    _sosCountdownTimer?.cancel();
    super.onClose();
  }
}
