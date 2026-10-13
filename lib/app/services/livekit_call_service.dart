import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:livekit_client/livekit_client.dart';
import '../data/models/visual_help_models.dart';
import 'tts_service.dart';

/// Service untuk mengelola lifecycle panggilan video kamera & audio dua arah via LiveKit
class LiveKitCallService extends GetxService {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  final RxBool isConnected = false.obs;
  final RxBool isReconnecting = false.obs;
  final RxBool isMicMuted = false.obs;
  final RxBool isCameraPaused = false.obs;
  final RxBool isScreenShareActive = false.obs;
  final RxString connectionStatusText = 'Belum terhubung'.obs;

  // Track video yang aktif
  final Rx<VideoTrack?> localVideoTrack = Rx<VideoTrack?>(null);
  final Rx<VideoTrack?> remoteVideoTrack = Rx<VideoTrack?>(null);

  // Cuplikan sementara (HANYA di RAM, dibersihkan saat sesi selesai)
  final Rx<SessionSnapshot?> currentSnapshot = Rx<SessionSnapshot?>(null);

  Room? get room => _room;

  /// Memulai koneksi media ke LiveKit room
  Future<bool> connect({
    required String url,
    required String token,
    required bool isUserRole,
  }) async {
    try {
      connectionStatusText.value = 'Menyambungkan ke ruang media...';
      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
        ),
      );

      _listener = _room!.createListener();
      _setupRoomListeners();

      await _room!.connect(url, token);
      isConnected.value = true;
      connectionStatusText.value = 'Terhubung langsung';

      if (isUserRole) {
        // Pengguna Tunanetra: Beri konfirmasi suara tersambung
        Get.find<TtsService>().speak('Tersambung dengan pendamping. Kamera dan mikrofon aktif.');
        // Pengguna Tunanetra: Aktifkan kamera belakang dan mikrofon
        await _room!.localParticipant?.setCameraEnabled(
          true,
          cameraCaptureOptions: const CameraCaptureOptions(
            cameraPosition: CameraPosition.back,
            params: VideoParametersPresets.h720_169,
          ),
        );
        await _room!.localParticipant?.setMicrophoneEnabled(true);

        // Ambil local track untuk preview di layar pengguna
        for (final pub in _room!.localParticipant?.videoTrackPublications ?? []) {
          if (pub.track != null) {
            localVideoTrack.value = pub.track;
            break;
          }
        }
      } else {
        // Pendamping / Relawan: Aktifkan HANYA mikrofon (kamera pendamping tidak perlu dikirim)
        await _room!.localParticipant?.setMicrophoneEnabled(true);

        // Cari remote video track yang sudah ada dari pengguna
        _findRemoteVideoTrack();
      }

      return true;
    } catch (e) {
      connectionStatusText.value = 'Gagal tersambung: $e';
      isConnected.value = false;
      return false;
    }
  }

  void _setupRoomListeners() {
    if (_listener == null) return;

    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        isConnected.value = false;
        connectionStatusText.value = 'Koneksi terputus';
        localVideoTrack.value = null;
    isScreenShareActive.value = false;
        remoteVideoTrack.value = null;
      })
      ..on<RoomReconnectingEvent>((event) {
        isReconnecting.value = true;
        connectionStatusText.value = 'Menyambungkan kembali koneksi...';
      })
      ..on<RoomReconnectedEvent>((event) {
        isReconnecting.value = false;
        isConnected.value = true;
        connectionStatusText.value = 'Koneksi pulih';
      })
      ..on<TrackSubscribedEvent>((event) {
        if (event.track is VideoTrack) {
          remoteVideoTrack.value = event.track as VideoTrack;
          connectionStatusText.value = 'Video pengguna tersambung';
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (event.track == remoteVideoTrack.value) {
          remoteVideoTrack.value = null;
          connectionStatusText.value = 'Kamera pengguna terhenti (Hanya Audio)';
        }
      })
      ..on<DataReceivedEvent>((event) {
        try {
          final rawText = utf8.decode(event.data);
          final map = jsonDecode(rawText) as Map<String, dynamic>;
          final type = map['type'] as String?;
          if (type == 'tts_guide' && map['text'] != null) {
            final guideText = map['text'] as String;
            // Bicara langsung di telinga tunanetra dengan prioritas tinggi
            Get.find<TtsService>().speak(guideText, isUrgent: true);
            HapticFeedback.heavyImpact();
          } else if (type == 'haptic_buzz') {
            HapticFeedback.heavyImpact();
            Get.find<TtsService>().speak('Peringatan getar dari pendamping', isUrgent: true);
          }
        } catch (e) {
          // ignore unparseable data packet
        }
      });
  }

  void _findRemoteVideoTrack() {
    if (_room == null) return;
    for (final participant in _room!.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (pub.track != null) {
          remoteVideoTrack.value = pub.track;
          return;
        }
      }
    }
  }

  Future<void> toggleMic() async {
    if (_room?.localParticipant == null) return;
    final newState = !isMicMuted.value;
    await _room!.localParticipant!.setMicrophoneEnabled(!newState);
    isMicMuted.value = newState;
  }


  Future<void> toggleScreenShare() async {
    if (_room?.localParticipant == null) return;
    try {
      final newState = !isScreenShareActive.value;
      await _room!.localParticipant!.setScreenShareEnabled(newState);
      isScreenShareActive.value = newState;
    } catch (e) {
      connectionStatusText.value = 'Gagal berbagi layar: $e';
    }
  }

  Future<void> toggleCamera() async {
    if (_room?.localParticipant == null) return;
    final newState = !isCameraPaused.value;
    await _room!.localParticipant!.setCameraEnabled(!newState);
    isCameraPaused.value = newState;
  }

  /// Mengambil cuplikan sementara (snapshot) dari frame video pengguna
  Future<SessionSnapshot?> captureSnapshot({Uint8List? frameData}) async {
    // Buat data gambar sementara jika frame belum tersedia dari native buffer
    final dummyPixels = frameData ?? Uint8List.fromList(List.generate(100, (i) => 255));
    final snapshot = SessionSnapshot(
      id: 'snap_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      imageBytes: dummyPixels,
      width: 1280,
      height: 720,
    );
    currentSnapshot.value = snapshot;

    // Pengumuman suara di perangkat pengguna
    try {
      final tts = Get.find<TtsService>();
      tts.speak('Cuplikan foto diambil oleh pendamping untuk memeriksa tulisan.', isUrgent: true);
    } catch (_) {}

    return snapshot;
  }

  void clearSnapshot() {
    currentSnapshot.value = null;
  }

  Future<void> disconnect() async {
    clearSnapshot();
    localVideoTrack.value = null;
    isScreenShareActive.value = false;
    remoteVideoTrack.value = null;

    try {
      await _room?.localParticipant?.setCameraEnabled(false);
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _listener?.dispose();
      await _room?.disconnect();
      await _room?.dispose();
    } catch (_) {}

    _room = null;
    _listener = null;
    isConnected.value = false;
    isReconnecting.value = false;
    connectionStatusText.value = 'Sesi diakhiri';
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
