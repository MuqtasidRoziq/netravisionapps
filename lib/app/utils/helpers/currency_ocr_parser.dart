/// Parser deterministik untuk mengenali nominal uang kertas Rupiah
/// dari teks hasil OCR (Google ML Kit Text Recognition).
///
/// Fungsi murni (pure function) tanpa dependency hardware agar dapat diuji unit 100%.
class CurrencyOcrParser {
  CurrencyOcrParser._();

  // Pola teks kata resmi pada uang kertas Rupiah (prioritas urutan nominal besar ke kecil)
  static final List<({RegExp regex, String nominal})> _wordPatterns = [
    (
      regex: RegExp(r'SERATUS\s+RIBU', caseSensitive: false),
      nominal: '100000',
    ),
    (
      regex: RegExp(r'TUJUH\s+PULUH\s+LIMA\s+RIBU', caseSensitive: false),
      nominal: '75000',
    ),
    (
      regex: RegExp(r'LIMA\s+PULUH\s+RIBU', caseSensitive: false),
      nominal: '50000',
    ),
    (
      regex: RegExp(r'DUA\s+PULUH\s+RIBU', caseSensitive: false),
      nominal: '20000',
    ),
    (
      regex: RegExp(r'SEPULUH\s+RIBU', caseSensitive: false),
      nominal: '10000',
    ),
    (
      regex: RegExp(r'LIMA\s+RIBU', caseSensitive: false),
      nominal: '5000',
    ),
    (
      regex: RegExp(r'DUA\s+RIBU', caseSensitive: false),
      nominal: '2000',
    ),
    (
      regex: RegExp(r'SE(?:RIBU|SATU\s+RIBU)', caseSensitive: false),
      nominal: '1000',
    ),
  ];

  // Pola angka nominal uang kertas Rupiah
  // PENTING: Urutan wajib dari nominal digit terbanyak (6 digit) ke terkecil (4 digit)
  // agar "20000" tidak terpangkas menjadi "2000".
  static final List<({RegExp regex, String nominal})> _digitPatterns = [
    // 100.000 / 100000
    (
      regex: RegExp(r'\b100[.,\s]?000\b'),
      nominal: '100000',
    ),
    // 75.000 / 75000
    (
      regex: RegExp(r'\b75[.,\s]?000\b'),
      nominal: '75000',
    ),
    // 50.000 / 50000
    (
      regex: RegExp(r'\b50[.,\s]?000\b'),
      nominal: '50000',
    ),
    // 20.000 / 20000
    (
      regex: RegExp(r'\b20[.,\s]?000\b'),
      nominal: '20000',
    ),
    // 10.000 / 10000
    (
      regex: RegExp(r'\b10[.,\s]?000\b'),
      nominal: '10000',
    ),
    // 5.000 / 5000
    (
      regex: RegExp(r'\b5[.,\s]?000\b'),
      nominal: '5000',
    ),
    // 2.000 / 2000
    (
      regex: RegExp(r'\b2[.,\s]?000\b'),
      nominal: '2000',
    ),
    // 1.000 / 1000
    (
      regex: RegExp(r'\b1[.,\s]?000\b'),
      nominal: '1000',
    ),
  ];

  /// Mengekstrak nominal Rupiah resmi ('1000', '2000', '5000', dst)
  /// dari rangkaian teks yang diekstrak oleh OCR.
  ///
  /// Mengembalikan `null` jika tidak ditemukan teks atau angka nominal Rupiah yang sah.
  static String? extractNominal(String ocrText) {
    if (ocrText.trim().isEmpty) return null;

    final normalized = ocrText.replaceAll('\n', ' ').trim();

    // 1. Prioritas Utama: Kata nominal tertulis (mis. "DUA RIBU RUPIAH", "LIMA PULUH RIBU")
    // Teks tulisan sangat kuat dan tidak rentan salah deteksi noise.
    for (final pattern in _wordPatterns) {
      if (pattern.regex.hasMatch(normalized)) {
        return pattern.nominal;
      }
    }

    // 2. Prioritas Kedua: Angka nominal tertera (mis. "2000", "2.000", "50000", "50.000")
    for (final pattern in _digitPatterns) {
      if (pattern.regex.hasMatch(normalized)) {
        return pattern.nominal;
      }
    }

    // 3. Toleransi Khusus OCR parsial: jika ada angka "2000" yang sedikit terpotong atau "Rp 2000"
    final cleanDigits = normalized.replaceAll(RegExp(r'[^0-9]'), ' ');
    final tokens = cleanDigits.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final token in tokens) {
      switch (token) {
        case '100000':
          return '100000';
        case '75000':
          return '75000';
        case '50000':
          return '50000';
        case '20000':
          return '20000';
        case '10000':
          return '10000';
        case '5000':
          return '5000';
        case '2000':
          return '2000';
        case '1000':
          return '1000';
      }
    }

    return null;
  }
}
