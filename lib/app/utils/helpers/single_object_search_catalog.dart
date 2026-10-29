import 'package:flutter/material.dart';

/// Metadata untuk objek yang dapat dicari dalam Mode Cari Objek Tunggal.
class SearchableTarget {
  const SearchableTarget({
    required this.label,
    required this.displayName,
    required this.icon,
    required this.category,
  });

  /// Nama kelas AI yang dikenali oleh model TFLite (harus sama persis dengan labels.txt).
  final String label;

  /// Nama ramah Bahasa Indonesia untuk diucapkan TTS dan ditampilkan di UI.
  final String displayName;

  /// Ikon representatif untuk mempermudah identifikasi visual.
  final IconData icon;

  /// Kategori objek (mis. Elektronik, Alat Makan, Perabotan, dll).
  final String category;
}

/// Katalog objek target yang didukung oleh model `indoor_objects.tflite`
/// untuk fitur Pencarian Objek Tunggal.
class SingleObjectSearchCatalog {
  /// Daftar objek target populer yang paling sering dicari oleh tunanetra sehari-hari.
  static const List<SearchableTarget> quickTargets = [
    SearchableTarget(
      label: 'tas punggung',
      displayName: 'Tas Ransel / Punggung',
      icon: Icons.backpack_rounded,
      category: 'Barang Pribadi',
    ),
    SearchableTarget(
      label: 'ponsel',
      displayName: 'Ponsel / HP',
      icon: Icons.smartphone_rounded,
      category: 'Elektronik',
    ),
    SearchableTarget(
      label: 'botol',
      displayName: 'Botol Minum',
      icon: Icons.water_drop_rounded,
      category: 'Wadah & Minum',
    ),
    SearchableTarget(
      label: 'cangkir',
      displayName: 'Cangkir / Gelas',
      icon: Icons.coffee_rounded,
      category: 'Wadah & Minum',
    ),
    SearchableTarget(
      label: 'kursi',
      displayName: 'Kursi',
      icon: Icons.chair_rounded,
      category: 'Perabotan',
    ),
    SearchableTarget(
      label: 'laptop',
      displayName: 'Laptop',
      icon: Icons.laptop_rounded,
      category: 'Elektronik',
    ),
    SearchableTarget(
      label: 'remot',
      displayName: 'Remot TV / AC',
      icon: Icons.settings_remote_rounded,
      category: 'Elektronik',
    ),
    SearchableTarget(
      label: 'sendok',
      displayName: 'Sendok',
      icon: Icons.restaurant_rounded,
      category: 'Alat Makan',
    ),
    SearchableTarget(
      label: 'buku',
      displayName: 'Buku',
      icon: Icons.menu_book_rounded,
      category: 'Barang Pribadi',
    ),
    SearchableTarget(
      label: 'gunting',
      displayName: 'Gunting',
      icon: Icons.content_cut_rounded,
      category: 'Barang Pribadi',
    ),
    SearchableTarget(
      label: 'payung',
      displayName: 'Payung',
      icon: Icons.umbrella_rounded,
      category: 'Barang Pribadi',
    ),
    SearchableTarget(
      label: 'tas tangan',
      displayName: 'Tas Tangan',
      icon: Icons.shopping_bag_rounded,
      category: 'Barang Pribadi',
    ),
  ];

