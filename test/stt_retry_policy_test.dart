import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/stt_retry_policy.dart';

void main() {
  group('SttRetryPolicy.shouldRetry', () {
    test('error tidak ada suara / timeout / busy boleh diulang', () {
      expect(SttRetryPolicy.shouldRetry('error_no_match'), isTrue);
      expect(SttRetryPolicy.shouldRetry('error_speech_timeout'), isTrue);
      expect(SttRetryPolicy.shouldRetry('error_busy'), isTrue);
    });

    test('error izin / jaringan tidak diulang otomatis', () {
      expect(SttRetryPolicy.shouldRetry('error_permission'), isFalse);
      expect(SttRetryPolicy.shouldRetry('error_network'), isFalse);
    });
  });

  group('SttRetryPolicy.canRetry', () {
    test('hanya satu kali dengar (tanpa pengulangan otomatis)', () {
      expect(SttRetryPolicy.maxAutoRetries, 1);
      expect(SttRetryPolicy.canRetry(1), isFalse);
      expect(SttRetryPolicy.canRetry(2), isFalse);
    });
  });

  test('retryAnnouncement menyebut percobaan dengan jumlah maksimum', () {
    final message = SttRetryPolicy.retryAnnouncement(2);
    expect(message, contains('2'));
    expect(message, contains('${SttRetryPolicy.maxAutoRetries}'));
  });
}
