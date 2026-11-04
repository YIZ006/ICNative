import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StickerEditMode {
  original, // 1. Original: Tách nền chủ thể sắc nét, viền mềm tự nhiên (không viền trắng)
  outline,  // 2. Outline: Tách nền chủ thể kèm viền trắng die-cut dày mượt kiểu Messages/TikTok
  full,     // 3. Full: Giữ nguyên toàn bộ bức ảnh gốc (bo góc nhẹ)
  badge,    // 4. Badge (tương thích ngược với các sticker cũ đã lưu)
}

class InAppSamplePhoto {
  final String id;
  final String title;
  final String assetPath;
  final String? pairedCutoutAsset;

  const InAppSamplePhoto({
    required this.id,
    required this.title,
    required this.assetPath,
    this.pairedCutoutAsset,
  });
}

class CustomStickerItem {
  final String id;
  final String path;
  final bool isAsset;
  final StickerEditMode mode;
  final String title;
  final String? caption;

  CustomStickerItem({
    required this.id,
    required this.path,
    this.isAsset = false,
    this.mode = StickerEditMode.outline,
    required this.title,
    this.caption,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'isAsset': isAsset,
    'mode': mode.index,
    'title': title,
    'caption': caption,
  };

  factory CustomStickerItem.fromJson(Map<String, dynamic> json) => CustomStickerItem(
    id: json['id'] as String,
    path: json['path'] as String,
    isAsset: json['isAsset'] as bool? ?? false,
    mode: StickerEditMode.values[(json['mode'] as int? ?? 1).clamp(0, StickerEditMode.values.length - 1)],
    title: json['title'] as String? ?? 'Sticker',
    caption: json['caption'] as String?,
  );
}

class _VariationIsolateInput {
  final Uint8List fullBytes;
  final Uint8List cutoutBytes;

  const _VariationIsolateInput({
    required this.fullBytes,
    required this.cutoutBytes,
  });
}

class _VariationIsolateOutput {
  final Uint8List originalPng;
  final Uint8List outlinePng;
  final Uint8List fullPng;

