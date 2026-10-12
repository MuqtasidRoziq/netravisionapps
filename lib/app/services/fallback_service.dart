import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service untuk menangani fallback panggilan seluler (dialer) dan WhatsApp
/// Penting: Sesuai spesifikasi prompt V2, membuka aplikasi eksternal TIDAK
/// dianggap sebagai bukti bahwa panggilan tersambung atau pesan terkirim.
class FallbackService extends GetxService {
  /// Membuka dialer telepon perangkat
  Future<bool> launchPhoneDialer(String phoneNumber) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');

    try {
      if (await canLaunchUrl(uri)) {
        final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
        return success;
      }
    } catch (_) {}
    return false;
  }

  /// Membuka obrolan WhatsApp dengan pesan pembuka konteks tugas
  Future<bool> launchWhatsApp(String phoneNumber, {String? initialMessage}) async {
    // Normalisasi format nomor Indonesia (08xxx -> 628xxx)
    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }

    final message = initialMessage ??
        'Halo, saya membutuhkan bantuan visual dari aplikasi NetraVision. Mohon dapat dihubungi kembali.';
    final encodedMsg = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$clean?text=$encodedMsg');

    try {
      if (await canLaunchUrl(uri)) {
        final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
        return success;
      }
    } catch (_) {}
    return false;
  }
}
