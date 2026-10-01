import 'package:flutter/material.dart';

/// Palet warna NetraVision (Putih - Biru) dengan kontras tinggi
/// yang ramah aksesibilitas untuk pengguna tunanetra dan low-vision (WCAG AAA standard).
class AppColors {
  AppColors._();

  // Biru Utama (NetraVision Blue)
  static const Color primaryBlue = Color(0xFF0D47A1);      // Biru tua pekat (kontras tinggi)
  static const Color accentBlue = Color(0xFF1976D2);       // Biru aktif
  static const Color lightBlue = Color(0xFFE3F2FD);        // Biru sangat muda (background card)
  static const Color lightBlueBorder = Color(0xFF90CAF9);  // Border penegas card

  // Warna Netral & Permukaan
  static const Color background = Color(0xFFF8FAFC);       // Putih kebiruan lembut
  static const Color surface = Color(0xFFFFFFFF);          // Putih bersih
  static const Color cardShadow = Color(0x140D47A1);       // Bayangan lembut biru

  // Teks Kontras Tinggi
  static const Color textPrimary = Color(0xFF0F172A);      // Hitam kebiruan pekat (mudah dibaca)
  static const Color textSecondary = Color(0xFF475569);    // Abu-abu gelap
  static const Color textOnBlue = Color(0xFFFFFFFF);       // Teks putih di atas biru

  // Warna Aksen / Khusus
  static const Color yellowAccent = Color(0xFFFFB300);     // Aksen kuning kontras untuk ikon/indikator
  static const Color emergencyRed = Color(0xFFC62828);     // Merah darurat SOS
  static const Color emergencyRedLight = Color(0xFFFFEBEE);// Background merah muda
  static const Color successGreen = Color(0xFF2E7D32);     // Hijau status siap
}
