import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/services/contacts_service.dart';
import 'app/services/fallback_service.dart';
import 'app/services/livekit_call_service.dart';
import 'app/services/tts_service.dart';
import 'app/services/vibration_service.dart';
import 'app/services/visual_help_service.dart';
import 'app/utils/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Service Global (Single Instance untuk seluruh aplikasi)
  await Get.putAsync(() => TtsService().init());
  await Get.putAsync(() async => VibrationService());
  await Get.putAsync(() => ContactsService().init());
  Get.put(FallbackService());
  await Get.putAsync(() => VisualHelpService().init());
  Get.put(LiveKitCallService());

  runApp(
    GetMaterialApp(
      title: "NetraVision",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primaryBlue,
          elevation: 0,
        ),
      ),
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    ),
  );
}
