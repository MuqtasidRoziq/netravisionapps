/// Mode fitur deteksi yang tersedia di NetraVision
enum VisionMode {
  indoor,
  outdoor,
  currency,
  itemSearch,
  findObject,
}

extension VisionModeExtension on VisionMode {
  String get title {
    switch (this) {
      case VisionMode.indoor:
        return 'Mode Dalam Ruangan';
      case VisionMode.outdoor:
        return 'Mode Luar Ruangan';
      case VisionMode.currency:
        return 'Mode Baca Uang';
      case VisionMode.itemSearch:
      case VisionMode.findObject:
        return 'Cari Barang';
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
      case VisionMode.itemSearch:
      case VisionMode.findObject:
        return 'Cari barang spesifik dengan suara';
    }
  }

  String get announcement {
    switch (this) {
      case VisionMode.indoor:
        return 'Mode Dalam Ruangan aktif. Kamera siap mendeteksi perabotan dan rintangan di dalam ruangan.';
      case VisionMode.outdoor:
        return 'Mode Luar Ruangan aktif. Kamera siap mendeteksi jalan, kendaraan, dan rintangan luar ruangan.';
      case VisionMode.currency:
        return 'Mode Baca Uang aktif. Arahkan uang rupiah ke kamera.';
      case VisionMode.itemSearch:
      case VisionMode.findObject:
        return 'Mode Cari Barang aktif. Arahkan kamera ke sekitar Anda.';
    }
  }
}
