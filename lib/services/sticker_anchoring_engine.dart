import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;

enum StickerCategory { food, beverage, general, scene, person, animal, electronics }
enum AnchorPreference { topEdge, bottomEdge, center, bottomScene }

class StickerMetadata {
  final String id;
  final String assetPath;
  final StickerCategory category;
  final AnchorPreference preference;
  final ui.Offset bitePoint; // 0.0 to 1.0
  final ui.Offset? detectedAnchorOffset;

  const StickerMetadata({
    required this.id,
    required this.assetPath,
    required this.category,
    required this.preference,
    required this.bitePoint,
    this.detectedAnchorOffset,
  });

  StickerMetadata copyWith({
    String? id,
    String? assetPath,
    StickerCategory? category,
    AnchorPreference? preference,
    ui.Offset? bitePoint,
    ui.Offset? detectedAnchorOffset,
  }) {
    return StickerMetadata(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      category: category ?? this.category,
      preference: preference ?? this.preference,
      bitePoint: bitePoint ?? this.bitePoint,
      detectedAnchorOffset: detectedAnchorOffset ?? this.detectedAnchorOffset,
    );
  }
}

class StickerAnchoringEngine {
  // Toàn bộ 115 meme đã được đánh số và phân loại ngữ cảnh chính xác:
  // 1. Mèo meme (29 ảnh): Dành cho vật nuôi, động vật, biểu cảm dễ thương
  static final List<String> catMemes = List.generate(
    29,
    (i) => 'assets/memes/meme_cat_${(i + 1).toString().padLeft(2, '0')}.png',
  );

  // 2. Capybara meme (22 ảnh): Dành cho phong cảnh, ăn uống chill, thư giãn ngoài trời
  static final List<String> capybaraMemes = List.generate(
    22,
    (i) => 'assets/memes/meme_capybara_${(i + 1).toString().padLeft(2, '0')}.png',
  );

  // 3. Biểu cảm & hài hước (64 ảnh): Dành cho con người, cảm xúc, đồ uống, công nghệ
  static final List<String> funnyMemes = List.generate(
    64,
    (i) => 'assets/memes/meme_react_${(i + 1).toString().padLeft(2, '0')}.png',
  );

  // Danh mục hợp nhất toàn bộ 115 meme
  static final List<String> allMemes = [...catMemes, ...capybaraMemes, ...funnyMemes];

  static StickerMetadata pickStickerForCategory(StickerCategory category) {
    final rand = math.Random();
    switch (category) {
      case StickerCategory.animal:
        // Động vật, thú cưng, chó mèo -> Chọn từ kho 29 meme mèo bựa & cute
        final path = catMemes[rand.nextInt(catMemes.length)];
        return StickerMetadata(
          id: 'animal_cat',
          assetPath: path,
          category: StickerCategory.animal,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
      case StickerCategory.person:
        // Con người, khuôn mặt, selfie -> Chọn từ kho 64 meme biểu cảm hài hước
        final path = funnyMemes[rand.nextInt(funnyMemes.length)];
        return StickerMetadata(
          id: 'person_funny',
          assetPath: path,
          category: StickerCategory.person,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
      case StickerCategory.food:
        // Đồ ăn -> Chọn từ các meme thèm ăn, há miệng háo hức trong funnyMemes & catMemes
        final foodPool = [...funnyMemes, ...catMemes];
        final path = foodPool[rand.nextInt(foodPool.length)];
        return StickerMetadata(
          id: 'food_meme',
          assetPath: path,
          category: StickerCategory.food,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.9),
        );
      case StickerCategory.beverage:
        // Đồ uống -> Chọn từ funnyMemes & catMemes
        final drinkPool = [...funnyMemes, ...catMemes];
        final path = drinkPool[rand.nextInt(drinkPool.length)];
        return StickerMetadata(
          id: 'drink_meme',
          assetPath: path,
          category: StickerCategory.beverage,
          preference: AnchorPreference.center,
          bitePoint: const ui.Offset(0.5, 0.5),
        );
      case StickerCategory.electronics:
        // Công nghệ, laptop, máy tính, điện thoại -> Meme mèo gõ phím, công nghệ
        final path = catMemes[rand.nextInt(catMemes.length)];
        return StickerMetadata(
          id: 'tech_cat',
          assetPath: path,
          category: StickerCategory.electronics,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
      case StickerCategory.scene:
        // KHÔNG CÓ VẬT THỂ RÕ RÀNG -> Chụp phong cảnh thư giãn -> Capybara chill ngâm bồn, đội cam
        final path = capybaraMemes[rand.nextInt(capybaraMemes.length)];
        return StickerMetadata(
          id: 'scene_capybara',
          assetPath: path,
          category: StickerCategory.scene,
          preference: AnchorPreference.bottomScene,
          bitePoint: const ui.Offset(0.5, 1.0),
        );
      case StickerCategory.general:
        // CÓ VẬT THỂ RÕ RÀNG NHƯNG LÀ ĐỒ VẬT KHÁC (móc khóa, bàn làm việc, đồ chơi, sách vở...)
        // -> Chọn ngẫu nhiên phong phú từ toàn bộ 115 meme (Mèo, Capybara, Reaction)
        final path = allMemes[rand.nextInt(allMemes.length)];
        return StickerMetadata(
          id: 'general_meme',
          assetPath: path,
          category: StickerCategory.general,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
    }
  }

  // Persistent ML Kit singletons to eliminate TFLite cold-start latency (~1s saved)
  static SubjectSegmenter? _cachedSegmenter;
  static ImageLabeler? _cachedLabeler;
  static ObjectDetector? _cachedObjectDetector;

  static SubjectSegmenter _getSegmenter() {
    return _cachedSegmenter ??= SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: false,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: true,
          enableSubjectBitmap: false,
        ),
      ),
    );
  }