  const _VariationIsolateOutput({
    required this.originalPng,
    required this.outlinePng,
    required this.fullPng,
  });
}

/// Chạy hoàn toàn trong Background Isolate để không bao giờ gây đơ UI hay văng app (ANR/OOM)
_VariationIsolateOutput _renderAllVariationsIsolate(_VariationIsolateInput input) {
  img.Image? fullImg = img.decodeImage(input.fullBytes);
  img.Image? cutoutImg = img.decodeImage(input.cutoutBytes);

  fullImg ??= img.Image(width: 360, height: 360, numChannels: 4);
  cutoutImg ??= fullImg;

  // Giới hạn kích thước an toàn (tối đa 420px)
  if (fullImg.width > 420 || fullImg.height > 420) {
    fullImg = img.copyResize(
      fullImg,
      width: fullImg.width >= fullImg.height ? 420 : null,
      height: fullImg.height > fullImg.width ? 420 : null,
      interpolation: img.Interpolation.linear,
    );
  }

  if (cutoutImg.width > 380 || cutoutImg.height > 380) {
    cutoutImg = img.copyResize(
      cutoutImg,
      width: cutoutImg.width >= cutoutImg.height ? 380 : null,
      height: cutoutImg.height > cutoutImg.width ? 380 : null,
      interpolation: img.Interpolation.linear,
    );
  }

  // 1. Tạo ảnh ORIGINAL (Chủ thể đã tách nền, viền mượt tự nhiên không viền trắng)
  final Uint8List originalPng = Uint8List.fromList(img.encodePng(cutoutImg));

  // 2. Tạo ảnh OUTLINE (Chủ thể tách nền + Viền trắng dày 11px mượt mà chuẩn Messages/TikTok)
  const int outlineRadius = 11;
  const int padding = outlineRadius + 4;
  final int cw = cutoutImg.width;
  final int ch = cutoutImg.height;
  final int targetW = cw + padding * 2;
  final int targetH = ch + padding * 2;

  final outlined = img.Image(width: targetW, height: targetH, numChannels: 4);
  img.fill(outlined, color: img.ColorRgba8(0, 0, 0, 0));

  // Tìm các pixel biên của chủ thể
  final List<int> borderXs = [];
  final List<int> borderYs = [];

  for (int y = 0; y < ch; y++) {
    for (int x = 0; x < cw; x++) {
      if (cutoutImg.getPixel(x, y).a > 35) {
        if (x == 0 ||
            x == cw - 1 ||
            y == 0 ||
            y == ch - 1 ||
            cutoutImg.getPixel(x - 1, y).a <= 35 ||
            cutoutImg.getPixel(x + 1, y).a <= 35 ||
            cutoutImg.getPixel(x, y - 1).a <= 35 ||
            cutoutImg.getPixel(x, y + 1).a <= 35) {
          borderXs.add(x);
          borderYs.add(y);
        }
      }
    }
  }

  // Bản đồ khoảng cách bình phương nhỏ nhất tới biên để tạo viền trắng khử răng cưa (anti-aliased)
  final int totalPixels = targetW * targetH;
  final Int32List minDistSq = Int32List(totalPixels);
  const int inf = 1000000;
  for (int i = 0; i < totalPixels; i++) {
    minDistSq[i] = inf;
  }

  final int numBorders = borderXs.length;
  const int maxRad = outlineRadius + 1;
  const int maxRadSq = maxRad * maxRad;

  for (int i = 0; i < numBorders; i++) {
    final int cx = borderXs[i] + padding;
    final int cy = borderYs[i] + padding;
    for (int dy = -maxRad; dy <= maxRad; dy++) {
      final int ny = cy + dy;
      if (ny < 0 || ny >= targetH) continue;
      final int dySq = dy * dy;
      final int rowOffset = ny * targetW;
      for (int dx = -maxRad; dx <= maxRad; dx++) {
        final int dSq = dx * dx + dySq;
        if (dSq > maxRadSq) continue;
        final int nx = cx + dx;
        if (nx < 0 || nx >= targetW) continue;
        final int idx = rowOffset + nx;
        if (dSq < minDistSq[idx]) {
          minDistSq[idx] = dSq;
        }
      }
    }
  }

  const int innerRadSq = (outlineRadius - 1) * (outlineRadius - 1);
  for (int y = 0; y < targetH; y++) {
    final int rowOffset = y * targetW;
    for (int x = 0; x < targetW; x++) {
      final int dSq = minDistSq[rowOffset + x];
      if (dSq <= innerRadSq) {
        outlined.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
      } else if (dSq <= maxRadSq) {
        final double dist = math.sqrt(dSq.toDouble());
        final int alpha = (((maxRad - dist) / 2.0).clamp(0.0, 1.0) * 255).round();
        if (alpha > 0) {
          outlined.setPixel(x, y, img.ColorRgba8(255, 255, 255, alpha));
        }
      }
    }
  }

  // Vẽ đè chủ thể gốc lên trên lớp viền trắng với alpha blending mượt mà
  for (int y = 0; y < ch; y++) {
    for (int x = 0; x < cw; x++) {
      final p = cutoutImg.getPixel(x, y);
      final int pa = p.a.toInt();
      if (pa > 10) {
        final int tx = x + padding;
        final int ty = y + padding;
        final dst = outlined.getPixel(tx, ty);
        if (pa >= 245 || dst.a == 0) {
          outlined.setPixel(tx, ty, p);
        } else {
          // Pha trộn mềm ở rìa chủ thể với nền viền trắng
          final int invA = 255 - pa;
          final int r = (p.r.toInt() * pa + 255 * invA) ~/ 255;
          final int g = (p.g.toInt() * pa + 255 * invA) ~/ 255;
          final int b = (p.b.toInt() * pa + 255 * invA) ~/ 255;
          outlined.setPixel(tx, ty, img.ColorRgba8(r, g, b, 255));
        }
      }
    }
  }

  final Uint8List outlinePng = Uint8List.fromList(img.encodePng(outlined));

  // 3. Tạo ảnh FULL (Toàn bộ bức ảnh gốc bo góc nhẹ mượt mà)
  final int fw = fullImg.width;
  final int fh = fullImg.height;
  final fullRounded = img.Image(width: fw, height: fh, numChannels: 4);
  const double cornerRadius = 22.0;

  for (int y = 0; y < fh; y++) {
    for (int x = 0; x < fw; x++) {
      double dx = 0.0;
      double dy = 0.0;
      if (x < cornerRadius) {
        dx = cornerRadius - x;
      } else if (x >= fw - cornerRadius) {
        dx = x - (fw - 1 - cornerRadius);
      }
      if (y < cornerRadius) {
        dy = cornerRadius - y;
      } else if (y >= fh - cornerRadius) {
        dy = y - (fh - 1 - cornerRadius);
      }

      if (dx > 0 && dy > 0) {
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist > cornerRadius + 0.5) {
          fullRounded.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
          continue;
        }
      }
      final srcP = fullImg.getPixel(x, y);
      fullRounded.setPixel(
        x,
        y,
        img.ColorRgba8(srcP.r.toInt(), srcP.g.toInt(), srcP.b.toInt(), srcP.a.toInt()),
      );
    }
  }

