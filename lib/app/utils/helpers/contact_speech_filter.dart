import 'speech_result_filter.dart';

/// Helper untuk membersihkan dan mengekstrak nama kontak dari ucapan suara (STT)
/// pengguna tunanetra pada fitur pencarian kontak keluarga/relawan.
class ContactSpeechFilter {
  ContactSpeechFilter._();

  static const List<String> _prefixesAndStopWords = [
    'tolong carikan kontak atas nama',
    'tolong cari kontak atas nama',
    'tolong carikan kontak yang namanya',
    'tolong cari kontak yang namanya',
    'carikan kontak yang namanya',
    'cari kontak yang namanya',
    'kontak yang namanya',
    'yang namanya',
    'namanya',
    'tolong carikan kontak bernama',
    'tolong cari kontak bernama',
    'carikan kontak bernama',
    'cari kontak bernama',
    'kontak bernama',
    'bernama',
    'tolong carikan kontak',
    'tolong cari kontak',
    'tolong hubungi kontak',
    'carikan kontak atas nama',
    'cari kontak atas nama',
    'kontak atas nama',
    'atas nama',
    'tolong hubungkan ke',
    'hubungkan ke',
    'tolong sambungkan ke',
    'sambungkan ke',
    'tolong panggilkan',
    'panggilkan',
    'tolong carikan',
    'tolong hubungi',
    'tolong telepon',
    'tolong telpon',
    'tolong panggil',
    'tolong cari',
    'carikan kontak',
    'carikan nomor',
    'carikan',
    'cari kontak',
    'cari nama',
    'cari nomor',
    'cari',
    'video call sama',
    'video call dengan',
    'video call ke',
    'video call',
    'videocall sama',
    'videocall dengan',
    'videocall ke',
    'videocall',
    'vc sama',
    'vc dengan',
    'vc ke',
    'vc',
    'telepon sama',
    'telepon dengan',
    'telepon ke',
    'telepon',
    'telpon sama',
    'telpon dengan',
    'telpon ke',
    'telpon',
    'hubungi nomor',
    'hubungi',
    'panggil sama',
    'panggil ke',
    'panggil',
    'whatsapp ke',
    'whatsapp sama',
    'whatsapp',
    'wa ke',
    'wa sama',
    'wa',
    'kontak',
    'nama',
    'nomor',
  ];

  static const List<String> _conversationalParticles = [
    ' dong',
    ' ya',
    ' sih',
    ' lah',
    ' deh',
    ' kah',
    ' nih',
    ' tuh',
    ' sekarang',
    ' cepet',
    ' cepat',
  ];

  static const Set<String> _motherSynonyms = {
    'ibu',
    'mama',
    'bunda',
    'mami',
    'umi',
    'emak',
  };

  static const Set<String> _fatherSynonyms = {
    'ayah',
    'bapak',
    'papa',
    'papi',
    'abi',
  };

  static const List<String> _honorificTitles = [
    'dokter',
    'bapak',
    'ibu',
    'mas',
    'mbak',
    'kakak',
    'kak',
    'abang',
    'bang',
    'om',
    'tante',
    'paman',
    'bibi',
    'bude',
    'pakde',
    'kakek',
    'nenek',
    'haji',
    'ustadz',
    'ustazah',
  ];

  static const List<String> _contactScreenEchoes = [
    'halaman kontak',
    'kontak keluarga',
    'kontak darurat',
    'sedang mendengarkan',
    'sebutkan nama',
    'ketuk mikrofon',
    'ketuk tombol',
    'bantuan relawan',
    'telepon whatsapp sekarang',
  ];

