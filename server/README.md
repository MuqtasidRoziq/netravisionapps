# NetraVision Bantuan Visual V2 — Pilot Server

Server backend ringan berbasis Dart (`dart:io` HttpServer & WebSocketTransformer) untuk mendukung pilot Bantuan Visual NetraVision V2.

## Fitur Utama

1. **Autentikasi & Peran Sesi**: Pengguna Tunanetra (`user`) dan Pendamping Relawan (`companion`) dengan scoping komunitas pilot (`communityId`).
2. **Ketersediaan & Presence**: Status aktif pendamping dengan heartbeat dan deteksi kedaluwarsa otomatis (30 detik).
3. **Penyaluran Permintaan (Matching)**: Mencegah permintaan aktif ganda per pengguna, membawa konteks tugas minimum (`taskType`, `taskTarget`, label belum diverifikasi).
4. **Penerimaan Atomik (Atomic Claim)**: Menjamin tepat satu pendamping yang berhasil mengambil sesi ketika dua pendamping menekan "Terima" secara bersamaan. Pendamping kedua menerima respons `409 Conflict`.
5. **Penerbitan Token LiveKit**: Membuat token JWT HS256 berizin minimum dan bertenggat waktu terbatas untuk video/audio streaming dua arah.
6. **Sinyal Cuplikan Sementara (Snapshot)**: Menyampaikan persetujuan dan sinyal cuplikan frame dari pendamping ke pengguna secara real-time.
7. **Timeout Terbatas**: Permintaan kedaluwarsa otomatis setelah 45 detik jika tidak ada pendamping yang tersedia, dengan pesan yang jujur kepada pengguna tanpa estimasi palsu.

## Cara Menjalankan

Dari root repository `netravisionapps`:

```bash
dart run server/bin/server.dart
```

Atau tentukan variabel lingkungan:
```bash
$env:PORT="8080"
$env:LIVEKIT_URL="wss://pilot.netravision.internal"
dart run server/bin/server.dart
```

## Menjalankan Pengujian Unit Server

```bash
dart test test/pilot_server_test.dart
```
