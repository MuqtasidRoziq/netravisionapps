import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/tts_policy.dart';

void main() {
  const debounce = Duration(milliseconds: 2000);

  TtsAction decide({
    required String text,
    required TtsPriority priority,
    TtsPriority currentPriority = TtsPriority.normal,
    bool isSpeaking = true,
    String lastSpoken = '',
    Duration sinceLast = const Duration(milliseconds: 800),
  }) {
    return TtsPolicy.decide(
      text: text,
      priority: priority,
      currentPriority: currentPriority,
      isSpeaking: isSpeaking,
      lastSpoken: lastSpoken,
      sinceLast: sinceLast,
      debounce: debounce,
    );
  }

  group('TtsPolicy.decide', () {
    test('teks sama dalam masa debounce diabaikan walau bahaya', () {
      expect(
        decide(
          text: 'Awas, ada mobil di depan!',
          priority: TtsPriority.danger,
          lastSpoken: 'Awas, ada mobil di depan!',
          sinceLast: const Duration(milliseconds: 500),
        ),
        TtsAction.ignore,
      );
    });

    test('teks sama setelah debounce lewat tetap diucapkan', () {
      expect(
        decide(
          text: 'Ada kursi di depan',
          priority: TtsPriority.normal,
          isSpeaking: false,
          lastSpoken: 'Ada kursi di depan',
          sinceLast: const Duration(milliseconds: 2500),
        ),
        TtsAction.speakNow,
      );
    });

    test('saat idle, kalimat baru langsung diucapkan', () {
      expect(
        decide(
          text: 'Ada meja di depan',
          priority: TtsPriority.normal,
          isSpeaking: false,
          lastSpoken: 'Ada kursi di depan',
        ),
        TtsAction.speakNow,
      );
    });

    test('info biasa saat sedang bicara disimpan sebagai pending', () {
      expect(
        decide(
          text: 'Ada meja di samping kiri',
          priority: TtsPriority.normal,
          currentPriority: TtsPriority.normal,
        ),
        TtsAction.enqueue,
      );
    });

    test('bahaya menyerobot arahan navigasi (bahaya dulu)', () {
      expect(
        decide(
          text: 'Awas, ada mobil di depan!',
          priority: TtsPriority.danger,
          currentPriority: TtsPriority.navigation,
        ),
        TtsAction.preempt,
      );
    });

    test('bahaya tidak menyerobot SOS', () {
      expect(
        decide(
          text: 'Awas!',
          priority: TtsPriority.danger,
          currentPriority: TtsPriority.sos,
        ),
        TtsAction.enqueue,
      );
    });

    test('SOS selalu menyerobot', () {
      expect(
        decide(
          text: 'Menghubungkan panggilan darurat',
          priority: TtsPriority.sos,
          currentPriority: TtsPriority.danger,
        ),
        TtsAction.preempt,
      );
    });

    test('arahan navigasi menyerobot info biasa', () {
      expect(
        decide(
          text: 'Belok kanan di depan',
          priority: TtsPriority.navigation,
          currentPriority: TtsPriority.normal,
        ),
        TtsAction.preempt,
      );
    });

    test('arahan navigasi tidak saling memotong (anti tabrak-menabrak)', () {
      expect(
        decide(
          text: 'Lurus terus 50 meter',
          priority: TtsPriority.navigation,
          currentPriority: TtsPriority.navigation,
        ),
        TtsAction.enqueue,
      );
    });
  });
}
