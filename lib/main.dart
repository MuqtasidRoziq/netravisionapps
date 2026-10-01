import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/services/camera_service.dart';
import 'app/services/tts_service.dart';
import 'app/services/vision_service.dart';
import 'app/utils/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Service Global (Single Instance untuk seluruh aplikasi)
  await Get.putAsync(() => TtsService().init());
  await Get.putAsync(() => CameraService().init());
  await Get.putAsync(() => VisionService().init());

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
