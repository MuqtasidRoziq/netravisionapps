# Konsep Indoor Assist NetraVision

## Tujuan

Indoor Assist adalah **pendamping kewaspadaan**, bukan pengganti tongkat,
anjing pemandu, pendamping manusia, atau pelatihan orientasi dan mobilitas.
Fitur tidak boleh menyatakan jalur aman hanya karena kamera tidak menemukan
objek.

## Pengalaman utama

### 1. Fokus Keselamatan (selalu aktif)

- Kamera memantau objek yang dikenali pada koridor tengah di depan pengguna.
- Audio otomatis hanya keluar untuk satu rintangan terpenting yang dekat.
- Peringatan biasa harus stabil pada dua frame agar false alarm satu frame
  tidak dibacakan.
- Peringatan kritis memotong ucapan biasa.
- Aplikasi menyebut posisi relatif, tetapi tidak menyuruh berbelok karena sisi
  tujuan belum terbukti bebas.
- Contoh: `Berhenti. Ada kursi sangat dekat di depan. Periksa dengan tongkat
  sebelum melangkah.`

### 2. Jelajahi Sekitar (sesuai permintaan)

- Ketuk layar untuk mendengar maksimal tiga objek yang paling relevan.
- Objek disebut dengan arah kiri, depan, atau kanan dan jarak kualitatif.
- Jika tidak ada hasil, ucapan yang benar adalah `belum ada objek yang
  dikenali`, bukan `jalur aman`.

### 3. Cari Tujuan (pengembangan berikutnya)

Target yang berguna antara lain pintu, toilet, lift, kursi, meja resepsionis,
dan nomor ruangan. Nomor ruangan membutuhkan OCR. Pintu, lift, serta tangga
membutuhkan model khusus karena tidak ada dalam model COCO yang dipakai saat
ini.

### 4. Navigasi Gedung (pengembangan lanjutan)

Navigasi ke ruangan yang tidak terlihat kamera memerlukan peta gedung dan
lokalisasi seperti visual marker, BLE, Wi-Fi, atau visual-inertial odometry.
Object detector saja tidak dapat menyediakan navigasi gedung.

## Kemampuan versi 1.1.0

- Menilai objek yang dikenali berdasarkan kedekatan kualitatif, irisan dengan
  koridor jalan, keyakinan model, dan kestabilan antarframe.
- Memprioritaskan objek mobilitas seperti orang, kursi, sofa, meja makan,
  tempat tidur, tanaman pot, koper, tas, hewan, dan beberapa benda lantai.
- Alarm suara singkat dan getaran burst terbatas; tidak ada getaran kontinu.
- Ringkasan sekitar maksimal tiga objek saat layar diketuk.
- Menghapus status/getaran basi setelah frame kosong terkonfirmasi.
- Tidak menghitung atau membacakan meter semu dari ukuran bounding box.
- Seluruh inferensi inti tetap on-device.

## Batas kemampuan saat ini

Model `assets/models/indoor/indoor_objects.tflite` adalah detektor COCO 80
kelas. Model ini **belum mendeteksi** pintu, tangga naik/turun, lift, dinding,
kaca, lubang/drop-off, benda tipis, atau ruang bebas. Kamera RGB tunggal juga
tidak memberikan jarak metrik yang andal. Karena itu fitur saat ini belum boleh
dipasarkan sebagai navigasi indoor lengkap atau sistem keselamatan mandiri.

Tahap teknis berikutnya adalah depth/free-space yang memiliki confidence,
tracking/TTC, pemeriksaan arah kamera, serta model khusus dari sudut kamera
dada/handheld pada bangunan Indonesia.

## Dasar riset

- Uji klinis peringatan tabrakan berbasis kamera pada 31 pengguna tunanetra
  menurunkan kontak dengan rintangan sekitar 37% ketika dipakai bersama alat
  mobilitas biasa: <https://pubmed.ncbi.nlm.nih.gov/34292298/>
- Co-design indoor menekankan mode focused/exploratory dan menemukan getaran
  konstan menambah beban: <https://rehab.jmir.org/2026/1/e81347>
- Pedoman Android menyarankan haptik yang hemat, konsisten, dan tidak
  berlebihan:
  <https://developer.android.com/develop/ui/views/haptics/haptics-principles>
- ARCore Depth mempunyai batas perangkat dan lingkungan; depth tidak boleh
  dianggap selalu tersedia atau selalu benar:
  <https://developers.google.com/ar/develop/depth>
- NavCog3 menunjukkan navigasi gedung skala besar memerlukan peta, landmark,
  point of interest, dan lokalisasi:
  <https://publications.ri.cmu.edu/navcog3-evaluation-smartphone-based-blind-indoor-navigation-assistant-semantic-features-large-scale-environment>

## Validasi yang wajib sebelum klaim lapangan

1. Uji rekaman offline untuk setiap kelas, posisi, ukuran, dan cahaya.
2. Uji lorong terkendali dengan pendamping keselamatan.
3. Uji bersama pengguna tunanetra dan spesialis orientasi-mobilitas, selalu
   menggunakan tongkat/alat utama pengguna.
4. Ukur miss rate bahaya, false alarm per jam, latensi alert p50/p95, kontak
   fisik, intervensi pendamping, beban mental, baterai, dan temperatur.
5. Uji perangkat berbeda serta kondisi gelap, silau, kaca, keramaian, objek
   tipis, objek menggantung, tangga, dan drop-off.

Build dan unit test hanya membuktikan software berjalan sesuai aturan; klaim
`benar-benar berguna` memerlukan pengujian langsung bersama pengguna sasaran.
