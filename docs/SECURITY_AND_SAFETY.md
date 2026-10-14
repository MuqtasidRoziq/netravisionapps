# Keselamatan dan keamanan NetraVision

## Batas kemampuan

NetraVision adalah alat bantu informasi visual. Ia bukan pengganti tongkat,
orientasi dan mobilitas, penilaian pengguna, pendamping manusia, atau layanan
darurat. Deteksi dan navigasi dapat keliru atau terlambat; pengguna tidak boleh
memakai aplikasi ini sebagai satu-satunya dasar untuk menyeberang jalan,
menghindari kendaraan, atau mengambil keputusan medis/darurat.

Tombol bantuan mendesak mengirim permintaan ke relawan/kontak tepercaya. Tombol
ini **bukan** panggilan ke layanan darurat dan tidak menjamin ada orang yang
menjawab. Simpan serta uji setidaknya satu kontak tepercaya sebelum memakai
fitur tersebut.

## Checklist sebelum cloud production

1. Gunakan Supabase Auth. Jangan pernah memakai anon/publishable key sebagai
   identitas pengguna atau mengirim `SUPABASE_USER_JWT` sebagai nilai build
   permanen. Ambil dan perbarui sesi pengguna saat runtime lewat mekanisme
   autentikasi yang sesuai.
2. Aktifkan RLS pada `help_requests`. Pengguna hanya boleh membuat dan membaca
   request miliknya; relawan hanya boleh membaca request yang ditugaskan untuk
   komunitasnya. Kolom `access_key`, `user_token`, dan `companion_token` tidak
   boleh dapat dibaca/ditulis langsung oleh aplikasi client.
3. Pindahkan pembuatan request, assignment relawan, dan penerbitan token
   LiveKit ke Edge Function/server yang memverifikasi identitas dan kepemilikan
   request. Token harus scoped ke satu room dan berumur pendek.
4. Set secret `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, `CORS_ALLOWED_ORIGIN`, dan `ALERT_FUNCTION_SECRET` di
   secret manager. Jangan commit secret ke repository.
5. Deploy Edge Function dengan JWT verification aktif. Function token juga
   melakukan pemeriksaan user dan menolak anon key, sebagai lapisan tambahan.
6. Jangan mengekspos `server/` pilot ke internet. Secara default server kini
   hanya bind ke loopback. `PILOT_ALLOW_NETWORK=true` hanya untuk uji jaringan
   terkontrol, bukan production.

## Pengujian sebelum rilis

- Uji TalkBack dengan pengguna tunanetra, headphone, suara lingkungan ramai,
  font besar, serta mode pesawat/jaringan lambat.
- Uji model dengan data lapangan yang tidak masuk training: gelap, silau,
  kamera miring, objek terpotong, trotoar rusak, dan uang lusuh.
- Pastikan aplikasi mengatakan kegagalan koneksi secara jujur; jangan pernah
  membacakan "terhubung" sampai kanal media benar-benar aktif.
- Uji alur kontak tepercaya dan pembatalan bantuan tanpa mengandalkan
  Accessibility Service.
