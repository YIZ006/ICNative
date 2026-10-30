import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StickerEditMode {
  original, // 1. Anh goc / badge giu nguyen ti le
  outline,  // 2. Vien sticker trang quanh chu the kieu Messenger
  full,     // 3. Tach nen trong suot giu chu the day du
}

class CustomStickerItem {
  final String id;
  final String path;
  final bool isAsset;
  final StickerEditMode mode;
  final String title;

  CustomStickerItem({
    required this.id,
    required this.path,
    this.isAsset = false,
    this.mode = StickerEditMode.original,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'isAsset': isAsset,
    'mode': mode.index,
    'title': title,
  };

  factory CustomStickerItem.fromJson(Map<String, dynamic> json) => CustomStickerItem(
    id: json['id'] as String,
    path: json['path'] as String,
    isAsset: json['isAsset'] as bool? ?? false,
    mode: StickerEditMode.values[(json['mode'] as int? ?? 0).clamp(0, 2)],
    title: json['title'] as String? ?? 'Sticker',
  );
}

class CustomStickerService {
  CustomStickerService._();
  static final CustomStickerService instance = CustomStickerService._();

  final List<CustomStickerItem> _stickers = [];
  List<CustomStickerItem> get stickers => List.unmodifiable(_stickers);

  SubjectSegmenter? _segmenter;
  ObjectDetector? _objectDetector;

