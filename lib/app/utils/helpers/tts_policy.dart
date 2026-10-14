/// Tingkat prioritas ucapan [TtsService].
///
/// Urutan (dari rendah ke tinggi) menentukan siapa yang boleh memotong siapa:
/// - [normal]     : info biasa (objek, status). Tidak pernah memotong.
/// - [navigation] : arahan turn-by-turn. Boleh memotong info biasa, tidak
///                  memotong bahaya. Arahan sesama navigasi tidak saling potong.
/// - [danger]     : peringatan bahaya dekat. Menyerobot navigasi demi
///                  keselamatan, tetapi tidak menyerobot [sos].
/// - [sos]        : darurat. Selalu menyerobot.
enum TtsPriority { normal, navigation, danger, sos }

/// Aksi yang harus diambil [TtsService] untuk satu permintaan ucapan.
enum TtsAction {
  /// Ucapkan sekarang (tidak ada ucapan yang sedang berjalan).
  speakNow,

  /// Hentikan ucapan yang sedang jalan lalu ucapkan segera (prioritas lebih
  /// tinggi menyerobot yang sedang berbicara).
  preempt,

  /// Sedang berbicara; simpan sebagai pesan tunggu (prioritas tertinggi yang
  /// menang) dan ucapkan setelah ucapan saat ini selesai.
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
    required TtsPriority priority,
    required TtsPriority currentPriority,
    required bool isSpeaking,
    required String lastSpoken,
    required Duration sinceLast,
    required Duration debounce,
  }) {
    // Teks sama dan belum lewat cooldown → jangan ulang.
    if (text == lastSpoken && sinceLast < debounce) return TtsAction.ignore;

    // Tidak ada yang berbicara → langsung ucapkan.
    if (!isSpeaking) return TtsAction.speakNow;

    switch (priority) {
      case TtsPriority.sos:
        return TtsAction.preempt;
      case TtsPriority.danger:
        // Bahaya menyerobot navigasi/info, tetapi tidak menyerobot SOS.
        return currentPriority == TtsPriority.sos
            ? TtsAction.enqueue
            : TtsAction.preempt;
      case TtsPriority.navigation:
        // Arahan navigasi hanya memotong info biasa; tidak memotong arahan
        // navigasi lain, bahaya, atau SOS (mencegah "tabrak-menabrak").
        return currentPriority.index >= TtsPriority.navigation.index
            ? TtsAction.enqueue
            : TtsAction.preempt;
      case TtsPriority.normal:
        return TtsAction.enqueue;
    }
  }
}
