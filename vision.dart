import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import '../domain/models.dart';

/// 100% on-device vision. One still frame per check, classified and deleted immediately.
/// Golden rule: when unsure, return neutral. Penalties require two consecutive hits.
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

  Future<void> init() async {
    await dispose();
    final cams = await availableCameras();
    if (cams.isEmpty) {
      throw StateError('No camera found on this device.');
    }
    final front = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cams.first,
    );
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    cam = controller;
    _miss = _away = _eyes = 0;
  }

  Future<FocusState> classify() async {
    final c = cam;
    if (c == null || !c.value.isInitialized || _capturing) {
      return FocusState.neutral;
    }
    _capturing = true;
    XFile? shot;
    try {
      shot = await c.takePicture();
      final img = InputImage.fromFilePath(shot.path);
      final faces = await _face.processImage(img);

      if (faces.isEmpty) {
        // Head down writing can hide face, so require two consecutive misses.
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
