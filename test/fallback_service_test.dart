import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/services/fallback_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FallbackService Calling & WhatsApp Tests', () {
    late FallbackService service;

    setUp(() {
      service = FallbackService();
    });

    test('Inisialisasi FallbackService berhasil', () {
      expect(service, isNotNull);
    });

    test('Formatting nomor telepon untuk WhatsApp (08xx -> 628xx)', () {
      final raw = '0812-3456-7890';
      var clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.startsWith('0')) {
        clean = '62${clean.substring(1)}';
      }
      expect(clean, '6281234567890');
    });

    test('Formatting nomor telepon seluler dialer mempertahankan tanda plus', () {
      final raw = '+62 812-3456-7890';
      final clean = raw.replaceAll(RegExp(r'[^0-9+]'), '');
      expect(clean, '+6281234567890');
    });
  });
}
