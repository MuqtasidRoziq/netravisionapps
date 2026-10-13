import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/utils/helpers/currency_ocr_parser.dart';

void main() {
  group('CurrencyOcrParser.extractNominal', () {
    test('ekstraksi angka 2000 dengan benar', () {
      expect(CurrencyOcrParser.extractNominal('2000'), '2000');
      expect(CurrencyOcrParser.extractNominal('2.000'), '2000');
      expect(CurrencyOcrParser.extractNominal('BANK INDONESIA 2000'), '2000');
      expect(CurrencyOcrParser.extractNominal('DUA RIBU RUPIAH 2000'), '2000');
    });

    test('ekstraksi kata tertulis DUA RIBU', () {
      expect(CurrencyOcrParser.extractNominal('DUA RIBU RUPIAH'), '2000');
      expect(CurrencyOcrParser.extractNominal('NEGARA KESATUAN REPUBLIK INDONESIA DUA RIBU RUPIAH'), '2000');
    });

    test('membedakan 2000 dan 20000 secara tegas (tidak tertukar)', () {
      expect(CurrencyOcrParser.extractNominal('20000'), '20000');
      expect(CurrencyOcrParser.extractNominal('20.000'), '20000');
      expect(CurrencyOcrParser.extractNominal('DUA PULUH RIBU RUPIAH'), '20000');
      expect(CurrencyOcrParser.extractNominal('2000'), '2000');
    });

    test('membedakan 5000 dan 50000 secara tegas', () {
      expect(CurrencyOcrParser.extractNominal('50000'), '50000');
      expect(CurrencyOcrParser.extractNominal('50.000'), '50000');
      expect(CurrencyOcrParser.extractNominal('LIMA PULUH RIBU RUPIAH'), '50000');
      expect(CurrencyOcrParser.extractNominal('5000'), '5000');
      expect(CurrencyOcrParser.extractNominal('5.000'), '5000');
      expect(CurrencyOcrParser.extractNominal('LIMA RIBU RUPIAH'), '5000');
    });

    test('ekstraksi 100000, 75000, 10000, 1000', () {
      expect(CurrencyOcrParser.extractNominal('100000'), '100000');
      expect(CurrencyOcrParser.extractNominal('SERATUS RIBU RUPIAH'), '100000');
      expect(CurrencyOcrParser.extractNominal('75000'), '75000');
      expect(CurrencyOcrParser.extractNominal('10000'), '10000');
      expect(CurrencyOcrParser.extractNominal('SEPULUH RIBU RUPIAH'), '10000');
      expect(CurrencyOcrParser.extractNominal('1000'), '1000');
      expect(CurrencyOcrParser.extractNominal('SERIBU RUPIAH'), '1000');
    });

    test('menolak teks keyboard, laptop, dan noise acak', () {
      expect(CurrencyOcrParser.extractNominal(''), isNull);
      expect(CurrencyOcrParser.extractNominal('ASUS ROG Intel Core i7'), isNull);
      expect(CurrencyOcrParser.extractNominal('QWERTYUIOP ASDFGHJKL'), isNull);
      expect(CurrencyOcrParser.extractNominal('Tahun 2024'), isNull);
      expect(CurrencyOcrParser.extractNominal('Tahun 2026'), isNull);
      expect(CurrencyOcrParser.extractNominal('Windows 11 Home'), isNull);
      expect(CurrencyOcrParser.extractNominal('Stiker Laptop'), isNull);
    });
  });
}
