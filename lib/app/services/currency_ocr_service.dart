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

      // 1. Periksa teks gabungan seluruh gambar
      final overall = CurrencyOcrParser.extractNominal(recognizedText.text);
      if (overall != null) {
        return overall;
      }

      // 2. Periksa blok dan baris secara individual (untuk teks uang yang tersebar di sudut)
      for (final block in recognizedText.blocks) {
        final blockNominal = CurrencyOcrParser.extractNominal(block.text);
        if (blockNominal != null) {
          return blockNominal;
        }
        for (final line in block.lines) {
          final lineNominal = CurrencyOcrParser.extractNominal(line.text);
          if (lineNominal != null) {
            return lineNominal;
          }
        }
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
