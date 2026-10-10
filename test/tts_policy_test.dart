import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/tts_policy.dart';

void main() {
  const debounce = Duration(milliseconds: 2000);

  group('TtsPolicy.decide', () {
    test('permintaan mendesak selalu menyerobot (preempt)', () {
      expect(
        TtsPolicy.decide(
          text: 'Awas, ada mobil di depan!',
          urgent: true,
          isSpeaking: true,
          lastSpoken: 'Ada kursi di depan',
          sinceLast: Duration.zero,
          debounce: debounce,
        ),
        TtsAction.preempt,
      );
    });

    test('teks sama dalam masa debounce diabaikan', () {
      expect(
        TtsPolicy.decide(
          text: 'Ada kursi di depan',
          urgent: false,
          isSpeaking: false,
          lastSpoken: 'Ada kursi di depan',
          sinceLast: const Duration(milliseconds: 500),
          debounce: debounce,
        ),
        TtsAction.ignore,
      );
    });

    test('teks sama setelah debounce lewat tetap diucapkan', () {
      expect(
        TtsPolicy.decide(
          text: 'Ada kursi di depan',
          urgent: false,
          isSpeaking: false,
          lastSpoken: 'Ada kursi di depan',
          sinceLast: const Duration(milliseconds: 2500),
          debounce: debounce,
        ),
        TtsAction.speakNow,
      );
    });

    test('saat sedang bicara, kalimat biasa disimpan sebagai pending', () {
      expect(
        TtsPolicy.decide(
          text: 'Ada meja di samping kiri, dekat di depan Anda',
          urgent: false,
          isSpeaking: true,
          lastSpoken: 'Ada kursi di depan',
          sinceLast: const Duration(milliseconds: 800),
          debounce: debounce,
        ),
        TtsAction.enqueue,
      );
    });

    test('saat idle, kalimat baru langsung diucapkan', () {
      expect(
        TtsPolicy.decide(
          text: 'Ada meja di depan',
          urgent: false,
          isSpeaking: false,
          lastSpoken: 'Ada kursi di depan',
          sinceLast: const Duration(milliseconds: 800),
          debounce: debounce,
        ),
        TtsAction.speakNow,
      );
    });
  });
}
