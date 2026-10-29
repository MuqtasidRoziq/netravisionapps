/// Filter hasil STT (speech-to-text) agar suara/gema aplikasi sendiri tidak
/// dianggap sebagai ucapan pengguna.
///
/// Masalah yang diatasi: kadang mikrofon mengenali kembali teks yang barusan
/// dibacakan TTS (sapaan, arahan navigasi, atau pengumuman koordinat) sehingga
/// aplikasi "mendeteksi sendiri" dan langsung membuat rute ke tempat acak.
class SpeechResultFilter {
  SpeechResultFilter._();

  /// Frasa milik aplikasi yang tidak boleh dianggap perintah pengguna.
  static const List<String> _appPhrases = <String>[
    'titik koordinat',
    'latitude',
    'longitude',
    'menghadap ke arah',
    'silakan sebutkan tujuan',
    'silakan ucapkan tujuan',
    'sedang mendengarkan',
    'ketuk mikrofon',
    'ketuk tombol mikrofon',
    'ucapkan nama barang',
    'nama barang',
    'halaman cari barang',
    'mode jalan aktif',
    'sisa jarak',
    'anda telah tiba',
    'menunggu sinyal gps',
    'membuat rute',
    'arahan navigasi',
  ];

  /// Buang tanda baca, kurangi spasi, dan kecilkan huruf agar perbandingan
  /// tidak terpecah oleh variasi penulisan pengenalan suara.
  static String normalize(String input) {
    final lowered = input.toLowerCase();
    final noPunct = lowered.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return noPunct.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// True bila [recognized] mengandung gema TTS/pengumuman aplikasi.
  static bool isEchoOfApp(String recognized) {
    final text = normalize(recognized);
    if (text.isEmpty) return false;

    // Gema arahan navigasi: "Menuju [Tempat], [X] meter"
    if (text.contains('menuju') &&
        (text.contains('meter') || text.contains('membuat rute') || text.contains('sisa jarak'))) {
      return true;
    }

    for (final phrase in _appPhrases) {
      if (text == phrase) return true;
      if (text.contains(phrase)) {
        // Cek apakah setelah membuang frasa aplikasi, masih ada kata substansial
        final stripped = text.replaceAll(phrase, '').trim();
        if (stripped.length < 2) return true;
      }
    }
    return false;
  }

  /// True bila [recognized] layak diteruskan sebagai perintah tujuan:
  /// cukup panjang, bukan angka murni, dan bukan gema aplikasi.
  static bool isUsable(String recognized, {int minChars = 3}) {
    final text = recognized.trim();
    if (text.length < minChars) return false;
    if (RegExp(r'^[\d\s.,-]+$').hasMatch(text)) return false;
    if (isEchoOfApp(text)) return false;
    return true;
  }
}
