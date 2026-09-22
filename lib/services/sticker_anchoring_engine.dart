import 'dart:io';
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
  // Pre-configured stickers
  static const List<StickerMetadata> availableStickers = [
    StickerMetadata(
      id: 'food_bite',
      assetPath: 'assets/memes/meme_food.png',
      category: StickerCategory.food,
      preference: AnchorPreference.topEdge,
      bitePoint: ui.Offset(0.5, 0.9), // Mouth at the bottom
    ),
    StickerMetadata(
      id: 'drink_hug',
      assetPath: 'assets/memes/meme_drink.png',
      category: StickerCategory.beverage,
      preference: AnchorPreference.center,
      bitePoint: ui.Offset(0.5, 0.5), // Center hug
    ),
    StickerMetadata(
      id: 'scene_overlay',
      assetPath: 'assets/memes/meme_scene.png',
      category: StickerCategory.scene,
      preference: AnchorPreference.bottomScene,
      bitePoint: ui.Offset(0.5, 1.0), // Stick to bottom of screen
    ),
    StickerMetadata(
      id: 'general_overlay',
      assetPath: 'assets/memes/meme_bear.png', // Thay con gấu hồng mỏ há to vào đây!
      category: StickerCategory.general,
      preference: AnchorPreference.topEdge, // Ghim nó ngó đầu từ trên viền vật thể xuống
      bitePoint: ui.Offset(0.5, 0.75), // Toạ độ cái miệng há hốc của con gấu
    ),
    StickerMetadata(
      id: 'animal_overlay',
      assetPath: 'assets/memes/meme_bear.png', 
      category: StickerCategory.animal,
      preference: AnchorPreference.topEdge, 
      bitePoint: ui.Offset(0.5, 0.75), 
    ),
    StickerMetadata(
      id: 'person_overlay',
      assetPath: 'assets/memes/meme_bear.png', 
      category: StickerCategory.person,
      preference: AnchorPreference.topEdge, 
      bitePoint: ui.Offset(0.5, 0.75), 
    ),
    StickerMetadata(
      id: 'electronics_overlay',
      assetPath: 'assets/memes/meme_drink.png', 
      category: StickerCategory.electronics,
      preference: AnchorPreference.center, 
      bitePoint: ui.Offset(0.5, 0.5), 
    ),
  ];

  static Future<String?> processAndMerge(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final originalImageBytes = File(imagePath).readAsBytesSync();
      final img.Image? decodedImg = img.decodeImage(originalImageBytes);
      if (decodedImg == null) return null;
      final imageArea = decodedImg.width * decodedImg.height;

      Rect? targetRect;
      double maxArea = 0;
      List<double>? subjectMask;

      // --- PATH 1: Try Subject Segmentation (Pixel-level Silhouette Mask) ---
      try {
        final segmenterOptions = SubjectSegmenterOptions(
          enableForegroundBitmap: false,
          enableForegroundConfidenceMask: false,
          enableMultipleSubjects: SubjectResultOptions(
            enableConfidenceMask: true,
            enableSubjectBitmap: false,
          ),
        );
        final segmenter = SubjectSegmenter(options: segmenterOptions);
        final segResult = await segmenter.processImage(inputImage);
        segmenter.close();

        if (segResult.subjects.isNotEmpty) {
          for (var subj in segResult.subjects) {
            final area = (subj.width * subj.height).toDouble();
            if (area > maxArea) {
              maxArea = area;
              targetRect = Rect.fromLTWH(subj.startX.toDouble(), subj.startY.toDouble(), subj.width.toDouble(), subj.height.toDouble());
              subjectMask = subj.confidenceMask;
            }
          }
          if (subjectMask != null) {
            print('🤖 [AI Engine] ✨ Subject Segmenter ACTIVE: Exact pixel-level mask found! Area: ${((maxArea / imageArea)*100).toStringAsFixed(1)}%');
          }
        }
      } catch (e) {
        print('🤖 [AI Engine] ℹ️ Subject Segmenter module not ready yet ($e). Falling back to ObjectDetector.');
      }

      // --- PATH 2: Fallback to ObjectDetector if SubjectSegmenter is not available ---
      if (targetRect == null) {
        final options = ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        );
        final objectDetector = ObjectDetector(options: options);
        final List<DetectedObject> objects = await objectDetector.processImage(inputImage);
        objectDetector.close();

        for (var obj in objects) {
          final area = obj.boundingBox.width * obj.boundingBox.height;
          if (area > maxArea) {
            maxArea = area;
            targetRect = obj.boundingBox;
          }
        }
        if (targetRect != null) {
          print('🤖 [AI Engine] 📦 Object Detector ACTIVE: Bounding Box found! Area: ${((maxArea / imageArea)*100).toStringAsFixed(1)}%');
        }
      }

      StickerCategory category = StickerCategory.scene;

      if (targetRect != null && (maxArea / imageArea) > 0.08) {
        category = StickerCategory.general;
        
        // --- DUAL-AI PIPELINE: STEP 2 - IMAGE LABELING ---
        final labelerOptions = ImageLabelerOptions(confidenceThreshold: 0.5);
        final imageLabeler = ImageLabeler(options: labelerOptions);
        final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
        
        bool hasPerson = false;
        bool hasScene = false;

        if (labels.isNotEmpty) {
          print('🤖 [AI Engine] Dual-AI: Labels found for Main Subject:');
          for (var label in labels) {
            print('   - ${label.label} (Confidence: ${(label.confidence * 100).toStringAsFixed(1)}%)');
            final text = label.label.toLowerCase();
            final conf = label.confidence;

            // 1. Check for Person (Strict word boundaries to never confuse 'chair' with 'hair')
            if (text == 'person' || text == 'face' || text == 'human' || text == 'man' || text == 'woman' || text == 'boy' || text == 'girl' || RegExp(r'\b(hair|head|smile)\b').hasMatch(text)) {
              if (conf > 0.5) hasPerson = true;
            }
            
            // 2. Check for Scene indicators (Room, Building, Interior, etc.)
            if (text.contains('room') || text.contains('building') || text.contains('interior') || text.contains('landscape') || text.contains('sky') || text.contains('architecture') || text.contains('house')) {
              if (conf > 0.65) hasScene = true;
            }

            // Category mappings
            if (text.contains('food') || text.contains('cake') || text.contains('donut') || text.contains('apple') || text.contains('banana') || text.contains('sandwich') || text.contains('pizza') || text.contains('hot dog') || text.contains('broccoli') || text.contains('carrot')) {
              category = StickerCategory.food;
            }
            else if (text.contains('drink') || text.contains('cup') || text.contains('bottle') || (text.contains('glass') && !text.contains('sunglass') && !text.contains('eyeglass')) || text.contains('liquid') || text.contains('beverage') || text.contains('beer') || text.contains('coffee')) {
              category = StickerCategory.beverage;
            }
            else if (text.contains('animal') || text.contains('cat') || text.contains('dog') || text.contains('bird') || text.contains('pet') || text.contains('bear')) {
              category = StickerCategory.animal;
            }
            else if (text.contains('laptop') || text.contains('computer') || text.contains('phone') || text.contains('keyboard') || text.contains('mouse') || text.contains('screen') || text.contains('electronic')) {
              category = StickerCategory.electronics;
            }
            else if (text.contains('toy') || text.contains('figurine') || text.contains('doll') || text.contains('statue') || text.contains('sculpture') || text.contains('sunglass') || text.contains('goggles')) {
              category = StickerCategory.general; // Real toy/figure/gadget object!
            }
          }
        }
        imageLabeler.close();

        // --- HIERARCHY LOGIC: PERSON VS REAL OBJECT VS SCENE ---
        if (hasPerson) {
          print('🤖 [AI Engine] 👤 Person detected! Person takes highest priority as Main Subject.');
          category = StickerCategory.person;
        } else if (subjectMask != null) {
          // If Subject Segmenter already isolated a real foreground subject, NEVER override with Scene!
          print('🤖 [AI Engine] 🎯 Definite Subject isolated by Segmenter (No Scene Override needed).');
        } else if (hasScene && category == StickerCategory.general && (maxArea / imageArea) < 0.20) {
          // Only force Scene Mode on ObjectDetector fallback if no specific object detected and very small
          print('🤖 [AI Engine] 🏠 Scene Override: Pure empty background detected. Forcing Scene Mode.');
          targetRect = Rect.fromLTRB(0, decodedImg.height - 100.0, decodedImg.width.toDouble(), decodedImg.height.toDouble());
          category = StickerCategory.scene;
        }
      } else {
        print('🤖 [AI Engine] Saliency: No dominant subject. Falling back to Scene Mode.');
        targetRect = Rect.fromLTRB(0, decodedImg.height - 100.0, decodedImg.width.toDouble(), decodedImg.height.toDouble());
        category = StickerCategory.scene;
      }
        
      // Pick sticker
      final sticker = availableStickers.firstWhere(
        (s) => s.category == category,
        orElse: () => availableStickers.first,
      );
      print('🤖 [AI Engine] Applying Sticker: ${sticker.id} (Asset: ${sticker.assetPath})');

      final ByteData stickerData = await rootBundle.load(sticker.assetPath);
      final Uint8List stickerBytes = stickerData.buffer.asUint8List();

      final mergedPath = await compute(_mergeImages, {
        'originalPath': imagePath,
        'stickerBytes': stickerBytes,
        'rectLeft': targetRect.left.toInt(),
        'rectTop': targetRect.top.toInt(),
        'rectWidth': targetRect.width.toInt(),
        'rectHeight': targetRect.height.toInt(),
        'bitePointX': sticker.bitePoint.dx,
        'bitePointY': sticker.bitePoint.dy,
        'preference': sticker.preference.index,
        'isScene': category == StickerCategory.scene,
        'mask': subjectMask,
      });

      return mergedPath;
    } catch (e) {
      print('🤖 [AI Engine] Global Process Error: $e');
      return null;
    }
  }

  static String _mergeImages(Map<String, dynamic> args) {
    final originalPath = args['originalPath'] as String;
    final stickerBytes = args['stickerBytes'] as Uint8List;
    final rectLeft = args['rectLeft'] as int;
    final rectTop = args['rectTop'] as int;
    final rectWidth = args['rectWidth'] as int;
    final rectHeight = args['rectHeight'] as int;
    final bitePointX = args['bitePointX'] as double;
    final bitePointY = args['bitePointY'] as double;
    final preference = AnchorPreference.values[args['preference'] as int];
    final isScene = args['isScene'] as bool? ?? false;
    final mask = args['mask'] as List<double>?;

    final originalBytes = File(originalPath).readAsBytesSync();
    final originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) return originalPath;

    // --- NEON GLOW CONTOUR & CYBERPUNK HUD EFFECT ---
    if (!isScene && rectWidth > 0 && rectHeight > 0) {
      final List<img.Point> edgePoints = [];

      // 1. If Pixel-level Segmentation Mask is available, trace exact silhouette!
      if (mask != null && mask.length == rectWidth * rectHeight) {
        for (int y = 0; y < rectHeight; y++) {
          for (int x = 0; x < rectWidth; x++) {
            int idx = y * rectWidth + x;
            if (mask[idx] > 0.5) {
              bool isEdge = false;
              if (x == 0 || x == rectWidth - 1 || y == 0 || y == rectHeight - 1) {
                isEdge = true;
              } else {
                if (mask[y * rectWidth + (x - 1)] <= 0.5 ||
                    mask[y * rectWidth + (x + 1)] <= 0.5 ||
                    mask[(y - 1) * rectWidth + x] <= 0.5 ||
                    mask[(y + 1) * rectWidth + x] <= 0.5) {
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
        // 2. Otherwise, use Contrast Gradient Edge Detection!
        final step = 2;
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

      // Draw Rich 3-layer Neon Glow on detected object contours
      // 1. Outer Glow Aura
      for (int i = 0; i < edgePoints.length; i += 2) {
        final pt = edgePoints[i];
        img.fillCircle(originalImage, x: pt.x.toInt(), y: pt.y.toInt(), radius: 10, color: img.ColorRgba8(0, 255, 255, 30));
      }
      // 2. Mid Glow
      for (int i = 0; i < edgePoints.length; i += 2) {
        final pt = edgePoints[i];
        img.fillCircle(originalImage, x: pt.x.toInt(), y: pt.y.toInt(), radius: 5, color: img.ColorRgba8(0, 255, 255, 110));
      }
      // 3. Core Bright Tube
      for (final pt in edgePoints) {
        img.fillCircle(originalImage, x: pt.x.toInt(), y: pt.y.toInt(), radius: 2, color: img.ColorRgba8(240, 255, 255, 255));
      }

      // 2. Cyberpunk Neon Corner Brackets [  ]
      final cornerLen = (rectWidth * 0.18).clamp(24.0, 70.0).toInt();
      void drawNeonLine(int x1, int y1, int x2, int y2) {
        // Outer glow
        img.drawLine(originalImage, x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgba8(0, 255, 255, 60), thickness: 12);
        // Mid glow
        img.drawLine(originalImage, x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgba8(0, 255, 255, 160), thickness: 6);
        // Core tube
        img.drawLine(originalImage, x1: x1, y1: y1, x2: x2, y2: y2, color: img.ColorRgba8(240, 255, 255, 255), thickness: 2);
      }
      
      // Top-Left corner
      drawNeonLine(rectLeft, rectTop, rectLeft + cornerLen, rectTop);
      drawNeonLine(rectLeft, rectTop, rectLeft, rectTop + cornerLen);
      // Top-Right corner
      drawNeonLine(rectLeft + rectWidth, rectTop, rectLeft + rectWidth - cornerLen, rectTop);
      drawNeonLine(rectLeft + rectWidth, rectTop, rectLeft + rectWidth, rectTop + cornerLen);
      // Bottom-Left corner
      drawNeonLine(rectLeft, rectTop + rectHeight, rectLeft + cornerLen, rectTop + rectHeight);
      drawNeonLine(rectLeft, rectTop + rectHeight, rectLeft, rectTop + rectHeight - cornerLen);
      // Bottom-Right corner
      drawNeonLine(rectLeft + rectWidth, rectTop + rectHeight, rectLeft + rectWidth - cornerLen, rectTop + rectHeight);
      drawNeonLine(rectLeft + rectWidth, rectTop + rectHeight, rectLeft + rectWidth, rectTop + rectHeight - cornerLen);
    }

    // Read sticker image from bytes
    var stickerImage = img.decodeImage(stickerBytes);
    if (stickerImage == null) return originalPath;

    // 4. Calculate Anchoring Math
    // Target sticker width = 45% of object width (or 80% if it's a hug)
    double scale = (rectWidth * 0.45) / stickerImage.width;
    if (preference == AnchorPreference.center) {
      scale = (rectWidth * 0.8) / stickerImage.width;
    }
    
    // Resize sticker
    final newStickerWidth = (stickerImage.width * scale).toInt();
    final newStickerHeight = (stickerImage.height * scale).toInt();
    stickerImage = img.copyResize(stickerImage, width: newStickerWidth, height: newStickerHeight);

    // Calculate target coordinate on original image
    int targetX, targetY;
    if (preference == AnchorPreference.topEdge) {
      targetX = rectLeft + (rectWidth ~/ 2);
      targetY = rectTop; // apex
    } else if (preference == AnchorPreference.bottomEdge) {
      targetX = rectLeft + (rectWidth ~/ 2);
      targetY = rectTop + rectHeight;
    } else {
      // center
      targetX = rectLeft + (rectWidth ~/ 2);
      targetY = rectTop + (rectHeight ~/ 2);
    }

    // Offset by bite point
    final drawX = targetX - (newStickerWidth * bitePointX).toInt();
    final drawY = targetY - (newStickerHeight * bitePointY).toInt();

    // Composite
    img.compositeImage(originalImage, stickerImage, dstX: drawX, dstY: drawY);

    // Save to temp
    final tempDir = Directory.systemTemp.path;
    final outPath = '$tempDir/merged_${DateTime.now().millisecondsSinceEpoch}.jpg';
    File(outPath).writeAsBytesSync(img.encodeJpg(originalImage, quality: 90));
    
    return outPath;
  }
}
