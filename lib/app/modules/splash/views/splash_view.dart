import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/constants/app_colors.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Semantics(
        label: 'Layar Splash NetraVision. Asisten pintar mobilitas tunanetra sedang memuat. Ketuk layar untuk langsung masuk.',
        button: true,
        child: InkWell(
          onTap: () => controller.navigateToHome(),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),

                    // Logo dengan Animasi Loading Circle yang Langsung Muter Mengelilingi Logo
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Cincin Animasi Loading Muter di Sekeliling Logo
                        const SizedBox(
                          width: 176,
                          height: 176,
                          child: CircularProgressIndicator(
                            strokeWidth: 4.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                            backgroundColor: AppColors.lightBlue,
                          ),
                        ),

                        // Wadah Logo di Tengah
                        Container(
                          width: 150,
                          height: 150,
                          padding: const EdgeInsets.all(22),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cardShadow,
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo_no_bg.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.visibility,
                                size: 70,
                                color: AppColors.primaryBlue,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // Nama Aplikasi
                    const Text(
                      'NetraVision',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    const Text(
                      'Asisten Mobilitas Mandiri Tunanetra',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Spacer(),

                    // Keterangan Status Sistem
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sync,
                          size: 18,
                          color: AppColors.accentBlue,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Menyiapkan sistem...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}