  static ImageLabeler _getLabeler() {
    return _cachedLabeler ??= ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
  }

  static ObjectDetector _getObjectDetector() {
    return _cachedObjectDetector ??= ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
  }

  /// 0 VNĐ & 100% Offline: Phân tích bối cảnh theo tình huống & phân biệt vật thể rõ ràng vs phong cảnh
  /// - Nếu có vật thể rõ ràng (> 8% diện tích): Nhận diện cụ thể (thú cưng, người, đồ ăn, nước uống, laptop, đồ chơi/đồ vật)
  /// - Nếu không có vật thể rõ ràng: Xếp vào chụp phong cảnh (Scene Mode - Capybara chill)
  static Future<StickerMetadata?> detectAndSuggestSticker(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      // Đọc kích thước ảnh nhanh qua Skia
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final double origW = frame.image.width.toDouble();
      final double origH = frame.image.height.toDouble();
      frame.image.dispose();
      codec.dispose();

      final double imageArea = origW * origH;

      // 1. Chạy song song ObjectDetector và ImageLabeler
      final detectorFuture = _getObjectDetector().processImage(inputImage);
      final labelerFuture = _getLabeler().processImage(inputImage);

      final results = await Future.wait([
        detectorFuture.then<dynamic>((v) => v).catchError((_) => <DetectedObject>[]),
        labelerFuture.then<dynamic>((v) => v).catchError((_) => <ImageLabel>[]),
      ]);

      final objects = (results[0] as List<DetectedObject>?) ?? [];
      final labels = (results[1] as List<ImageLabel>?) ?? [];

      // 2. Tìm vật thể lớn nhất trong khung hình
      Rect? targetRect;
      double maxArea = 0;
      for (final obj in objects) {
        final area = (obj.boundingBox.width * obj.boundingBox.height).toDouble();
        if (area > maxArea) {
          maxArea = area;
          targetRect = obj.boundingBox;
        }
      }

      StickerCategory category;

      // 3. Phân biệt chính xác: Có vật thể rõ ràng (> 8% diện tích ảnh) vs Không có vật thể (Chụp phong cảnh)
      final bool hasClearObject = targetRect != null && imageArea > 0 && (maxArea / imageArea) > 0.08;

      if (!hasClearObject) {
        // KHÔNG CÓ VẬT THỂ RÕ RÀNG -> Chụp phong cảnh (Scene Mode)
        category = StickerCategory.scene;
      } else {
        // CÓ VẬT THỂ RÕ RÀNG -> Mặc định là vật thể chung (general - đa dạng 115 meme), sau đó rà soát nhãn chi tiết
        category = StickerCategory.general;
        bool hasPerson = false;

        for (final label in labels) {
          final text = label.label.toLowerCase();
          final conf = label.confidence;

          // Nhận diện Con người / Khuôn mặt
          if (text == 'person' || text == 'face' || text == 'human' || text == 'man' || text == 'woman' || text == 'boy' || text == 'girl' || RegExp(r'\b(hair|head|smile)\b').hasMatch(text)) {
            if (conf > 0.5) hasPerson = true;
          }

          // Nhận diện Đồ ăn
          if (text.contains('food') || text.contains('cake') || text.contains('donut') || text.contains('apple') || text.contains('banana') || text.contains('sandwich') || text.contains('pizza') || text.contains('hot dog') || text.contains('bread') || text.contains('snack') || text.contains('noodle') || text.contains('meat') || text.contains('fruit')) {
            category = StickerCategory.food;
            break;
          }
          // Nhận diện Đồ uống
          else if (text.contains('drink') || text.contains('cup') || text.contains('bottle') || (text.contains('glass') && !text.contains('sunglass') && !text.contains('eyeglass')) || text.contains('liquid') || text.contains('beverage') || text.contains('beer') || text.contains('coffee') || text.contains('tea')) {
            category = StickerCategory.beverage;
            break;
          }
          // Nhận diện Thú cưng / Động vật
          else if (text.contains('animal') || text.contains('cat') || text.contains('dog') || text.contains('bird') || text.contains('pet') || text.contains('bear') || text.contains('mammal') || text.contains('carnivore') || text.contains('felidae') || text.contains('canidae') || text.contains('whiskers') || text.contains('fur')) {
            category = StickerCategory.animal;
            break;
          }
          // Nhận diện Thiết bị điện tử / Công nghệ
          else if (text.contains('laptop') || text.contains('computer') || text.contains('phone') || text.contains('keyboard') || text.contains('mouse') || text.contains('screen') || text.contains('electronic') || text.contains('netbook') || text.contains('technology') || text.contains('gadget') || text.contains('hardware') || text.contains('monitor') || text.contains('display')) {
            category = StickerCategory.electronics;
            break;
          }
        }

        if (hasPerson) {
          category = StickerCategory.person;
        }
      }

      final metadata = pickStickerForCategory(category);

      // 4. Nếu có vật thể rõ ràng, tính toán tọa độ neo tự động bám theo đỉnh vật thể
      ui.Offset? anchorOffset;
      if (hasClearObject && origW > 0 && origH > 0) {
        final double normX = ((targetRect.center.dx - (origW * 0.16)) / origW).clamp(0.06, 0.65);
        final double normY = ((targetRect.top - (origH * 0.16)) / origH).clamp(0.06, 0.45);
        anchorOffset = ui.Offset(normX, normY);
      }

      return metadata.copyWith(
        detectedAnchorOffset: anchorOffset ?? const ui.Offset(0.08, 0.35),
      );
    } catch (e) {
      debugPrint('detectAndSuggestSticker Error: $e');
      return null;
    }
  }

  static Future<String?> processAndMerge(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      // Fast hardware-accelerated dimension reading via Skia (1ms)
      final bytes = await File(imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final double origW = frame.image.width.toDouble();
      final double origH = frame.image.height.toDouble();
      frame.image.dispose();
      codec.dispose();

      final double imageArea = origW * origH;

      Rect? targetRect;
      double maxArea = 0;
      List<double>? subjectMask;

      // Run Subject Segmentation (Android) and Image Labeling in PARALLEL for maximum speed
      final segmenterFuture = Platform.isIOS
          ? Future<SubjectSegmentationResult?>.value(null)
          : _getSegmenter().processImage(inputImage);
      final labelerFuture = _getLabeler().processImage(inputImage);

      SubjectSegmentationResult? segResult;
      List<ImageLabel> labels = [];

      try {
        final results = await Future.wait([
          segmenterFuture.then<dynamic>((v) => v).catchError((_) => null),
          labelerFuture.then<dynamic>((v) => v).catchError((_) => <ImageLabel>[]),
        ]);
        segResult = results[0] as SubjectSegmentationResult?;
        labels = (results[1] as List<ImageLabel>?) ?? [];
      } catch (e) {
        debugPrint('AI Inference Error: $e');
      }

      // Check Segmentation results
      if (segResult != null && segResult.subjects.isNotEmpty) {
        for (var subj in segResult.subjects) {
          final area = (subj.width * subj.height).toDouble();
          if (area > maxArea) {
            maxArea = area;
            targetRect = Rect.fromLTWH(
              subj.startX.toDouble(),
              subj.startY.toDouble(),
              subj.width.toDouble(),
              subj.height.toDouble(),
            );
            subjectMask = subj.confidenceMask;
          }
        }
      }

      // Fallback to ObjectDetector if SubjectSegmenter found nothing
      if (targetRect == null) {
        try {
          final objects = await _getObjectDetector().processImage(inputImage);
          for (var obj in objects) {
            final area = obj.boundingBox.width * obj.boundingBox.height;
            if (area > maxArea) {
              maxArea = area;
              targetRect = obj.boundingBox;
            }
          }
        } catch (_) {}
      }

      // Category detection based on labels
      StickerCategory category = StickerCategory.scene;

      if (targetRect != null && (maxArea / imageArea) > 0.08) {
        category = StickerCategory.general;
        bool hasPerson = false;
        bool hasScene = false;

        for (var label in labels) {
          final text = label.label.toLowerCase();
          final conf = label.confidence;

          if (text == 'person' || text == 'face' || text == 'human' || text == 'man' || text == 'woman' || text == 'boy' || text == 'girl' || RegExp(r'\b(hair|head|smile)\b').hasMatch(text)) {
            if (conf > 0.5) hasPerson = true;
          }
          if (text.contains('room') || text.contains('building') || text.contains('interior') || text.contains('landscape') || text.contains('sky') || text.contains('architecture') || text.contains('house')) {
            if (conf > 0.65) hasScene = true;
          }

          if (text.contains('food') || text.contains('cake') || text.contains('donut') || text.contains('apple') || text.contains('banana') || text.contains('sandwich') || text.contains('pizza') || text.contains('hot dog') || text.contains('broccoli') || text.contains('carrot')) {
            category = StickerCategory.food;
          } else if (text.contains('drink') || text.contains('cup') || text.contains('bottle') || (text.contains('glass') && !text.contains('sunglass') && !text.contains('eyeglass')) || text.contains('liquid') || text.contains('beverage') || text.contains('beer') || text.contains('coffee')) {
            category = StickerCategory.beverage;
          } else if (text.contains('animal') || text.contains('cat') || text.contains('dog') || text.contains('bird') || text.contains('pet') || text.contains('bear') || text.contains('mammal') || text.contains('carnivore') || text.contains('felidae') || text.contains('canidae') || text.contains('whiskers') || text.contains('fur') || text.contains('capybara')) {
            category = StickerCategory.animal;
          } else if (text.contains('laptop') || text.contains('computer') || text.contains('phone') || text.contains('keyboard') || text.contains('mouse') || text.contains('screen') || text.contains('electronic') || text.contains('netbook') || text.contains('technology') || text.contains('gadget') || text.contains('hardware') || text.contains('input device') || text.contains('peripheral') || text.contains('touchpad') || text.contains('space bar') || text.contains('keypad') || text.contains('monitor') || text.contains('display')) {
            category = StickerCategory.electronics;
          } else if (text.contains('toy') || text.contains('figurine') || text.contains('doll') || text.contains('statue') || text.contains('sculpture') || text.contains('sunglass') || text.contains('goggles')) {
            category = StickerCategory.general;
          }
        }

        if (hasPerson) {
          category = StickerCategory.person;
        } else if (hasScene && category == StickerCategory.general && (maxArea / imageArea) < 0.20) {
          targetRect = Rect.fromLTRB(0, origH - 100.0, origW, origH);
          category = StickerCategory.scene;
        }
      } else {
        targetRect = Rect.fromLTRB(0, origH - 100.0, origW, origH);
        category = StickerCategory.scene;
      }

      // Pick sticker
      final sticker = pickStickerForCategory(category);
      final ByteData stickerData = await rootBundle.load(sticker.assetPath);
      final Uint8List stickerBytes = stickerData.buffer.asUint8List();

      final mergedPath = await compute(_mergeImages, {
        'originalPath': imagePath,
        'stickerBytes': stickerBytes,
        'rectLeft': targetRect.left.toInt(),
        'rectTop': targetRect.top.toInt(),
        'rectWidth': targetRect.width.toInt(),
        'rectHeight': targetRect.height.toInt(),
        'preference': sticker.preference.index,
        'isScene': category == StickerCategory.scene,
        'mask': subjectMask,
      });

      return mergedPath;
    } catch (e) {
      debugPrint('Global Process Error: $e');
      return null;
    }
  }

  static String _mergeImages(Map<String, dynamic> args) {
    final originalPath = args['originalPath'] as String;
    final stickerBytes = args['stickerBytes'] as Uint8List;
    final origRectLeft = args['rectLeft'] as int;
    final origRectTop = args['rectTop'] as int;
    final rectWidth = args['rectWidth'] as int;
    final rectHeight = args['rectHeight'] as int;
    final preference = AnchorPreference.values[args['preference'] as int];

    // Single-pass: Decode original image in background isolate
    final originalBytes = File(originalPath).readAsBytesSync();
    var originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) return originalPath;

    // 1. Bake EXIF orientation
    originalImage = img.bakeOrientation(originalImage);

    // 2. Crop to 1:1 center square (Matches viewfinder exactly, eliminates crop cuts)
    int cropX = 0;
    int cropY = 0;
    if (originalImage.width != originalImage.height) {
      final cropSize = math.min(originalImage.width, originalImage.height);
      cropX = (originalImage.width - cropSize) ~/ 2;
      cropY = (originalImage.height - cropSize) ~/ 2;
      originalImage = img.copyCrop(originalImage, x: cropX, y: cropY, width: cropSize, height: cropSize);
    }

    // 3. Transform subject bounding box to cropped square coordinates
    final rectLeft = origRectLeft - cropX;
    final rectTop = origRectTop - cropY;

    // 4. Decode & Resize Sticker (Giữ nguyên ảnh gốc hoàn toàn sạch sẽ, không vẽ đè vạch neon hay chấm tròn)
    var stickerImage = img.decodeImage(stickerBytes);
    if (stickerImage == null) return originalPath;

    final double minStickerWidth = (originalImage.width * 0.24).clamp(160.0, 280.0);
    final double maxStickerWidth = (originalImage.width * 0.34).clamp(220.0, 380.0);

    double targetWidth = rectWidth * 0.42;
    if (preference == AnchorPreference.center) {
      targetWidth = rectWidth * 0.65;
    }
    targetWidth = targetWidth.clamp(minStickerWidth, maxStickerWidth);

    double scale = targetWidth / stickerImage.width;
    final newStickerWidth = (stickerImage.width * scale).toInt();
    final newStickerHeight = (stickerImage.height * scale).toInt();

    stickerImage = img.copyResize(
      stickerImage,
      width: newStickerWidth,
      height: newStickerHeight,
      interpolation: img.Interpolation.cubic,
    );

    // 6. Adaptive Placement with Safe Margin
    final int margin = (originalImage.width * 0.05).clamp(24.0, 48.0).toInt();
    int drawX, drawY;

    final spaceRight = originalImage.width - (rectLeft + rectWidth);
    final spaceLeft = rectLeft;
    final spaceTop = rectTop;
    final spaceBottom = originalImage.height - (rectTop + rectHeight);

    if (preference == AnchorPreference.center) {
      drawX = rectLeft + (rectWidth ~/ 2) - (newStickerWidth ~/ 2);
      drawY = rectTop + (rectHeight ~/ 2) - (newStickerHeight ~/ 2);
    } else if (spaceRight >= newStickerWidth + margin) {
      drawX = rectLeft + rectWidth + 12;
      drawY = rectTop + (rectHeight * 0.15).toInt();
    } else if (spaceLeft >= newStickerWidth + margin) {
      drawX = rectLeft - newStickerWidth - 12;
      drawY = rectTop + (rectHeight * 0.15).toInt();
    } else if (spaceTop >= newStickerHeight + margin) {
      drawX = rectLeft + (rectWidth ~/ 2) - (newStickerWidth ~/ 2);
      drawY = rectTop - (newStickerHeight * 0.75).toInt();
    } else if (spaceBottom >= newStickerHeight + margin) {
      drawX = rectLeft + (rectWidth ~/ 2) - (newStickerWidth ~/ 2);
      drawY = rectTop + rectHeight + 12;
    } else {
      final cornerScores = {
        'topRight': spaceTop + spaceRight,
        'topLeft': spaceTop + spaceLeft,
        'bottomRight': spaceBottom + spaceRight,
        'bottomLeft': spaceBottom + spaceLeft,
      };
      final bestCorner = cornerScores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      switch (bestCorner) {
        case 'topRight':
          drawX = originalImage.width - newStickerWidth - margin;
          drawY = margin;
          break;
        case 'topLeft':
          drawX = margin;
          drawY = margin;
          break;
        case 'bottomRight':
          drawX = originalImage.width - newStickerWidth - margin;
          drawY = originalImage.height - newStickerHeight - margin;
          break;
        case 'bottomLeft':
        default:
          drawX = margin;
          drawY = originalImage.height - newStickerHeight - margin;
          break;
      }
    }

    final maxX = (originalImage.width - newStickerWidth - margin).clamp(margin, originalImage.width);
    final maxY = (originalImage.height - newStickerHeight - margin).clamp(margin, originalImage.height);
    drawX = drawX.clamp(margin, maxX);
    drawY = drawY.clamp(margin, maxY);

    // 7. Composite Sticker
    img.compositeImage(originalImage, stickerImage, dstX: drawX, dstY: drawY);

    // 8. Single Fast Encode: quality 85 produces sharp visuals and encodes 3x faster
    final tempDir = Directory.systemTemp.path;
    final outPath = '$tempDir/merged_${DateTime.now().millisecondsSinceEpoch}.jpg';
    File(outPath).writeAsBytesSync(img.encodeJpg(originalImage, quality: 85));

    return outPath;
  }
}
