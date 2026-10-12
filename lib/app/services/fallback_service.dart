import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service untuk menangani fallback panggilan seluler (dialer) dan WhatsApp
/// Mendukung Telepon Seluler, Telepon Suara/Video WhatsApp, dan Obrolan WhatsApp.
class FallbackService extends GetxService {
  /// Membuka dialer telepon seluler perangkat
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

  /// Membuka PANGGILAN TELEPON WHATSAPP (Voice/Video Call WA)
  Future<bool> launchWhatsAppCall(String phoneNumber) async {
    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }

    final message = 'Halo, saya membutuhkan bantuan visual mendesak dari NetraVision. Mohon telepon saya melalui Panggilan Suara atau Video WhatsApp sekarang.';
    final encodedMsg = Uri.encodeComponent(message);

    // 1. Coba deep-link panggilan langsung WhatsApp
    final callUri = Uri.parse('whatsapp://call?phone=$clean');
    try {
      if (await canLaunchUrl(callUri)) {
        final success = await launchUrl(callUri, mode: LaunchMode.externalApplication);
        if (success) return true;
      }
    } catch (_) {}

    // 2. Buka kontak WhatsApp langsung via skema whatsapp:// dengan pesan darurat siap panggil
    final directWaUri = Uri.parse('whatsapp://send?phone=$clean&text=$encodedMsg');
    try {
      if (await canLaunchUrl(directWaUri)) {
        final success = await launchUrl(directWaUri, mode: LaunchMode.externalApplication);
        if (success) return true;
      }
    } catch (_) {}

    // 3. Fallback: Buka kontak WhatsApp via browser wa.me
    final waUri = Uri.parse('https://wa.me/$clean?text=$encodedMsg');
    try {
      if (await canLaunchUrl(waUri)) {
        return await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Membuka obrolan teks WhatsApp dengan pesan pembuka konteks tugas
  Future<bool> launchWhatsApp(String phoneNumber, {String? initialMessage}) async {
    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }

    final message = initialMessage ??
        'Halo, saya membutuhkan bantuan visual dari aplikasi NetraVision. Mohon dapat dihubungi kembali.';
    final encodedMsg = Uri.encodeComponent(message);

    // 1. Buka kontak WhatsApp langsung via skema whatsapp://
    final directWaUri = Uri.parse('whatsapp://send?phone=$clean&text=$encodedMsg');
    try {
      if (await canLaunchUrl(directWaUri)) {
        final success = await launchUrl(directWaUri, mode: LaunchMode.externalApplication);
        if (success) return true;
      }
    } catch (_) {}

    // 2. Fallback via wa.me
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