  final Uint8List fullPng = Uint8List.fromList(img.encodePng(fullRounded));

  return _VariationIsolateOutput(
    originalPng: originalPng,
    outlinePng: outlinePng,
    fullPng: fullPng,
  );
}

class CustomStickerService {
  CustomStickerService._();
  static final CustomStickerService instance = CustomStickerService._();

  final List<CustomStickerItem> _stickers = [];
  List<CustomStickerItem> get stickers => List.unmodifiable(_stickers);

  /// Kho ảnh mẫu tích hợp sẵn trong App để người dùng test & tạo Sticker ngay lập tức
  /// mà không cần rời khỏi ứng dụng (bao gồm ảnh Mèo La Hét AAAA từ Message/TikTok)
  static const List<InAppSamplePhoto> inAppSamplePhotos = [
    InAppSamplePhoto(
      id: 'sample_cat_scream',
      title: 'Mèo AAAA',
      assetPath: 'assets/stickers/sticker_cat_scream_full.jpg',
      pairedCutoutAsset: 'assets/memes/meme_cat_scream.png',
    ),
    InAppSamplePhoto(
      id: 'sample_cat_joy',
      title: 'Mèo Cười',
      assetPath: 'assets/stickers/sticker_cat_crying_joy.jpg',
    ),
    InAppSamplePhoto(
      id: 'sample_cat_heart',
      title: 'Mèo Tim',
      assetPath: 'assets/stickers/sticker_cat_heart.jpg',
    ),
    InAppSamplePhoto(
      id: 'sample_shiba',
      title: 'Shiba Ngầu',
      assetPath: 'assets/stickers/sticker_shiba_cool.jpg',
    ),
    InAppSamplePhoto(
      id: 'sample_capybara',
      title: 'Capybara',
      assetPath: 'assets/stickers/sticker_capybara_chill.jpg',
    ),
    InAppSamplePhoto(
      id: 'sample_boba',
      title: 'Trà Sữa',
      assetPath: 'assets/stickers/sticker_boba_cute.jpg',
    ),
    InAppSamplePhoto(
      id: 'sample_bear',
      title: 'Gấu Ngủ',
      assetPath: 'assets/stickers/sticker_bear_sleepy.jpg',
    ),
  ];

  SubjectSegmenter? _segmenter;
  ObjectDetector? _objectDetector;

