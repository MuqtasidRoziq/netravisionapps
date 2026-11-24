import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';

class SplashController extends GetxController {
  final TtsService _ttsService = Get.find<TtsService>();

  final RxString statusText = 'Menyiapkan sistem...'.obs;
  bool _hasNavigated = false;

  @override
  void onInit() {
    super.onInit();
    _startSplash();
  }

  Future<void> _startSplash() async {
    // Daftar izin utama yang dibutuhkan oleh aplikasi NetraVision
    final permissions = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ];

    bool hasUngranted = false;
    for (final p in permissions) {
      if (!await p.isGranted) {
        hasUngranted = true;
        break;
      }
    }

    if (hasUngranted) {
      // 1. Berikan pengumuman suara awal kepada pengguna
      statusText.value = 'Menyiapkan izin aplikasi...';
      _ttsService.speak(
        'Selamat datang di NetraVision. Mohon izinkan akses kamera, mikrofon, dan lokasi untuk asisten mobilitas Anda.',
      );

      // Beri sedikit jeda agar pengumuman suara terdengar sebelum dialog sistem muncul
      await Future.delayed(const Duration(milliseconds: 1200));

      // 2. Munculkan izin satu per satu secara langsung dan berurutan di awal aplikasi
      for (final permission in permissions) {
        if (_hasNavigated || isClosed) return;

        final isGranted = await permission.isGranted;
        if (!isGranted) {
          if (permission == Permission.camera) {
            statusText.value = 'Meminta izin kamera...';
          } else if (permission == Permission.microphone) {
            statusText.value = 'Meminta izin mikrofon...';
          } else if (permission == Permission.location) {
            statusText.value = 'Meminta izin lokasi...';
          }

          await permission.request();
          // Jeda singkat antar-dialog agar transisi dialog sistem di Android mulus
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      if (_hasNavigated || isClosed) return;
      statusText.value = 'Izin selesai, menyiapkan menu...';
      _ttsService.speak('Izin selesai. Membuka menu utama.');
      await Future.delayed(const Duration(milliseconds: 1000));
    } else {
      // Jika semua izin sudah diberikan sebelumnya
      statusText.value = 'Menyiapkan sistem...';
      _ttsService.speak(
        'Selamat datang di NetraVision. Asisten pintar mobilitas tunanetra. Usap atau ketuk menu untuk memilih fitur deteksi.',
      );
      await Future.delayed(const Duration(milliseconds: 2200));
    }

    navigateToHome();
  }

  void navigateToHome() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    HapticFeedback.lightImpact();
    Get.offNamed(Routes.HOME);
  }
}
