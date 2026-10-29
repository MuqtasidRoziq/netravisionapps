import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_accessibility_service/accessibility_event.dart';
import 'package:flutter_accessibility_service/constants.dart';
import 'package:flutter_accessibility_service/flutter_accessibility_service.dart';
import 'package:get/get.dart';

enum AutoClickAction { none, videoCall, sendChat }

/// Service untuk menangani auto-klik otomatis saat WhatsApp terbuka (VC WA / Kirim Chat)
class AutoClickService extends GetxService {
  static const MethodChannel _nativeChannel = MethodChannel('com.netravision.apps/whatsapp');
  final RxBool isAccessibilityGranted = false.obs;
  AutoClickAction _pendingAction = AutoClickAction.none;
  DateTime? _actionArmTime;
  StreamSubscription<AccessibilityEvent>? _sub;

  @override
  void onInit() {
    super.onInit();
    checkPermission();
    _startListening();
  }

  /// Memeriksa apakah Layanan Aksesibilitas NetraVision sudah aktif di Pengaturan Android
  Future<bool> checkPermission() async {
    try {
      final nativeRunning = await _nativeChannel.invokeMethod<bool>('isAccessibilityRunning');
      if (nativeRunning == true) {
        isAccessibilityGranted.value = true;
        return true;
      }
      final granted = await FlutterAccessibilityService.isAccessibilityPermissionEnabled();
      isAccessibilityGranted.value = granted;
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Membuka halaman Pengaturan Aksesibilitas Android agar pengguna mengaktifkan NetraVision
  Future<void> requestPermission() async {
    try {
      await FlutterAccessibilityService.requestAccessibilityPermission();
    } catch (_) {}
  }

  /// Mengaktifkan mode siap auto-klik sebelum WhatsApp dibuka
  void armAutoClick(AutoClickAction action) {
    _pendingAction = action;
    _actionArmTime = DateTime.now();

    final actStr = action == AutoClickAction.videoCall ? 'video_call' : 'send_chat';
    try {
      _nativeChannel.invokeMethod('armAutoClick', {'action': actStr});
    } catch (_) {}
  }

  /// Membatalkan mode siap auto-klik
  void disarm() {
    _pendingAction = AutoClickAction.none;
    _actionArmTime = null;
  }

  void _startListening() {
    _sub?.cancel();
    try {
      _sub = FlutterAccessibilityService.accessStream.listen((event) {
        if (_pendingAction == AutoClickAction.none) return;

        // Batas waktu timeout 15 detik jika tidak berhasil menemukan tombol
        if (_actionArmTime != null &&
            DateTime.now().difference(_actionArmTime!).inSeconds > 15) {
          disarm();
          return;
        }

        final pkg = event.packageName ?? '';
        if (!pkg.contains('whatsapp')) return;

        _handleWhatsAppEvent(event);
      });
    } catch (_) {}
  }

  Future<void> _handleWhatsAppEvent(AccessibilityEvent event) async {
    if (_pendingAction == AutoClickAction.videoCall) {
      await _searchAndClick(event, [
        'telepon video',
        'panggilan video',
        'video call',
        'video_call',
        'panggilan_video',
        'videocall',
        'video',
      ]);
    } else if (_pendingAction == AutoClickAction.sendChat) {
      await _searchAndClick(event, [
        'kirim',
        'send',
        'kirim pesan',
      ]);
    }
  }

  Future<bool> _searchAndClick(AccessibilityEvent event, List<String> keywords) async {
    Future<bool> checkNode(AccessibilityEvent node) async {
      final t = (node.text ?? '').toLowerCase();
      final id = (node.nodeId ?? '').toLowerCase();

      for (final kw in keywords) {
        if (t.contains(kw) || id.contains(kw)) {
          final clicked = await FlutterAccessibilityService.performAction(
            node,
            NodeAction.actionClick,
          );
          if (clicked) {
            disarm();
            return true;
          }
        }
      }
      return false;
    }

    // 1. Cek node utama
    if (await checkNode(event)) return true;

    // 2. Cek subNodes turunan
    final sub = event.subNodes;
    if (sub != null) {
      for (final s in sub) {
        if (await checkNode(s)) return true;
        if (s.subNodes != null) {
          for (final deep in s.subNodes!) {
            if (await checkNode(deep)) return true;
          }
        }
      }
    }

    return false;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
