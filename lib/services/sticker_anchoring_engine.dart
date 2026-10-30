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

  const StickerMetadata({
    required this.id,
    required this.assetPath,
    required this.category,
    required this.preference,
    required this.bitePoint,
  });
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
      case StickerCategory.electronics:
        final path = catMemes[rand.nextInt(catMemes.length)];
        return StickerMetadata(
          id: 'electronics_cat',
          assetPath: path,
          category: StickerCategory.electronics,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
      case StickerCategory.animal:
        final path = capybaraMemes[rand.nextInt(capybaraMemes.length)];
        return StickerMetadata(
          id: 'animal_capybara',
          assetPath: path,
          category: StickerCategory.animal,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
      case StickerCategory.person:
        final path = funnyMemes[rand.nextInt(funnyMemes.length)];
        return StickerMetadata(
          id: 'person_funny',
          assetPath: path,
          category: StickerCategory.person,
          preference: AnchorPreference.topEdge,
          bitePoint: const ui.Offset(0.5, 0.85),
        );
      case StickerCategory.food:
        return const StickerMetadata(
          id: 'food_bite',
          assetPath: 'assets/memes/meme_food.png',
          category: StickerCategory.food,
          preference: AnchorPreference.topEdge,
          bitePoint: ui.Offset(0.5, 0.9),
        );
      case StickerCategory.beverage:
        return const StickerMetadata(
          id: 'drink_hug',
          assetPath: 'assets/memes/meme_drink.png',
          category: StickerCategory.beverage,
          preference: AnchorPreference.center,
          bitePoint: ui.Offset(0.5, 0.5),
        );
      case StickerCategory.scene:
        return const StickerMetadata(
          id: 'scene_overlay',
          assetPath: 'assets/memes/meme_scene.png',
          category: StickerCategory.scene,
          preference: AnchorPreference.bottomScene,
          bitePoint: ui.Offset(0.5, 1.0),
        );
      case StickerCategory.general:
        final all = [...funnyMemes, ...catMemes];
        final path = all[rand.nextInt(all.length)];
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

      // Run Subject Segmentation and Image Labeling in PARALLEL for maximum speed
      final segmenterFuture = _getSegmenter().processImage(inputImage);
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
    final isScene = args['isScene'] as bool? ?? false;
    final mask = args['mask'] as List<double>?;

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
    final img.Image baseImage = originalImage;

    // 4. Fast Neon Glow Contour & Cyberpunk HUD Effect
    if (!isScene && rectWidth > 0 && rectHeight > 0) {
      final List<img.Point> edgePoints = [];

      if (mask != null && mask.length == rectWidth * rectHeight) {
        // Fast edge detection: step by 2 pixels to cut iterations by 75%
        for (int y = 0; y < rectHeight; y += 2) {
          for (int x = 0; x < rectWidth; x += 2) {
            int idx = y * rectWidth + x;
            if (mask[idx] > 0.5) {
              bool isEdge = false;
              if (x <= 1 || x >= rectWidth - 2 || y <= 1 || y >= rectHeight - 2) {
                isEdge = true;
              } else {
                if (mask[y * rectWidth + (x - 2)] <= 0.5 ||
                    mask[y * rectWidth + (x + 2)] <= 0.5 ||
                    mask[(y - 2) * rectWidth + x] <= 0.5 ||
                    mask[(y + 2) * rectWidth + x] <= 0.5) {
                  isEdge = true;
                }
              }
              if (isEdge) {
                edgePoints.add(img.Point(rectLeft + x, rectTop + y));
              }
            }
          }
        }
      } else {
        // Fast contrast gradient fallback
        const step = 4;
        final xStart = rectLeft.clamp(0, originalImage.width - 1);
        final xEnd = (rectLeft + rectWidth).clamp(0, originalImage.width - 3);
        final yStart = rectTop.clamp(0, originalImage.height - 1);
        final yEnd = (rectTop + rectHeight).clamp(0, originalImage.height - 3);

        for (int y = yStart + 4; y < yEnd - 4; y += step) {
          for (int x = xStart + 4; x < xEnd - 4; x += step) {
            final p = originalImage.getPixel(x, y);
            final pRight = originalImage.getPixel(x + 2, y);
            final pDown = originalImage.getPixel(x, y + 2);

            final diffR = (p.r - pRight.r).abs() + (p.r - pDown.r).abs();
            final diffG = (p.g - pRight.g).abs() + (p.g - pDown.g).abs();
            final diffB = (p.b - pRight.b).abs() + (p.b - pDown.b).abs();
            final diff = (diffR + diffG + diffB) / 3;

            if (diff > 35) {
              edgePoints.add(img.Point(x, y));
            }
          }
        }
      }

      // Fast Neon Glow Rendering (Sampled for lightning speed & smooth visuals)
      for (int i = 0; i < edgePoints.length; i += 4) {
        final pt = edgePoints[i];
        img.fillCircle(originalImage, x: pt.x.toInt(), y: pt.y.toInt(), radius: 4, color: img.ColorRgba8(0, 255, 255, 90));
      }
      for (int i = 0; i < edgePoints.length; i += 2) {
        final pt = edgePoints[i];
        img.fillCircle(originalImage, x: pt.x.toInt(), y: pt.y.toInt(), radius: 2, color: img.ColorRgba8(240, 255, 255, 255));
      }

      // Cyberpunk Neon Corner Brackets [  ]
      final cornerLen = (rectWidth * 0.18).clamp(24.0, 70.0).toInt();
      void drawNeonLine(int x1, int y1, int x2, int y2) {
        img.drawLine(baseImage, x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgba8(0, 255, 255, 80), thickness: 6);
        img.drawLine(baseImage, x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgba8(240, 255, 255, 255), thickness: 2);
      }

      // 4 corners
      drawNeonLine(rectLeft, rectTop, rectLeft + cornerLen, rectTop);
      drawNeonLine(rectLeft, rectTop, rectLeft, rectTop + cornerLen);
      drawNeonLine(rectLeft + rectWidth, rectTop, rectLeft + rectWidth - cornerLen, rectTop);
      drawNeonLine(rectLeft + rectWidth, rectTop, rectLeft + rectWidth, rectTop + cornerLen);
      drawNeonLine(rectLeft, rectTop + rectHeight, rectLeft + cornerLen, rectTop + rectHeight);
      drawNeonLine(rectLeft, rectTop + rectHeight, rectLeft, rectTop + rectHeight - cornerLen);
      drawNeonLine(rectLeft + rectWidth, rectTop + rectHeight, rectLeft + rectWidth - cornerLen, rectTop + rectHeight);
      drawNeonLine(rectLeft + rectWidth, rectTop + rectHeight, rectLeft + rectWidth, rectTop + rectHeight - cornerLen);
    }

    // 5. Decode & Resize Sticker
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
