import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../routes/app_pages.dart';
import '../../../services/tts_service.dart';

class SplashController extends GetxController {
  final TtsService _ttsService = Get.find<TtsService>();

  @override
  void onInit() {
    super.onInit();
    _startSplash();
  }

  Future<void> _startSplash() async {
    // 1. Sambutan suara langsung aktif
    _ttsService.speak(
      'Selamat datang di NetraVision. Asisten pintar mobilitas tunanetra.',
    );

    // 2. Waktu loading sebelum berpindah ke menu utama
    await Future.delayed(const Duration(milliseconds: 2200));
    navigateToHome();
  }

  void navigateToHome() {
    HapticFeedback.lightImpact();
    Get.offNamed(Routes.HOME);
  }
}