/// Aksi yang harus diambil [TtsService] untuk satu permintaan ucapan.
enum TtsAction {
  /// Ucapkan sekarang (tidak ada ucapan yang sedang berjalan).
  speakNow,

  /// Hentikan ucapan yang sedang jalan lalu ucapkan segera (permintaan
  /// mendesak, mis. peringatan bahaya atau ketukan pengguna).
  preempt,

  /// Sedang berbicara; simpan sebagai pesan tunggu terbaru dan ucapkan
  /// setelah ucapan saat ini selesai.
  enqueue,

  /// Abaikan (teks sama masih dalam masa debounce).
  ignore,
}

/// Keputusan murni (tanpa platform) untuk anti-potong TTS.
///
/// Dipisah dari [TtsService] agar mudah diuji unit.
class TtsPolicy {
  TtsPolicy._();

  static TtsAction decide({
    required String text,
    required bool urgent,
    required bool isSpeaking,
    required String lastSpoken,
    required Duration sinceLast,
    required Duration debounce,
  }) {
    // Permintaan mendesak selalu menyerobot demi keselamatan.
    if (urgent) return TtsAction.preempt;

    // Teks sama dan belum lewat cooldown → jangan ulang.
    if (text == lastSpoken && sinceLast < debounce) return TtsAction.ignore;

    // Masih berbicara → tuntaskan dulu, simpan yang terbaru untuk nanti.
    if (isSpeaking) return TtsAction.enqueue;

    return TtsAction.speakNow;
  }
}
