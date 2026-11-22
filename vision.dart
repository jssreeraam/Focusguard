import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../domain/models.dart';

/// 100% on-device vision supporting Back (default) and Front cameras.
/// Rear flash is explicitly forced OFF. Every frame is deleted immediately.
class VisionService {
  CameraController? cam;
  final _face = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final _labels = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: .7),
  );

  int _miss = 0, _away = 0, _eyes = 0;
  bool _capturing = false;
  bool _initializing = false;

  Future<void> init({bool useRear = true}) async {
    if (_initializing) return;
    _initializing = true;
    try {
      await dispose();
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw StateError('No camera found on this device.');
      }
      final target = useRear ? CameraLensDirection.back : CameraLensDirection.front;
      final selected = cams.firstWhere(
        (c) => c.lensDirection == target,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      cam = controller;
      _miss = _away = _eyes = 0;
    } finally {
      _initializing = false;
    }
  }

  Future<FocusState> classify() async {
    final c = cam;
    if (c == null || !c.value.isInitialized || _capturing || _initializing) {
      return FocusState.neutral;
    }
    if (c.value.isTakingPicture) return FocusState.neutral;

    _capturing = true;
    XFile? shot;
    try {
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      shot = await c.takePicture().timeout(const Duration(seconds: 6));
      final img = InputImage.fromFilePath(shot.path);
      final faces = await _face.processImage(img);

      if (faces.isEmpty) {
        _away = 0;
        _eyes = 0;
        _miss++;
        return _miss >= 2 ? FocusState.absent : FocusState.neutral;
      }
      _miss = 0;

      final labels = await _labels.processImage(img);
      final phone = labels.any(
        (l) => l.label.toLowerCase().contains('phone') && l.confidence >= .75,
      );
      if (phone) return FocusState.distraction;

      final f = faces.first;
      final yaw = (f.headEulerAngleY ?? 0).abs();
      final eyes =
          ((f.leftEyeOpenProbability ?? 1) + (f.rightEyeOpenProbability ?? 1)) / 2;

      if (yaw > 40) {
        _away++;
        _eyes = 0;
        return _away >= 2 ? FocusState.distraction : FocusState.neutral;
      }
      _away = 0;

      if (eyes < .15) {
        _eyes++;
        return _eyes >= 2 ? FocusState.distraction : FocusState.neutral;
      }
      _eyes = 0;
      return FocusState.study;
    } catch (_) {
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