  SubjectSegmenter _getSegmenter() {
    return _segmenter ??= SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: true,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: true,
          enableSubjectBitmap: true,
        ),
      ),
    );
  }

  ObjectDetector _getObjectDetector() {
    return _objectDetector ??= ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
  }

  Future<void> initialize() async {
    _stickers.clear();

    // 1. Cac sticker meme mau mac dinh san co trong app
    _stickers.addAll([
      CustomStickerItem(
        id: 'sample_capybara',
        path: 'assets/memes/capybara-cute-sticker.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Capybara Chill',
      ),
      CustomStickerItem(
        id: 'sample_cat',
        path: 'assets/memes/sticker-cat-meme.png',
        isAsset: true,
        mode: StickerEditMode.full,
        title: 'Mèo Bất Lực',
      ),
      CustomStickerItem(
        id: 'sample_bear',
        path: 'assets/memes/meme_bear.png',
        isAsset: true,
        mode: StickerEditMode.original,
        title: 'Gấu Nằm Ngủ',
      ),
      CustomStickerItem(
        id: 'sample_meme_cute',
        path: 'assets/memes/cute-meme-sticker.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Meme Dễ Thương',
      ),
    ]);

    // 2. Load cac sticker nguoi dung da tu tao tu SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('custom_sticker_ids') ?? [];
      for (final id in savedIds) {
        final rawPath = prefs.getString('custom_sticker_path_$id');
        final rawTitle = prefs.getString('custom_sticker_title_$id') ?? 'Custom Sticker';
        final rawMode = prefs.getInt('custom_sticker_mode_$id') ?? 0;
        if (rawPath != null && File(rawPath).existsSync()) {
          _stickers.add(
            CustomStickerItem(
              id: id,
              path: rawPath,
              isAsset: false,
              mode: StickerEditMode.values[rawMode.clamp(0, 2)],
              title: rawTitle,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading saved stickers: $e');
    }
  }

  Future<void> saveCustomSticker(CustomStickerItem item) async {
    _stickers.insert(0, item);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('custom_sticker_ids') ?? [];
      if (!savedIds.contains(item.id)) {
        savedIds.insert(0, item.id);
        await prefs.setStringList('custom_sticker_ids', savedIds);
      }
      await prefs.setString('custom_sticker_path_${item.id}', item.path);
      await prefs.setString('custom_sticker_title_${item.id}', item.title);
      await prefs.setInt('custom_sticker_mode_${item.id}', item.mode.index);
    } catch (e) {
      debugPrint('Error saving custom sticker: $e');
    }
  }

  Future<String> _ensureLocalFile(String path, bool isAsset) async {
    if (!isAsset) return path;
    final tempDir = await getTemporaryDirectory();
    final fileName = path.split('/').last;
    final localPath = '${tempDir.path}/asset_$fileName';
    final file = File(localPath);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return localPath;
  }

  /// Kiem tra xem anh co kenh alpha trong suot san khong
  bool _hasTransparency(img.Image image) {
    if (image.numChannels < 4) return false;
    int transparentPixelCount = 0;
    final totalSample = image.width * image.height;
    final step = (totalSample / 500).clamp(1, 50).toInt();

    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        if (image.getPixel(x, y).a < 200) {
          transparentPixelCount++;
          if (transparentPixelCount > 5) return true;
        }
      }
    }
    return false;
  }

  /// Tach nen chu the khoi anh bang Subject Segmentation hoac Object Bounding Mask
  Future<img.Image> _extractForeground(String localPath, img.Image baseImage) async {
    // 1. Neu anh da la PNG trong suot (vi du meme transparent) -> dung luon!
    if (_hasTransparency(baseImage)) {
      return baseImage;
    }

    // 2. Thu dung Google ML Kit Subject Segmentation on-device
    try {
      final inputImage = InputImage.fromFilePath(localPath);
      final segResult = await _getSegmenter().processImage(inputImage);

      if (segResult.foregroundBitmap != null && segResult.foregroundBitmap!.isNotEmpty) {
        final decoded = img.decodeImage(segResult.foregroundBitmap!);
        if (decoded != null && _hasTransparency(decoded)) {
          return decoded;
        }
      }

      if (segResult.subjects.isNotEmpty && segResult.subjects.first.bitmap != null) {
        final decoded = img.decodeImage(segResult.subjects.first.bitmap!);
        if (decoded != null) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('SubjectSegmenter info: $e');
    }

    // 3. Fallback thong minh: Phat hien vat the (Object Detection) & cat vien die-cut
    try {
      final inputImage = InputImage.fromFilePath(localPath);
      final objects = await _getObjectDetector().processImage(inputImage);

      if (objects.isNotEmpty) {
        // Lay vat the lon nhat
        var bestObj = objects.first;
        double maxArea = bestObj.boundingBox.width * bestObj.boundingBox.height;
        for (var o in objects) {
          final a = o.boundingBox.width * o.boundingBox.height;
          if (a > maxArea) {
            maxArea = a;
            bestObj = o;
          }
        }

        final box = bestObj.boundingBox;
        final cropX = box.left.clamp(0, baseImage.width - 1).toInt();
        final cropY = box.top.clamp(0, baseImage.height - 1).toInt();
        final cropW = box.width.clamp(20, baseImage.width - cropX).toInt();
        final cropH = box.height.clamp(20, baseImage.height - cropY).toInt();

        final cropped = img.copyCrop(baseImage, x: cropX, y: cropY, width: cropW, height: cropH);

        // Tao mat na bo goc hoac ellipse oval cho chu the
        final result = img.Image(width: cropW, height: cropH, numChannels: 4);
        final cx = cropW / 2.0;
        final cy = cropH / 2.0;
        final rx = cropW / 2.0;
        final ry = cropH / 2.0;

        for (int y = 0; y < cropH; y++) {
          for (int x = 0; x < cropW; x++) {
            final dx = (x - cx) / rx;
            final dy = (y - cy) / ry;
            final distSq = dx * dx + dy * dy;
            if (distSq <= 1.0) {
              result.setPixel(x, y, cropped.getPixel(x, y));
            } else {
              result.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
            }
          }
        }
        return result;
      }
    } catch (_) {}

    // 4. Neu khong tim duoc vat the ro rang: cat hinh oval badge sticker
    final cropSize = baseImage.width < baseImage.height ? baseImage.width : baseImage.height;
    final square = img.copyCrop(
      baseImage,
      x: (baseImage.width - cropSize) ~/ 2,
      y: (baseImage.height - cropSize) ~/ 2,
      width: cropSize,
      height: cropSize,
    );

    final badge = img.Image(width: cropSize, height: cropSize, numChannels: 4);
    final center = cropSize / 2.0;
    final radius = cropSize / 2.0;

    for (int y = 0; y < cropSize; y++) {
      for (int x = 0; x < cropSize; x++) {
        final dx = x - center;
        final dy = y - center;
        if (dx * dx + dy * dy <= radius * radius) {
          badge.setPixel(x, y, square.getPixel(x, y));
        } else {
          badge.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }
    return badge;
  }

  /// Tao Sticker theo 3 che do: Original, Outline, Full
  Future<String> generateStickerVariation({
    required String sourcePath,
    required bool isAsset,
    required StickerEditMode mode,
  }) async {
    final localPath = await _ensureLocalFile(sourcePath, isAsset);
    final bytes = await File(localPath).readAsBytes();
    final baseImage = img.decodeImage(bytes);
    if (baseImage == null) return localPath;

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 1. CHE DO ORIGINAL: Giu nguyen anh, thu nho vua phai (max 420px)
    if (mode == StickerEditMode.original) {
      img.Image processed = baseImage;
      if (processed.width > 420 || processed.height > 420) {
        processed = img.copyResize(
          processed,
          width: processed.width >= processed.height ? 420 : null,
          height: processed.height > processed.width ? 420 : null,
          interpolation: img.Interpolation.linear,
        );
      }
      final outPath = '${tempDir.path}/sticker_orig_$timestamp.png';
      await File(outPath).writeAsBytes(img.encodePng(processed));
      return outPath;
    }

    // Lay chu the da duoc tach nen
    img.Image cutoutImage = await _extractForeground(localPath, baseImage);

    // Resize cho vua tam sticker (max 380x380)
    if (cutoutImage.width > 380 || cutoutImage.height > 380) {
      cutoutImage = img.copyResize(
        cutoutImage,
        width: cutoutImage.width >= cutoutImage.height ? 380 : null,
        height: cutoutImage.height > cutoutImage.width ? 380 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    // 2. CHE DO FULL: Tach nen trong suot sach se
    if (mode == StickerEditMode.full) {
      final outPath = '${tempDir.path}/sticker_full_$timestamp.png';
      await File(outPath).writeAsBytes(img.encodePng(cutoutImage));
      return outPath;
    }

    // 3. CHE DO OUTLINE: Tao vien sticker trang day bao quanh chu the (Kieu Messenger)
    const int outlineRadius = 8; // Vien trang day 8px ro net
    const int padding = outlineRadius + 4;

    final int targetW = cutoutImage.width + padding * 2;
    final int targetH = cutoutImage.height + padding * 2;

    final outlined = img.Image(width: targetW, height: targetH, numChannels: 4);
    img.fill(outlined, color: img.ColorRgba8(0, 0, 0, 0));

    final whiteColor = img.ColorRgba8(255, 255, 255, 255);
    final shadowColor = img.ColorRgba8(40, 54, 24, 75); // Subtle deep olive shadow behind sticker

    // Buoc 1: Ve bong do nhe (Drop shadow) lech xuong duoi 3px
    for (int y = 0; y < cutoutImage.height; y++) {
      for (int x = 0; x < cutoutImage.width; x++) {
        if (cutoutImage.getPixel(x, y).a > 40) {
          for (int dy = -outlineRadius; dy <= outlineRadius; dy++) {
            for (int dx = -outlineRadius; dx <= outlineRadius; dx++) {
              if (dx * dx + dy * dy <= (outlineRadius + 2) * (outlineRadius + 2)) {
                final nx = x + padding + dx;
                final ny = y + padding + dy + 3;
                if (nx >= 0 && nx < targetW && ny >= 0 && ny < targetH) {
                  outlined.setPixel(nx, ny, shadowColor);
                }
              }
            }
          }
        }
      }
    }

    // Buoc 2: Ve vien trang day (Die-cut white contour)
    for (int y = 0; y < cutoutImage.height; y++) {
      for (int x = 0; x < cutoutImage.width; x++) {
        if (cutoutImage.getPixel(x, y).a > 30) {
          for (int dy = -outlineRadius; dy <= outlineRadius; dy++) {
            for (int dx = -outlineRadius; dx <= outlineRadius; dx++) {
              if (dx * dx + dy * dy <= outlineRadius * outlineRadius) {
                final nx = x + padding + dx;
                final ny = y + padding + dy;
                if (nx >= 0 && nx < targetW && ny >= 0 && ny < targetH) {
                  outlined.setPixel(nx, ny, whiteColor);
                }
              }
            }
          }
        }
      }
    }

    // Buoc 3: Ve chu the goc de len tren lop vien trang
    for (int y = 0; y < cutoutImage.height; y++) {
      for (int x = 0; x < cutoutImage.width; x++) {
        final pixel = cutoutImage.getPixel(x, y);
        if (pixel.a > 20) {
          outlined.setPixel(x + padding, y + padding, pixel);
        }
      }
    }

    final outPath = '${tempDir.path}/sticker_outline_$timestamp.png';
    await File(outPath).writeAsBytes(img.encodePng(outlined));
    return outPath;
  }
}