  /// Menormalisasi teks (lowercase, ekspansi singkatan umum, pembersihan catatan kurung, hapus tanda baca, trim)
  static String normalize(String text) {
    var lowered = text.toLowerCase();
    // Hapus catatan tambahan dalam kurung (e.g. "(Kantor)", "[Teman]", "(Rumah)")
    lowered = lowered.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    lowered = lowered.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');

    // Normalisasi singkatan umum di Indonesia
    lowered = lowered.replaceAll(RegExp(r'\bdr\b\.?'), 'dokter');
    lowered = lowered.replaceAll(RegExp(r'\bpak\b\.?'), 'bapak');
    lowered = lowered.replaceAll(RegExp(r'\bbu\b\.?'), 'ibu');
    lowered = lowered.replaceAll(RegExp(r'\bhj\b\.?'), 'haji');

    // Ganti karakter non-alfanumerik (termasuk underscore dan simbol) dengan spasi
    final noPunct = lowered.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
    return noPunct.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Menghilangkan sapaan/gelar kehormatan di awal nama untuk pencocokan nama inti
  static String stripTitles(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    while (words.isNotEmpty && _honorificTitles.contains(words.first)) {
      words.removeAt(0);
    }
    return words.join(' ');
  }

  /// Mengekstrak kata kunci nama kontak dari ucapan suara pengguna.
  static String extractContactName(String rawSpeech) {
    var text = normalize(rawSpeech);
    if (text.isEmpty) return '';

    // Cek apakah murni gema TTS aplikasi
    for (final echo in _contactScreenEchoes) {
      if (text == echo) return '';
      if (text.contains(echo)) {
        text = text.replaceAll(echo, '').trim();
      }
    }

    if (SpeechResultFilter.isEchoOfApp(text)) return '';

    // Bersihkan awalan perintah dan stop words
    for (final prefix in _prefixesAndStopWords) {
      if (text.startsWith('$prefix ')) {
        text = text.substring(prefix.length).trim();
      } else if (text == prefix) {
        return '';
      }
    }

    // Bersihkan partikel percakapan di akhir ucapan (e.g. "Cari Ibu dong" -> "ibu")
    for (final particle in _conversationalParticles) {
      if (text.endsWith(particle)) {
        text = text.substring(0, text.length - particle.length).trim();
      }
    }

    // Bersihkan lagi jika masih ada imbuhan 'ke', 'sama', atau 'dengan' di depan nama
    if (text.startsWith('ke ')) {
      text = text.substring(3).trim();
    } else if (text.startsWith('sama ')) {
      text = text.substring(5).trim();
    } else if (text.startsWith('dengan ')) {
      text = text.substring(7).trim();
    }

    return text;
  }

  /// Hitung jarak Levenshtein untuk toleransi sedikit salah dengar STT / salah ketik
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        int minVal = v1[j] + 1;
        if (v0[j + 1] + 1 < minVal) minVal = v0[j + 1] + 1;
        if (v0[j] + cost < minVal) minVal = v0[j] + cost;
        v1[j + 1] = minVal;
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  /// Menghitung skor kecocokan antara ucapan [rawQuery] dan [contactName].
  /// Dirancang spesifik, adaptif budaya, dan toleran terhadap variasi pengucapan:
  /// - 100: Kecocokan persis penuh (Exact Full Match)
  /// - 98: Seluruh kata sama persis (hanya beda urutan)
  /// - 95: Nama inti sama persis (hanya beda sapaan/gelar, misal user ucapkan "Mas Agus", kontak "Agus")
  /// - 92: Sinonim panggilan keluarga (misal user cari "Ibu", kontak di HP "Mama"; atau cari "Ayah", kontak "Papa")
  /// - 85: Query 1 kata ada di dalam nama kontak (misal cari "Budi" pada "Budi Santoso")
  /// - 85: Toleransi variasi penulisan / salah dengar STT 1 huruf (misal "Budy" -> "Budi", "Rakhmat" -> "Rahmat")
  /// - 82: Query inti 1 kata ada di nama kontak inti (misal "Mas Budi" pada "Budi Santoso")
  /// - 78: Awalan kata nama cocok (misal "Slamet" pada "Slametriyadi")
  /// - 75: Seluruh kata query ada di nama kontak yang lebih panjang
  /// - 0: Ditolak jika user mencari nama spesifik/panjang (contoh: cari "Ibu Santi" menolak kontak "Ibu" saja)
  static int matchScore(String rawQuery, String contactName) {
    final cleanQuery = extractContactName(rawQuery);
    final target = cleanQuery.isNotEmpty ? cleanQuery : normalize(rawQuery);
    final name = normalize(contactName);

    if (target.isEmpty || name.isEmpty) return 0;

    // 1. Exact full match (persis sama)
    if (target == name) return 100;

    final qTokens = target.split(' ').where((t) => t.isNotEmpty).toList();
    final nTokens = name.split(' ').where((t) => t.isNotEmpty).toList();

    // 2. Exact match tanpa sapaan/gelar kehormatan (contoh: user ucapkan "Mas Agus", kontak "Agus")
    final coreTarget = stripTitles(target);
    final coreName = stripTitles(name);
    if (coreTarget.isNotEmpty && coreName.isNotEmpty && coreTarget == coreName) {
      return 95;
    }

    // 3. Sinonim panggilan orang tua (Ibu <-> Mama / Bunda, Ayah <-> Papa / Bapak)
    if (qTokens.length == 1 && nTokens.length == 1) {
      final qWord = qTokens.first;
      final nWord = nTokens.first;
      if (_motherSynonyms.contains(qWord) && _motherSynonyms.contains(nWord)) {
        return 92;
      }
      if (_fatherSynonyms.contains(qWord) && _fatherSynonyms.contains(nWord)) {
        return 92;
      }
    }

    // 4. Seluruh kata persis sama (hanya beda urutan kata)
    if (qTokens.length == nTokens.length && qTokens.isNotEmpty) {
      if (qTokens.toSet().length == nTokens.toSet().length &&
          qTokens.every((q) => nTokens.contains(q))) {
        return 98;
      }
    }

    // 5. Jika kontak hanya 1 kata/hanya sapaan, namun query user spesifik/panjang:
    // Contoh: User cari "Ibu Santi", kontak hanya "Ibu"
    // Ditolak (skor 0) agar kontak umum tidak salah terpanggil saat mencari orang spesifik.
    final coreTargetTokens = coreTarget.split(' ').where((t) => t.isNotEmpty).toList();
    final coreNameTokens = coreName.split(' ').where((t) => t.isNotEmpty).toList();
    if (coreTargetTokens.length > 1 && coreNameTokens.length <= 1) {
      return 0; // Ditolak
    }
    if (nTokens.length == 1 && qTokens.length > 1 && !coreTargetTokens.contains(nTokens.first)) {
      return 0; // Ditolak
    }

    // 6. Query 1 kata ada di nama kontak
    // Contoh: User cari "Budi", kontak "Budi Santoso"
    if (qTokens.length == 1) {
      final singleQ = qTokens.first;
      if (nTokens.contains(singleQ)) {
        return 80;
      }
    }

    // 7. Query inti 1 kata ada di nama kontak inti
    // Contoh: User cari "Mas Budi", kontak "Budi Santoso"
    if (coreTargetTokens.length == 1 && coreNameTokens.contains(coreTargetTokens.first)) {
      return 82;
    }

    // 8. Toleransi fonetik/salah dengar STT 1 huruf (Levenshtein distance == 1)
    if (qTokens.length == 1) {
      final singleQ = qTokens.first;
      if (singleQ.length >= 4) {
        for (final n in nTokens) {
          if (n.length >= 4 && _levenshtein(singleQ, n) == 1) {
            return 85;
          }
        }
      }
    }

    // 9. Kecocokan awalan kata nama (contoh: user cari "Slamet", kontak "Slametriyadi")
    if (target.length >= 3) {
      for (final n in nTokens) {
        if (n.startsWith(target)) {
          return 78;
        }
      }
    }
    if (coreTarget.length >= 3) {
      for (final n in coreNameTokens) {
        if (n.startsWith(coreTarget)) {
          return 76;
        }
      }
    }

    // 10. Jika seluruh kata query ada di nama kontak yang lebih panjang
    // Contoh: User cari "Budi Santoso", kontak "Budi Santoso Wijaya"
    int matched = 0;
    for (final q in qTokens) {
      if (nTokens.contains(q)) {
        matched++;
      }
    }
    if (matched == qTokens.length && qTokens.isNotEmpty) {
      return 75;
    }

    // 11. Jika seluruh kata inti query ada di nama kontak inti
    int coreMatched = 0;
    for (final q in coreTargetTokens) {
      if (coreNameTokens.contains(q)) {
        coreMatched++;
      }
    }
    if (coreMatched == coreTargetTokens.length && coreTargetTokens.isNotEmpty) {
      return 74;
    }

    return 0;
  }

  /// Menentukan apakah nama kontak [contactName] cocok dengan kata kunci pencarian [query].
  static bool isMatch(String query, String contactName) {
    return matchScore(query, contactName) >= 60;
  }
}
