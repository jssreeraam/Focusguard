import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../domain/models.dart';

/// 100% on-device low-battery Rear-Camera proctor.
/// Checks live face presence + phone-in-hand + extreme head turn.
/// Eye-open angle is intentionally disabled so looking down at books never penalizes you.
class VisionService {
  CameraController? cam;
  final _face = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.08,
    ),
  );
  final _labels = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: .75),
  );

  int _miss = 0, _away = 0;
  bool _capturing = false;
  bool _initializing = false;
  String lastInfo = 'Waiting for first random check...';

  Future<void> init({bool useRear = true}) async {
    if (_initializing) return;
    _initializing = true;
    try {
      await dispose();
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw StateError('No camera found on this device.');
      }
      final selected = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      cam = controller;
      _miss = _away = 0;
      lastInfo = 'Rear camera ready (low power · flash OFF)';
    } finally {
      _initializing = false;
    }
  }

  Future<FocusState> classify() async {
    final c = cam;
    if (c == null || !c.value.isInitialized || _capturing || _initializing) {
      lastInfo = 'Camera busy or not ready';
      return FocusState.neutral;
    }
    if (c.value.isTakingPicture) return FocusState.neutral;

    _capturing = true;
    XFile? shot;
    try {
      shot = await c.takePicture().timeout(const Duration(seconds: 8));
      final img = InputImage.fromFilePath(shot.path);
      final faces = await _face.processImage(img);

      if (faces.isEmpty) {
        _away = 0;
        _miss++;
        lastInfo = _miss >= 2 ? 'No face (2/2) -> Absent' : 'No face (1/2) -> Grace';
        return _miss >= 2 ? FocusState.absent : FocusState.neutral;
      }
      _miss = 0;

      // Isolate phone-in-hand detection so labeler errors never break face detection
      try {
        final labels = await _labels.processImage(img);
        final phone = labels.any(
          (l) => l.label.toLowerCase().contains('phone') && l.confidence >= .75,
        );
        if (phone) {
          lastInfo = 'Phone detected in frame';
          return FocusState.distraction;
        }
      } catch (_) {}

      final f = faces.first;
      final yaw = (f.headEulerAngleY ?? 0).abs();

      if (yaw > 50) {
        _away++;
        lastInfo = 'Turned away (${yaw.round()}°) [$_away/2]';
        return _away >= 2 ? FocusState.distraction : FocusState.neutral;
      }
      _away = 0;

      lastInfo = 'Live face locked in (yaw ${yaw.round()}°)';
      return FocusState.study;
    } catch (e) {
      lastInfo = 'Check error: $e';
      return FocusState.neutral;
    } finally {
      _capturing = false;
      if (shot != null) {
        try {
          final file = File(shot.path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> dispose() async {
    final c = cam;
    cam = null;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
  }
}
