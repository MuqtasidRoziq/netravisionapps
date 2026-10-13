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

  // Indeks menu yang sedang terpilih pada ketukan pertama (-1 jika belum ada yang dipilih)
  final RxInt selectedMenuIndex = (-1).obs;
  Timer? _selectionTimer;

  // Penjelasan fitur singkat dan jelas untuk ketukan pertama
  final List<String> menuExplanations = [
    'Mode Dalam Ruangan. Mendeteksi rintangan, perabotan, dan pintu di sekitar Anda di dalam ruangan. Ketuk sekali lagi untuk masuk.',
    'Mode Luar Ruangan. Memandu navigasi jalan, trotoar, dan rintangan di luar ruangan. Ketuk sekali lagi untuk masuk.',
    'Mode Baca Uang. Memindai dan membacakan nominal uang rupiah secara otomatis. Ketuk sekali lagi untuk masuk.',
    'Cari Barang. Membantu mencari benda tertentu dengan menyebutkan namanya melalui suara. Ketuk sekali lagi untuk masuk.',
    'Bantuan Relawan. Menghubungkan Anda ke pendamping manusia secara langsung melalui video dan suara. Ketuk sekali lagi untuk masuk.',
  ];

  final List<String> menuTitles = [
    'Mode Dalam Ruangan, mendeteksi perabotan dan pintu',
    'Mode Luar Ruangan, mendeteksi rintangan dan jalan di luar',
    'Mode Baca Uang, memindai nominal uang rupiah',
    'Cari Barang, ucapkan nama barang untuk mendeteksinya',
    'Bantuan Relawan, panggilan langsung ke pendamping manusia',
  ];

  /// Menangani ketukan pada kartu menu:
  /// - Ketukan ke-1: Mengumumkan suara penjelasan fitur yang singkat dan jelas.
  /// - Ketukan ke-2: Membuka menu/mode tersebut.
  void handleMenuTap(int index) {
    if (isSosCountdownActive.value) {
      cancelEmergencySOS();
      return;
    }

    if (selectedMenuIndex.value == index) {
      // KETUKAN KE-2: Masuk ke menu!
      _selectionTimer?.cancel();
      selectedMenuIndex.value = -1;
      HapticFeedback.heavyImpact();
      activateMenuIndex(index);
    } else {
      // KETUKAN KE-1: Pilih menu dan bacakan penjelasan fitur
      selectedMenuIndex.value = index;
      activeMenuIndex.value = index;
      HapticFeedback.mediumImpact();

      final explanation = index >= 0 && index < menuExplanations.length
          ? menuExplanations[index]
          : 'Menu dipilih. Ketuk sekali lagi untuk masuk.';
      _ttsService.speak(explanation, isUrgent: true);

      // Batalkan seleksi otomatis setelah 6 detik jika tidak diketuk ulang
      _selectionTimer?.cancel();
      _selectionTimer = Timer(const Duration(seconds: 6), () {
        if (selectedMenuIndex.value == index) {
          selectedMenuIndex.value = -1;
        }
      });
    }
  }

  void nextMenu() {
    activeMenuIndex.value = (activeMenuIndex.value + 1) % menuExplanations.length;
    selectedMenuIndex.value = activeMenuIndex.value;
    HapticFeedback.selectionClick();
    _announceSelectedMenu();
  }

  void previousMenu() {
    activeMenuIndex.value = (activeMenuIndex.value - 1 + menuExplanations.length) % menuExplanations.length;
    selectedMenuIndex.value = activeMenuIndex.value;
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

    _selectionTimer?.cancel();
    _selectionTimer = Timer(const Duration(seconds: 6), () {
      if (selectedMenuIndex.value == idx) {
        selectedMenuIndex.value = -1;
      }
    });
  }

  void activateMenuIndex(int index) {
    _selectionTimer?.cancel();
    selectedMenuIndex.value = -1;
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
    final target = selectedMenuIndex.value != -1 ? selectedMenuIndex.value : activeMenuIndex.value;
    activateMenuIndex(target);
  }

  // Status Hitung Mundur Darurat (SOS)
  final RxBool isSosCountdownActive = false.obs;
  final RxInt sosCountdownSeconds = 5.obs;
  Timer? _sosCountdownTimer;

  void triggerEmergencySOS() {
    if (isSosCountdownActive.value) return;

    isSosCountdownActive.value = true;
    sosCountdownSeconds.value = 5;
    HapticFeedback.heavyImpact();

    _ttsService.speak(
      'Peringatan darurat aktif. Ketuk layar untuk membatalkan.',
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
    _ttsService.speak('Panggilan darurat dibatalkan.', isUrgent: true);
  }

  void _dispatchSosCall() async {
    isSosCountdownActive.value = false;
    HapticFeedback.heavyImpact();
    _ttsService.speak('Menghubungkan panggilan darurat sekarang...', isUrgent: true);

    String? locationNotes;
    try {
      if (Get.isRegistered<LocationService>()) {
        final loc = await Get.find<LocationService>().currentPosition();
        if (loc != null) {
          locationNotes = 'Lokasi: https://maps.google.com/?q=${loc.lat},${loc.lng}';
        }
      }
    } catch (_) {}

    Get.toNamed(
      Routes.VISUAL_HELP,
      arguments: TaskContext(
        taskType: TaskType.generalHelp,
        targetName: '🚨 PANGGILAN DARURAT (SOS)',
        sourceScreen: 'emergency_sos',
        notes: locationNotes,
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

  /// Membuka halaman Cari Barang (speech-to-search)
  void openItemSearch() {
    HapticFeedback.mediumImpact();
    _ttsService.speak('Membuka Cari Barang. Gunakan suara untuk mencari barang.');
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
      'Panduan NetraVision. Menu satu: Mode Indoor untuk mendeteksi perabotan di dalam rumah. '
      'Menu dua: Mode Outdoor untuk mendeteksi jalan dan rintangan luar ruangan. '
      'Menu tiga: Mode Baca Uang untuk memindai uang rupiah. '
      'Menu empat: Cari Barang, ucapkan nama barang yang ingin dicari. '
      'Menu lima: Bantuan Visual untuk meminta bantuan relawan via kamera dan audio. '
      'Ketuk dua kali menu mana saja untuk mengaktifkannya.',
      isUrgent: true,
    );
  }

  @override
  void onClose() {
    _selectionTimer?.cancel();
    _sosCountdownTimer?.cancel();
    super.onClose();
  }
}