  /// Daftar lengkap seluruh 50 objek indoor yang didukung oleh model AI NetraVision.
  static const List<SearchableTarget> allTargets = [
    ...quickTargets,
    SearchableTarget(
      label: 'koper',
      displayName: 'Koper',
      icon: Icons.luggage_rounded,
      category: 'Barang Pribadi',
    ),
    SearchableTarget(
      label: 'jam',
      displayName: 'Jam',
      icon: Icons.access_time_filled_rounded,
      category: 'Barang Pribadi',
    ),
    SearchableTarget(
      label: 'sikat gigi',
      displayName: 'Sikat Gigi',
      icon: Icons.clean_hands_rounded,
      category: 'Perawatan Diri',
    ),
    SearchableTarget(
      label: 'pengering rambut',
      displayName: 'Pengering Rambut',
      icon: Icons.shower_rounded,
      category: 'Perawatan Diri',
    ),
    SearchableTarget(
      label: 'dasi',
      displayName: 'Dasi',
      icon: Icons.checkroom_rounded,
      category: 'Pakaian',
    ),
    SearchableTarget(
      label: 'garpu',
      displayName: 'Garpu',
      icon: Icons.flatware_rounded,
      category: 'Alat Makan',
    ),
    SearchableTarget(
      label: 'pisau',
      displayName: 'Pisau',
      icon: Icons.kitchen_rounded,
      category: 'Alat Makan',
    ),
    SearchableTarget(
      label: 'mangkuk',
      displayName: 'Mangkuk',
      icon: Icons.soup_kitchen_rounded,
      category: 'Alat Makan',
    ),
    SearchableTarget(
      label: 'gelas anggur',
      displayName: 'Gelas Kaki',
      icon: Icons.wine_bar_rounded,
      category: 'Wadah & Minum',
    ),
    SearchableTarget(
      label: 'sofa',
      displayName: 'Sofa',
      icon: Icons.weekend_rounded,
      category: 'Perabotan',
    ),
    SearchableTarget(
      label: 'tempat tidur',
      displayName: 'Tempat Tidur',
      icon: Icons.bed_rounded,
      category: 'Perabotan',
    ),
    SearchableTarget(
      label: 'meja makan',
      displayName: 'Meja Makan',
      icon: Icons.table_restaurant_rounded,
      category: 'Perabotan',
    ),
    SearchableTarget(
      label: 'tanaman pot',
      displayName: 'Tanaman Hias',
      icon: Icons.yard_rounded,
      category: 'Dekorasi',
    ),
    SearchableTarget(
      label: 'vas',
      displayName: 'Vas Bunga',
      icon: Icons.local_florist_rounded,
      category: 'Dekorasi',
    ),
    SearchableTarget(
      label: 'televisi',
      displayName: 'Televisi',
      icon: Icons.tv_rounded,
      category: 'Elektronik',
    ),
    SearchableTarget(
      label: 'keyboard',
      displayName: 'Keyboard Komputer',
      icon: Icons.keyboard_rounded,
      category: 'Elektronik',
    ),
    SearchableTarget(
      label: 'tetikus',
      displayName: 'Tetikus / Mouse',
      icon: Icons.mouse_rounded,
      category: 'Elektronik',
    ),
    SearchableTarget(
      label: 'kulkas',
      displayName: 'Kulkas',
      icon: Icons.kitchen_rounded,
      category: 'Dapur & Sanitasi',
    ),
    SearchableTarget(
      label: 'microwave',
      displayName: 'Microwave',
      icon: Icons.microwave_rounded,
      category: 'Dapur & Sanitasi',
    ),
    SearchableTarget(
      label: 'oven',
      displayName: 'Oven',
      icon: Icons.countertops_rounded,
      category: 'Dapur & Sanitasi',
    ),
    SearchableTarget(
      label: 'pemanggang roti',
      displayName: 'Pemanggang Roti',
      icon: Icons.bakery_dining_rounded,
      category: 'Dapur & Sanitasi',
    ),
    SearchableTarget(
      label: 'wastafel',
      displayName: 'Wastafel',
      icon: Icons.wash_rounded,
      category: 'Dapur & Sanitasi',
    ),
    SearchableTarget(
      label: 'toilet',
      displayName: 'Toilet / Kloset',
      icon: Icons.wc_rounded,
      category: 'Dapur & Sanitasi',
    ),
    SearchableTarget(
      label: 'bola',
      displayName: 'Bola',
      icon: Icons.sports_soccer_rounded,
      category: 'Hobi & Mainan',
    ),
    SearchableTarget(
      label: 'boneka beruang',
      displayName: 'Boneka',
      icon: Icons.toys_rounded,
      category: 'Hobi & Mainan',
    ),
    SearchableTarget(
      label: 'pisang',
      displayName: 'Pisang',
      icon: Icons.eco_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'apel',
      displayName: 'Apel',
      icon: Icons.apple_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'jeruk',
      displayName: 'Jeruk',
      icon: Icons.circle_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'roti isi',
      displayName: 'Roti Isi / Sandwich',
      icon: Icons.lunch_dining_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'pizza',
      displayName: 'Pizza',
      icon: Icons.local_pizza_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'donat',
      displayName: 'Donat',
      icon: Icons.donut_large_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'kue',
      displayName: 'Kue',
      icon: Icons.cake_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'sosis',
      displayName: 'Sosis',
      icon: Icons.fastfood_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'brokoli',
      displayName: 'Brokoli',
      icon: Icons.grass_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'wortel',
      displayName: 'Wortel',
      icon: Icons.spa_rounded,
      category: 'Makanan & Buah',
    ),
    SearchableTarget(
      label: 'orang',
      displayName: 'Orang',
      icon: Icons.person_rounded,
      category: 'Lingkungan',
    ),
    SearchableTarget(
      label: 'kucing',
      displayName: 'Kucing',
      icon: Icons.pets_rounded,
      category: 'Hewan Peliharaan',
    ),
    SearchableTarget(
      label: 'anjing',
      displayName: 'Anjing',
      icon: Icons.pets_rounded,
      category: 'Hewan Peliharaan',
    ),
  ];