  SubjectSegmenter _getSegmenter() {
    return _segmenter ??= SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
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

    // 1. Ưu tiên nạp các sticker tự tạo của người dùng từ SharedPreferences lên đầu
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIds = prefs.getStringList('custom_sticker_ids') ?? [];
      for (final id in savedIds) {
        final rawPath = prefs.getString('custom_sticker_path_$id');
        final rawTitle = prefs.getString('custom_sticker_title_$id') ?? 'Custom Sticker';
        final rawMode = prefs.getInt('custom_sticker_mode_$id') ?? 1;
        final rawCaption = prefs.getString('custom_sticker_caption_$id');
        if (rawPath != null && File(rawPath).existsSync()) {
          _stickers.add(
            CustomStickerItem(
              id: id,
              path: rawPath,
              isAsset: false,
              mode: StickerEditMode.values[rawMode.clamp(0, StickerEditMode.values.length - 1)],
              title: rawTitle,
              caption: rawCaption,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading saved stickers: $e');
    }

    // 2. Bộ sưu tập Sticker mặc định sắc nét (bao gồm Mèo La Hét AAAA mới)
    _stickers.addAll([
      CustomStickerItem(
        id: 'cat_scream_aaaa',
        path: 'assets/memes/meme_cat_scream.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Mèo La Hét AAAA',
      ),
      CustomStickerItem(
        id: 'capybara_chill',
        path: 'assets/memes/meme_capybara_12.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Capybara Chill',
      ),
      CustomStickerItem(
        id: 'capybara_cute',
        path: 'assets/memes/meme_capybara_11.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Capybara Cute',
      ),
      CustomStickerItem(
        id: 'cat_smug',
        path: 'assets/memes/meme_cat_29.png',
        isAsset: true,
        mode: StickerEditMode.original,
        title: 'Mèo Cười Khẩy',
      ),
      CustomStickerItem(
        id: 'cat_derp',
        path: 'assets/memes/meme_cat_28.png',
        isAsset: true,
        mode: StickerEditMode.original,
        title: 'Mèo Ngơ Ngác',
      ),
      CustomStickerItem(
        id: 'react_heart',
        path: 'assets/memes/meme_react_22.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Bắn Tim',
      ),
      CustomStickerItem(
        id: 'react_laugh',
        path: 'assets/memes/meme_react_10.png',
        isAsset: true,
        mode: StickerEditMode.outline,
        title: 'Haha Bựa',
      ),
    ]);
  }

  Future<void> saveCustomSticker(CustomStickerItem item) async {
    _stickers.removeWhere((s) => s.id == item.id);
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
      if (item.caption != null) {
        await prefs.setString('custom_sticker_caption_${item.id}', item.caption!);
      }
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

  /// Tách nền chủ thể khỏi ảnh một cách an toàn tuyệt đối (có timeout, không bao giờ gây crash)
  Future<Uint8List> _extractForegroundBytes(
    String sourcePath,
    String localPath,
    Uint8List fullBytes,
  ) async {
    // 0. Nếu là ảnh mẫu trong app có sẵn bản tách nền chuẩn (ví dụ Mèo AAAA)
    for (final sample in inAppSamplePhotos) {
      if (sample.assetPath == sourcePath && sample.pairedCutoutAsset != null) {
        try {
          final bd = await rootBundle.load(sample.pairedCutoutAsset!);
          return bd.buffer.asUint8List();
        } catch (_) {}
      }
    }

    final baseImage = img.decodeImage(fullBytes);
    if (baseImage == null) return fullBytes;

    // 1. Nếu ảnh đã là PNG trong suốt sẵn
    if (_hasTransparency(baseImage)) {
      return fullBytes;
    }

    // 2. Nếu ảnh có viền nền đồng màu ở 4 góc (như các sticker mẫu trong assets/stickers/*.jpg)
    //    tách nền nhanh bằng flood-fill màu nền góc trước khi gọi ML Kit
    final cornerCutout = _tryCornerFloodFillCutout(baseImage);
    if (cornerCutout != null) {
      return Uint8List.fromList(img.encodePng(cornerCutout));
    }

    // 3. Thử dùng Google ML Kit Subject Segmentation on-device (có timeout 3.5s chống treo/văng)
    if (!Platform.isIOS) {
      try {
        final inputImage = InputImage.fromFilePath(localPath);
        final segResult = await _getSegmenter()
            .processImage(inputImage)
            .timeout(const Duration(milliseconds: 3500));

        if (segResult.foregroundBitmap != null && segResult.foregroundBitmap!.isNotEmpty) {
          return segResult.foregroundBitmap!;
        }
      } catch (e) {
        debugPrint('SubjectSegmenter safe fallback: $e');
      }
    }

    // 4. Fallback thông minh: Phát hiện vật thể (Object Detection) hoặc cắt silhouette elip mềm
    try {
      final inputImage = InputImage.fromFilePath(localPath);
      final objects = await _getObjectDetector()
          .processImage(inputImage)
          .timeout(const Duration(milliseconds: 2500));

      if (objects.isNotEmpty) {
        var bestObj = objects.first;
        double maxArea = bestObj.boundingBox.width * bestObj.boundingBox.height;
        for (final o in objects) {
          final a = o.boundingBox.width * o.boundingBox.height;
          if (a > maxArea) {
            maxArea = a;
            bestObj = o;
          }
        }

        final box = bestObj.boundingBox;
        final cropX = box.left.clamp(0, baseImage.width - 1).toInt();
        final cropY = box.top.clamp(0, baseImage.height - 1).toInt();
        final cropW = box.width.clamp(32, baseImage.width - cropX).toInt();
        final cropH = box.height.clamp(32, baseImage.height - cropY).toInt();

        final cropped = img.copyCrop(baseImage, x: cropX, y: cropY, width: cropW, height: cropH);
        return Uint8List.fromList(img.encodePng(_softOvalMask(cropped)));
      }
    } catch (_) {}

    // 5. Fallback cuối cùng: Cắt chủ thể trung tâm với viền mềm
    final cropSize = math.min(baseImage.width, baseImage.height);
    final square = img.copyCrop(
      baseImage,
      x: (baseImage.width - cropSize) ~/ 2,
      y: (baseImage.height - cropSize) ~/ 2,
      width: cropSize,
      height: cropSize,
    );
    return Uint8List.fromList(img.encodePng(_softOvalMask(square)));
  }

  /// Tách nền nhanh cho ảnh có màu nền đồng nhất ở các góc (trắng/kem/đen)
  img.Image? _tryCornerFloodFillCutout(img.Image src) {
    final int w = src.width;
    final int h = src.height;
    if (w < 40 || h < 40) return null;

    final c0 = src.getPixel(2, 2);
    final c1 = src.getPixel(w - 3, 2);
    final c2 = src.getPixel(2, h - 3);
    final c3 = src.getPixel(w - 3, h - 3);

    int colorDist(img.Pixel a, img.Pixel b) {
      final dr = (a.r - b.r).abs().toInt();
      final dg = (a.g - b.g).abs().toInt();
      final db = (a.b - b.b).abs().toInt();
      return math.max(dr, math.max(dg, db));
    }

    // Kiểm tra ít nhất 2 góc với c0 có màu tương đồng nhau (nền đồng nhất)
    if (colorDist(c0, c1) > 35 && colorDist(c0, c2) > 35 && colorDist(c0, c3) > 35) {
      return null;
    }

    final int bgR = c0.r.toInt();
    final int bgG = c0.g.toInt();
    final int bgB = c0.b.toInt();
    const int threshold = 38;

    final Uint8List visited = Uint8List(w * h);
    final List<int> queue = [];

    bool isBgColor(int x, int y) {
      final p = src.getPixel(x, y);
      final dr = (p.r.toInt() - bgR).abs();
      final dg = (p.g.toInt() - bgG).abs();
      final db = (p.b.toInt() - bgB).abs();
      return dr <= threshold && dg <= threshold && db <= threshold;
    }

    for (int x = 0; x < w; x++) {
      if (isBgColor(x, 0)) {
        visited[x] = 1;
        queue.add(x);
      }
      final botIdx = (h - 1) * w + x;
      if (isBgColor(x, h - 1) && visited[botIdx] == 0) {
        visited[botIdx] = 1;
        queue.add(botIdx);
      }
    }
    for (int y = 0; y < h; y++) {
      final leftIdx = y * w;
      if (isBgColor(0, y) && visited[leftIdx] == 0) {
        visited[leftIdx] = 1;
        queue.add(leftIdx);
      }
      final rightIdx = y * w + (w - 1);
      if (isBgColor(w - 1, y) && visited[rightIdx] == 0) {
        visited[rightIdx] = 1;
        queue.add(rightIdx);
      }
    }

    int head = 0;
    while (head < queue.length) {
      final curr = queue[head++];
      final cx = curr % w;
      final cy = curr ~/ w;

      if (cx > 0) {
        final ni = curr - 1;
        if (visited[ni] == 0 && isBgColor(cx - 1, cy)) {
          visited[ni] = 1;
          queue.add(ni);
        }
      }
      if (cx < w - 1) {
        final ni = curr + 1;
        if (visited[ni] == 0 && isBgColor(cx + 1, cy)) {
          visited[ni] = 1;
          queue.add(ni);
        }
      }
      if (cy > 0) {
        final ni = curr - w;
        if (visited[ni] == 0 && isBgColor(cx, cy - 1)) {
          visited[ni] = 1;
          queue.add(ni);
        }
      }
      if (cy < h - 1) {
        final ni = curr + w;
        if (visited[ni] == 0 && isBgColor(cx, cy + 1)) {
          visited[ni] = 1;
          queue.add(ni);
        }
      }
    }

    final int bgCount = queue.length;
    final int total = w * h;
    // Nếu vùng nền chiếm từ 8% đến 92% diện tích ảnh thì hợp lệ
    if (bgCount < total * 0.08 || bgCount > total * 0.92) {
      return null;
    }

    final out = img.Image(width: w, height: h, numChannels: 4);
    for (int y = 0; y < h; y++) {
      final row = y * w;
      for (int x = 0; x < w; x++) {
        if (visited[row + x] == 1) {
          out.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        } else {
          final p = src.getPixel(x, y);
          // Làm mềm rìa 1px nếu sát nền
          int adjBg = 0;
          if (x > 0 && visited[row + x - 1] == 1) adjBg++;
          if (x < w - 1 && visited[row + x + 1] == 1) adjBg++;
          if (y > 0 && visited[row - w + x] == 1) adjBg++;
          if (y < h - 1 && visited[row + w + x] == 1) adjBg++;
          final int alpha = adjBg >= 2 ? 180 : (adjBg == 1 ? 230 : 255);
          out.setPixel(x, y, img.ColorRgba8(p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha));
        }
      }
    }
    return out;
  }

  img.Image _softOvalMask(img.Image src) {
    final int w = src.width;
    final int h = src.height;
    final result = img.Image(width: w, height: h, numChannels: 4);
    final cx = w / 2.0;
    final cy = h / 2.0;
    final rx = w * 0.46;
    final ry = h * 0.46;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final dx = (x - cx) / rx;
        final dy = (y - cy) / ry;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 0.92) {
          final p = src.getPixel(x, y);
          result.setPixel(x, y, img.ColorRgba8(p.r.toInt(), p.g.toInt(), p.b.toInt(), 255));
        } else if (dist <= 1.05) {
          final p = src.getPixel(x, y);
          final alpha = (((1.05 - dist) / 0.13).clamp(0.0, 1.0) * 255).round();
          result.setPixel(x, y, img.ColorRgba8(p.r.toInt(), p.g.toInt(), p.b.toInt(), alpha));
        } else {
          result.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }
    return result;
  }

  /// Sinh đồng thời cả 3 biến thể (`Original`, `Outline`, `Full`) trong 1 lần duy nhất
  /// bằng Background Isolate để cả 3 ô thumbnail hiển thị tức thì giống hệt Google Messages / TikTok.
  Future<Map<StickerEditMode, String>> generateAllStickerVariations({
    required String sourcePath,
    required bool isAsset,
  }) async {
    final localPath = await _ensureLocalFile(sourcePath, isAsset);
    final fullBytes = await File(localPath).readAsBytes();
    final cutoutBytes = await _extractForegroundBytes(sourcePath, localPath, fullBytes);

    final rendered = await compute(
      _renderAllVariationsIsolate,
      _VariationIsolateInput(
        fullBytes: fullBytes,
        cutoutBytes: cutoutBytes,
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;

    final origPath = '${tempDir.path}/sticker_original_$ts.png';
    final outlinePath = '${tempDir.path}/sticker_outline_$ts.png';
    final fullPath = '${tempDir.path}/sticker_full_$ts.png';

    await Future.wait([
      File(origPath).writeAsBytes(rendered.originalPng),
      File(outlinePath).writeAsBytes(rendered.outlinePng),
      File(fullPath).writeAsBytes(rendered.fullPng),
    ]);

    return {
      StickerEditMode.original: origPath,
      StickerEditMode.outline: outlinePath,
      StickerEditMode.full: fullPath,
      StickerEditMode.badge: outlinePath,
    };
  }

  /// Hàm tương thích đơn lẻ
  Future<String> generateStickerVariation({
    required String sourcePath,
    required bool isAsset,
    required StickerEditMode mode,
    String? caption,
  }) async {
    final all = await generateAllStickerVariations(
      sourcePath: sourcePath,
      isAsset: isAsset,
    );
    return all[mode] ?? all[StickerEditMode.outline]!;
  }
}
