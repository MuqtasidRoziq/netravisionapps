/// Konfigurasi Terpusat NetraVision (Production & Development).
///
/// PERINGATAN KEAMANAN:
/// - Jangan pernah meletakkan API Secret / Private Key (seperti LiveKit API Secret) di sini.
/// - Kredensial rahasia (LiveKit Secret) tersimpan aman di Supabase Edge Function Secrets.
/// - Pengaturan di bawah ini dapat ditimpa saat compile/build menggunakan flag:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  /// URL Project Supabase Cloud
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://sipxavvrhgvlbqkazghv.supabase.co',
  );

  /// Anon / Publishable Key Supabase (Aman di client karena dilindungi Row Level Security)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_70z0vuV78vUWMDXud-DTRQ_qVXnfbTG',
  );

  /// URL LiveKit Cloud Server untuk streaming WebRTC
  static const String livekitCloudUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://netravision-ibcqale8.livekit.cloud',
  );

  /// Endpoint pembuatan token LiveKit yang aman di cloud
  static String get livekitTokenEndpoint =>
      '$supabaseUrl/functions/v1/generate-livekit-token';

  /// URL Web Portal Pendamping Relawan resmi di Vercel
  static const String webPortalUrl = String.fromEnvironment(
    'WEB_PORTAL_URL',
    defaultValue: 'https://netravision-portal.vercel.app',
  );
}
