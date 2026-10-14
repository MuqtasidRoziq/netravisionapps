/// Mode fitur deteksi yang tersedia di NetraVision
enum VisionMode { indoor, outdoor, currency, itemSearch }

extension VisionModeExtension on VisionMode {
  String get title {
    switch (this) {
      case VisionMode.indoor:
        return 'Kenali Barang Sekitar';
      case VisionMode.outdoor:
        return 'Mode Luar Ruangan';
      case VisionMode.currency:
        return 'Mode Baca Uang';
      case VisionMode.itemSearch:
        return 'Cari Barang';
    }
  }

  String get description {
    switch (this) {
      case VisionMode.indoor:
        return 'Peringatan rintangan & ringkasan sekitar';
      case VisionMode.outdoor:
        return 'Deteksi jalan, kendaraan & bahaya trotoar';
      case VisionMode.currency:
        return 'Pindai nominal uang kertas rupiah';
      case VisionMode.itemSearch:
        return 'Cari barang spesifik dengan suara';
    }
  }

  String get announcement {
    switch (this) {
      case VisionMode.indoor:
        return 'Kenali Barang Sekitar aktif. Pegang ponsel tegak setinggi dada dan arahkan ke depan. Peringatan otomatis diberikan untuk objek dekat yang dikenali. Ketuk layar untuk ringkasan sekitar. Tetap gunakan tongkat atau pendamping.';
      case VisionMode.outdoor:
        return 'Mode Luar Ruangan aktif. Kamera siap mendeteksi jalan, kendaraan, dan rintangan luar ruangan.';
      case VisionMode.currency:
        return 'Mode Baca Uang aktif. Arahkan uang rupiah ke kamera.';
      case VisionMode.itemSearch:
        return 'Mode Cari Barang aktif. Arahkan kamera ke sekitar Anda.';
    }
  }
}
