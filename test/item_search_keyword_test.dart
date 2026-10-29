import 'package:flutter_test/flutter_test.dart';
import 'package:netravisionapps/app/modules/item_search/controllers/item_search_controller.dart';

void main() {
  group('ItemSearchController.extractItemKeyword Tests', () {
    test('Hanya nama objek langsung', () {
      expect(ItemSearchController.extractItemKeyword('cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('botol'), 'botol');
      expect(ItemSearchController.extractItemKeyword('kursi'), 'kursi');
    });

    test('Dengan kata awalan cari / tolong carikan', () {
      expect(ItemSearchController.extractItemKeyword('cari cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('tolong carikan cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('mau cari cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('saya mau cari cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('mencari cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('di mana cangkir'), 'cangkir');
    });

    test('Bocoran suara sistem / TalkBack / prompt ikut terpotong bersih', () {
      expect(ItemSearchController.extractItemKeyword('ucapkan nama barang cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('silakan ucapkan nama barang cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('mencari ucapkan nama barang cangkir'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('ucapkan nama barang yang ingin dicari botol'), 'botol');
    });

    test('Dengan imbuhan akhir pemanis kalimat (dong, ya, nih)', () {
      expect(ItemSearchController.extractItemKeyword('tolong carikan cangkir dong'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('cari cangkir ya'), 'cangkir');
    });

    test('Sinonim umum diterjemahkan ke label model AI COCO', () {
      expect(ItemSearchController.extractItemKeyword('gelas'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('mug'), 'cangkir');
      expect(ItemSearchController.extractItemKeyword('botol minum'), 'botol');
      expect(ItemSearchController.extractItemKeyword('tumbler'), 'botol');
      expect(ItemSearchController.extractItemKeyword('hp'), 'ponsel');
      expect(ItemSearchController.extractItemKeyword('handphone'), 'ponsel');
    });

    test('Benda di luar daftar tetap diekstrak dengan bersih', () {
      expect(ItemSearchController.extractItemKeyword('cari kunci'), 'kunci');
      expect(ItemSearchController.extractItemKeyword('tolong carikan dompet'), 'dompet');
    });
  });
}
