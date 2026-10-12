import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/vision_mode.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';
import '../../detector/controllers/detector_controller.dart';

class HomeController extends GetxController {
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
}
