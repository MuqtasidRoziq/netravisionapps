import 'dart:io';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/helpers/currency_ocr_parser.dart';

/// Layanan on-device OCR (Google ML Kit) untuk memverifikasi angka dan teks nominal
/// pada uang kertas Rupiah secara offline, gratis, dan instan.
class CurrencyOcrService extends GetxService {
  late final TextRecognizer _textRecognizer;
  File? _tempFile;
  bool _isProcessing = false;

  bool get isProcessing => _isProcessing;

  @override
  void onInit() {
    super.onInit();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final tempDir = Directory.systemTemp;
    _tempFile = File('${tempDir.path}/ocr_rupiah_frame.jpg');
  }

  /// Memproses cuplikan gambar (JPEG bytes) dan mengekstrak nominal Rupiah resmi.
  ///
  /// Mengembalikan nominal string seperti '1000', '2000', '5000', '10000',
  /// '20000', '50000', '75000', '100000', atau `null` jika bukan uang.
  Future<String?> recognizeRupiah(Uint8List jpegBytes) async {
    if (_isProcessing || jpegBytes.isEmpty) return null;

    _isProcessing = true;
    try {
      final file = _tempFile ?? File('${Directory.systemTemp.path}/ocr_rupiah_frame.jpg');
      await file.writeAsBytes(jpegBytes, flush: true);

      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text.toUpperCase();

      // 1. Prioritas Tertinggi: Teks tulisan nominal resmi Bank Indonesia
      if (rawText.contains('DUA RIBU') || rawText.contains('DUARIBU')) {
        return '2000';
      }
      if (rawText.contains('LIMA PULUH') || rawText.contains('50 RIBU')) {
        return '50000';
      }
      if (rawText.contains('SERATUS RIBU')) {
        return '100000';
      }
      if (rawText.contains('SEPULUH RIBU')) {
        return '10000';
      }
      if (rawText.contains('DUA PULUH') || rawText.contains('20 RIBU')) {
        return '20000';
      }
      if (rawText.contains('LIMA RIBU') && !rawText.contains('PULUH')) {
        return '5000';
      }
      if (rawText.contains('SERIBU') || rawText.contains('SATU RIBU')) {
        return '1000';
      }
      if (rawText.contains('TUJUH PULUH LIMA')) {
        return '75000';
      }

      // 2. Periksa teks gabungan seluruh gambar via parser angka
      final overall = CurrencyOcrParser.extractNominal(recognizedText.text);
      if (overall != null) {
        return overall;
      }

      // 3. Periksa blok dan baris secara individual
      final candidates = <String>[];
      for (final block in recognizedText.blocks) {
        final blockNominal = CurrencyOcrParser.extractNominal(block.text);
        if (blockNominal != null) {
          candidates.add(blockNominal);
        }
      }

      if (candidates.isNotEmpty) {
        final counts = <String, int>{};
        for (final c in candidates) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
        String best = candidates.first;
        int maxCount = 0;
        counts.forEach((nom, count) {
          if (count > maxCount) {
            maxCount = count;
            best = nom;
          }
        });
        return best;
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void onClose() {
    _textRecognizer.close();
    super.onClose();
  }
}
