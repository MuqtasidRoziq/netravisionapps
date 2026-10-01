/// Mode fitur deteksi yang tersedia di NetraVision
enum VisionMode {
  indoor,
  outdoor,
  currency,
}

extension VisionModeExtension on VisionMode {
  String get title {
    switch (this) {
      case VisionMode.indoor:
        return 'Mode Indoor';
      case VisionMode.outdoor:
        return 'Mode Outdoor';
      case VisionMode.currency:
        return 'Mode Baca Uang';
    }
  }

  String get description {
    switch (this) {
      case VisionMode.indoor:
        return 'Deteksi rintangan, perabotan & ruang';
      case VisionMode.outdoor:
        return 'Deteksi jalan, kendaraan & bahaya trotoar';
      case VisionMode.currency:
        return 'Pindai nominal uang kertas rupiah';
    }
  }

  String get announcement {
    switch (this) {
      case VisionMode.indoor:
        return 'Mode Indoor aktif. Kamera siap mendeteksi perabotan dan rintangan di dalam ruangan.';
      case VisionMode.outdoor:
        return 'Mode Outdoor aktif. Kamera siap mendeteksi jalan, kendaraan, dan rintangan luar ruangan.';
      case VisionMode.currency:
        return 'Mode Baca Uang aktif. Arahkan uang rupiah ke kamera.';
    }
  }
}
