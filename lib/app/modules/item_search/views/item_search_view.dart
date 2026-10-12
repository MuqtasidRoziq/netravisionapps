import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/constants/app_colors.dart';
import '../controllers/item_search_controller.dart';

/// Halaman Cari Barang — user menekan tombol mic, lalu mengucapkan nama barang.
/// Aplikasi mendeteksi kata kunci dan membuka kamera detektor hanya untuk barang itu.
class ItemSearchView extends GetView<ItemSearchController> {
  const ItemSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Semantics(
          label: 'Kembali ke menu utama',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryBlue),
            onPressed: () => Get.back(),
          ),
        ),
        title: const Text(
          'Cari Barang',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Instruksi Banner ──────────────────────────────────────
              Semantics(
                label: 'Ketuk tombol mikrofon di bawah lalu ucapkan nama barang yang ingin dicari.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Ketuk tombol mikrofon lalu ucapkan nama barang.\nContoh: "Tolong carikan saya botol minum"',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // ── Status & Teks yang dikenali ───────────────────────────
              Obx(() => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(controller.statusMessage.value),
                  children: [
                    // Status
                    Text(
                      controller.statusMessage.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: controller.isListening.value
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // Teks hasil speech (live)
                    if (controller.recognizedText.value.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightBlueBorder, width: 1.5),
                        ),
                        child: Text(
                          '"${controller.recognizedText.value}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    // Kata kunci yang diekstrak
                    if (controller.extractedItem.value.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_rounded, color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Barang: ${controller.extractedItem.value}',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              )),

              const Spacer(),

              // ── Tombol Mikrofon Utama ─────────────────────────────────
              Obx(() {
                final listening = controller.isListening.value;
                return Semantics(
                  label: listening ? 'Sedang mendengarkan. Ketuk untuk berhenti.' : 'Ketuk dua kali untuk mulai berbicara dan mencari barang',
                  button: true,
                  child: GestureDetector(
                    onTap: listening ? controller.stopListening : controller.startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: listening ? AppColors.primaryBlue : AppColors.lightBlue,
                        border: Border.all(
                          color: listening ? AppColors.primaryBlue : AppColors.lightBlueBorder,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: listening ? 0.4 : 0.15),
                            blurRadius: listening ? 32 : 12,
                            spreadRadius: listening ? 8 : 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: listening ? Colors.white : AppColors.primaryBlue,
                            size: 56,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listening ? 'Mendengarkan...' : 'Ketuk Mic',
                            style: TextStyle(
                              color: listening ? Colors.white : AppColors.primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 32),

              // ── Tip pulsing animation saat mendengarkan ───────────────
              Obx(() => controller.isListening.value
                  ? const _PulsingDots()
                  : const SizedBox(height: 24)),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget tiga titik bergerak sebagai indikator visual listening.
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final offset = (i * 0.33).clamp(0.0, 1.0);
            final value = (((_animController.value - offset) % 1.0 + 1.0) % 1.0);
            final opacity = (0.3 + value * 0.7).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
