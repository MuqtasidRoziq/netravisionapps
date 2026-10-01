import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../data/models/vision_mode.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';

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
    Get.toNamed(Routes.DETECTOR, arguments: mode);
  }

  /// Fitur Darurat / SOS
  void triggerSos() {
    HapticFeedback.heavyImpact();
    _ttsService.speak('Menghubungi kontak darurat dan relawan peduli tunanetra.', isUrgent: true);

    Get.defaultDialog(
      title: 'Panggilan Darurat',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      middleText: 'Apakah Anda ingin menghubungkan panggilan suara ke kontak darurat atau relawan terdekat?',
      middleTextStyle: const TextStyle(fontSize: 16),
      textConfirm: 'Panggil Relawan',
      textCancel: 'Batal',
      confirmTextColor: Colors.white,
      buttonColor: const Color(0xFFC62828),
      onConfirm: () {
        Get.back();
        _ttsService.speak('Menyambungkan panggilan...');
      },
      onCancel: () {
        _ttsService.speak('Panggilan darurat dibatalkan');
      },
    );
  }

  /// Panduan suara pengantar bagi tunanetra
  void playGuide() {
    HapticFeedback.lightImpact();
    _ttsService.speak(
      'Panduan NetraVision. Menu satu: Mode Indoor untuk mendeteksi perabotan di dalam rumah. '
      'Menu dua: Mode Outdoor untuk mendeteksi jalan dan rintangan luar ruangan. '
      'Menu tiga: Mode Baca Uang untuk memindai uang rupiah. '
      'Menu empat: Bantuan Relawan untuk panggilan darurat. '
      'Ketuk dua kali menu mana saja untuk mengaktifkannya.',
      isUrgent: true,
    );
  }
}
