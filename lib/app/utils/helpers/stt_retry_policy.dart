/// Kebijakan percobaan ulang otomatis untuk sesi dengar mikrofon (STT).
///
/// Dipakai saat mic "tidak mau mendengar": bila gagal, sesi dijalankan otomatis
/// sebelum kembali ke pengguna. Nilai [maxAutoRetries] sengaja kecil.
class SttRetryPolicy {
  SttRetryPolicy._();

  /// Jumlah percobaan maksimum dalam satu putaran dengar.
  ///
  /// **1 = dengarkan sekali saja.** Bila tidak ada hasil, pengguna diminta
  /// mengetuk mikrofon lagi — menghindari pengulangan otomatis berulang yang
  /// membingungkan/melelahkan pengguna tunanetra.
  static const int maxAutoRetries = 1;

  /// Jeda antar percobaan ulang (memberi waktu mesin pengenalan pulih).
  static const Duration retryDelay = Duration(milliseconds: 700);

  /// Error mana yang layak dicoba ulang otomatis.
  ///
  /// - `error_no_match` / `error_speech_timeout`: tidak ada suara yang cocok
  ///   (umumnya karena sedikit lagi bicara atau terlalu cepat senyap).
  /// - `error_busy`: pengenalan masih memproses sesi sebelumnya (race saat
  ///   stop→listen beruntun).
  static bool shouldRetry(String errorMsg) {
    return errorMsg.contains('error_no_match') ||
        errorMsg.contains('error_speech_timeout') ||
        errorMsg.contains('error_busy');
  }

  /// Percobaan ke-[attempt] (mulai dari 1) masih boleh diulang?
  static bool canRetry(int attempt) => attempt < maxAutoRetries;

  /// Pesan singkat diumumkan TTS sebelum percobaan ulang.
  static String retryAnnouncement(int nextAttempt) =>
      'Belum terdengar, percobaan $nextAttempt dari $maxAutoRetries.';
}

/// Fase sesi dengar tujuan — satu sumber kebenaran untuk status mikrofon
/// agar flag `isListeningDestination`, status plugin, dan hasil STT tidak
/// saling mendahului (penyebab mic kadang dianggap "tidak mau mendengar").
enum DestinationSpeechPhase {
  /// Tidak ada sesi.
  idle,

  /// Sesi disiapkan (prompt TTS / menunggu recognizer lama dilepas).
  preparing,

  /// Mikrofon sungguhan sedang aktif.
  listening,

  /// Sesi berakhir menunggu hasil akhir dari plugin (grace period).
  draining,

  /// Hasil diterima, sedang membuat rute / mencari tempat.
  processing,

  /// Sesi gagal; menunggu keputusan retry/menyerah.
  error,
}
