import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auto_click_service.dart';

/// Service untuk menangani fallback panggilan seluler (dialer) dan WhatsApp
/// Mendukung Telepon Seluler, Telepon Suara/Video WhatsApp, dan Obrolan WhatsApp.
class FallbackService extends GetxService {
  static const MethodChannel _whatsAppChannel = MethodChannel('com.netravision.apps/whatsapp');

  /// Mencoba memicu Panggilan Video (VC) WhatsApp secara langsung ke nomor kontak
  Future<bool> launchDirectWhatsAppVideoCall({
    required String phoneNumber,
    String? contactName,
  }) async {
    try {
      final success = await _whatsAppChannel.invokeMethod<bool>('directVideoCall', {
        'phoneNumber': phoneNumber,
        'contactName': contactName ?? '',
      });
      if (success == true) return true;
    } catch (_) {}

    // Fallback: Arm auto-click and launch clean whatsapp://send?phone=... tanpa teks obrolan
    final autoClickService = Get.isRegistered<AutoClickService>() ? Get.find<AutoClickService>() : null;
    autoClickService?.armAutoClick(AutoClickAction.videoCall);

    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }

    final directWaUri = Uri.parse('whatsapp://send?phone=$clean');
    try {
      if (await canLaunchUrl(directWaUri)) {
        return await launchUrl(directWaUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    final waMeUri = Uri.parse('https://wa.me/$clean');
    try {
      if (await canLaunchUrl(waMeUri)) {
        return await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    return false;
  }

  /// Mencoba memicu Panggilan Suara WhatsApp secara langsung ke nomor kontak
  Future<bool> launchDirectWhatsAppVoiceCall({
    required String phoneNumber,
    String? contactName,
  }) async {
    try {
      final success = await _whatsAppChannel.invokeMethod<bool>('directVoiceCall', {
        'phoneNumber': phoneNumber,
        'contactName': contactName ?? '',
      });
      if (success == true) return true;
    } catch (_) {}

    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }

    final directWaUri = Uri.parse('whatsapp://send?phone=$clean');
    try {
      if (await canLaunchUrl(directWaUri)) {
        return await launchUrl(directWaUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    return false;
  }
  /// Melakukan broadcast / share pesan darurat sesi NetraVision ke WhatsApp (Grup atau Kontak)
  Future<bool> broadcastHelpRequestToWhatsApp({
    required String requestId,
    required String userName,
    required String taskDescription,
    String? targetPhone,
    String? locationUrl,
  }) async {
    final locText = (locationUrl != null && locationUrl.isNotEmpty)
        ? '\n📍 *Lokasi GPS Terkini:* $locationUrl\n'
        : '';

    final message = '🚨 *PANGGILAN BANTUAN NETRAVISION*\n'
        '👤 *Pengguna:* $userName\n'
        '🎯 *Kebutuhan:* $taskDescription\n'
        '$locText\n'
        '👉 *Klik tautan ini untuk menjawab panggilan langsung:*\n'
        'https://netravision-portal.vercel.app/?session=$requestId';

    final encodedMsg = Uri.encodeComponent(message);

    Uri targetUri;
    if (targetPhone != null && targetPhone.trim().isNotEmpty) {
      String clean = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.startsWith('0')) clean = '62${clean.substring(1)}';
      targetUri = Uri.parse('whatsapp://send?phone=$clean&text=$encodedMsg');
    } else {
      targetUri = Uri.parse('whatsapp://send?text=$encodedMsg');
    }

    try {
      if (await canLaunchUrl(targetUri)) {
        return await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // Fallback browser wa.me
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedMsg');
    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return false;
  }

  /// Membuka dialer telepon seluler perangkat (paling andal untuk kondisi darurat)
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

  /// Membuka pesan darurat WhatsApp langsung ke nomor kontak keluarga/wali
  /// Berisi permintaan panggilan telepon segera dan tautan lokasi Google Maps
  Future<bool> launchWhatsAppCall(String phoneNumber, {String? locationUrl}) async {
    String clean = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    }

    final locText = (locationUrl != null && locationUrl.isNotEmpty)
        ? '\n📍 *Lokasi GPS Terkini:* $locationUrl'
        : '';

    final message = '🚨 *PANGGILAN DARURAT NETRAVISION (SOS)*\n'
        'Halo, saya pengguna tunanetra membutuhkan bantuan visual mendesak.$locText\n\n'
        'Mohon segera hubungi saya melalui Panggilan Suara / Telepon sekarang!';
    final encodedMsg = Uri.encodeComponent(message);

    // Buka kontak WhatsApp langsung dengan template pesan darurat terisi
    final directWaUri = Uri.parse('whatsapp://send?phone=$clean&text=$encodedMsg');
    try {
      if (await canLaunchUrl(directWaUri)) {
        final success = await launchUrl(directWaUri, mode: LaunchMode.externalApplication);
        if (success) return true;
      }
    } catch (_) {}

    // Fallback via browser wa.me
    final waUri = Uri.parse('https://wa.me/$clean?text=$encodedMsg');
    try {
      if (await canLaunchUrl(waUri)) {
        return await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Mengirim SMS darurat (bekerja tanpa kuota internet)
  Future<bool> sendEmergencySms({
    required String phoneNumber,
    String? locationUrl,
    String? customMessage,
  }) async {
    final clean = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final locText = (locationUrl != null && locationUrl.isNotEmpty)
        ? ' Lokasi: $locationUrl'
        : '';
    final message = customMessage ??
        '🚨 DARURAT NETRAVISION: Saya membutuhkan bantuan mendesak.$locText';
    final encoded = Uri.encodeComponent(message);

    final uri = Uri.parse('sms:$clean?body=$encoded');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
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
