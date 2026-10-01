import 'package:camera/camera.dart';
import 'package:get/get.dart';

/// CameraService terpusat yang dapat digunakan kembali (reusable)
/// oleh semua mode: Mode Indoor, Mode Outdoor, maupun Mode Baca Uang.
class CameraService extends GetxService {
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;

  final RxBool isInitialized = false.obs;
  final RxBool isStreaming = false.obs;
  final RxString errorMessage = ''.obs;

  CameraController? get controller => _controller;

  Future<CameraService> init() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        await initializeCamera();
      } else {
        errorMessage.value = 'Tidak ada sensor kamera yang terdeteksi di perangkat.';
      }
    } catch (e) {
      errorMessage.value = 'Gagal mengakses kamera: $e';
    }
    return this;
  }

  /// Inisialisasi kamera belakang dengan resolusi Medium (optimal untuk AI & hemat baterai)
  Future<void> initializeCamera({CameraDescription? description}) async {
    if (_availableCameras.isEmpty) {
      errorMessage.value = 'Daftar kamera kosong.';
      return;
    }

    // Default ke kamera belakang jika ada
    final selectedCamera = description ??
        _availableCameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
          orElse: () => _availableCameras.first,
        );

    // Dispose controller lama jika ada
    await _controller?.dispose();

    _controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium, // 720p - Ideal untuk YOLO mobile tanpa overheat
      enableAudio: false,      // Audio false agar tidak memblokir TTS
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      isInitialized.value = true;
      errorMessage.value = '';
    } catch (e) {
      isInitialized.value = false;
      errorMessage.value = 'Gagal membuka kamera: $e';
    }
  }

  /// Pause kamera saat aplikasi ke background
  Future<void> pauseCamera() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.pausePreview();
      } catch (_) {}
    }
  }

  /// Resume kamera saat kembali ke foreground
  Future<void> resumeCamera() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.resumePreview();
      } catch (_) {}
    }
  }

  /// Menyalakan streaming frame kamera untuk pemrosesan AI
  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !isStreaming.value) {
      try {
        isStreaming.value = true;
        await _controller!.startImageStream(onImage);
      } catch (e) {
        isStreaming.value = false;
      }
    }
  }

  /// Menghentikan streaming frame kamera
  Future<void> stopImageStream() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        isStreaming.value) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {}
      isStreaming.value = false;
    }
  }

  @override
  void onClose() {
    stopImageStream();
    _controller?.dispose();
    super.onClose();
  }
}