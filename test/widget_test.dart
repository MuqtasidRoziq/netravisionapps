import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/data/models/vision_mode.dart';

void main() {
  test('VisionMode title & announcement menggunakan Bahasa Indonesia', () {
    expect(VisionMode.indoor.title, 'Kenali Barang Sekitar');
    expect(VisionMode.outdoor.title, 'Mode Luar Ruangan');
    expect(VisionMode.currency.title, 'Mode Baca Uang');
    expect(VisionMode.currency.announcement, contains('rupiah'));
    expect(VisionMode.outdoor.announcement, contains('Luar Ruangan'));
    expect(VisionMode.indoor.announcement, contains('tongkat'));
  });
}