  /// Dapatkan nama tampilan ramah berdasarkan label AI.
  static String getDisplayName(String label) {
    final clean = label.trim().toLowerCase();
    for (final target in allTargets) {
      if (target.label == clean) return target.displayName;
    }
    return label;
  }

  /// Dapatkan ikon berdasarkan label AI.
  static IconData getIcon(String label) {
    final clean = label.trim().toLowerCase();
    for (final target in allTargets) {
      if (target.label == clean) return target.icon;
    }
    return Icons.center_focus_strong_rounded;
  }

  /// Memeriksa apakah label deteksi AI cocok dengan target yang dipilih pengguna,
  /// termasuk mendukung variasi sinonim (mis. tas punggung / ransel / backpack).
  static bool matches(String detectedLabel, String targetLabel) {
    final d = detectedLabel.trim().toLowerCase();
    final t = targetLabel.trim().toLowerCase();
    if (d == t) return true;

    // Sinonim Tas: tas punggung, tas ransel, backpack, tas, bag
    const bagKeywords = {'tas', 'punggung', 'ransel', 'backpack', 'bag'};
    if (bagKeywords.any((k) => d.contains(k)) &&
        bagKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Ponsel: ponsel, hp, phone, smartphone, cell
    const phoneKeywords = {'ponsel', 'hp', 'phone', 'smartphone', 'cell'};
    if (phoneKeywords.any((k) => d.contains(k)) &&
        phoneKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Cangkir: cangkir, gelas, cup, mug
    const cupKeywords = {'cangkir', 'gelas', 'cup', 'mug'};
    if (cupKeywords.any((k) => d.contains(k)) &&
        cupKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Botol: botol, bottle
    const bottleKeywords = {'botol', 'bottle'};
    if (bottleKeywords.any((k) => d.contains(k)) &&
        bottleKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Kursi: kursi, chair
    const chairKeywords = {'kursi', 'chair'};
    if (chairKeywords.any((k) => d.contains(k)) &&
        chairKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Laptop: laptop, notebook, komputer
    const laptopKeywords = {'laptop', 'notebook', 'komputer'};
    if (laptopKeywords.any((k) => d.contains(k)) &&
        laptopKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Kunci: kunci, key
    const keyKeywords = {'kunci', 'key'};
    if (keyKeywords.any((k) => d.contains(k)) &&
        keyKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Dompet: dompet, wallet
    const walletKeywords = {'dompet', 'wallet'};
    if (walletKeywords.any((k) => d.contains(k)) &&
        walletKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Saklar / Colokan: saklar, colokan, stopkontak, switch, socket, plug
    const switchKeywords = {'saklar', 'colokan', 'stopkontak', 'switch', 'socket', 'plug'};
    if (switchKeywords.any((k) => d.contains(k)) &&
        switchKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Kacamata: kacamata, glasses, spectacles
    const glassesKeywords = {'kacamata', 'glasses', 'spectacles'};
    if (glassesKeywords.any((k) => d.contains(k)) &&
        glassesKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Obat: obat, medicine, pill, drug
    const medKeywords = {'obat', 'medicine', 'pill', 'drug'};
    if (medKeywords.any((k) => d.contains(k)) &&
        medKeywords.any((k) => t.contains(k))) {
      return true;
    }

    // Sinonim Remot: remot, remote
    const remoteKeywords = {'remot', 'remote'};
    if (remoteKeywords.any((k) => d.contains(k)) &&
        remoteKeywords.any((k) => t.contains(k))) {
      return true;
    }

    return false;
  }
}
