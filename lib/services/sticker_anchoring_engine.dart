import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:icnative/services/anchor_math.dart';

enum StickerCategory { food, beverage, general, scene, person, animal, electronics }
enum AnchorPreference { topEdge, bottomEdge, center, bottomScene }

class StickerMetadata {
  final String id;
  final String assetPath;
  final StickerCategory category;
  final AnchorPreference preference;
  final ui.Offset bitePoint; // 0.0 to 1.0
  final ui.Offset biteDirection;
  final double widthFactor;

  /// Hình học vật thể trong ảnh gốc (Bước 1-2). null khi không có vật thể rõ ràng.
  final ObjectAnchor? anchor;

  /// Kích thước pixel của file PNG sticker (để tính contain-fit cho bitePoint).
  final ui.Size? stickerPixelSize;

  const StickerMetadata({
    required this.id,
    required this.assetPath,
    required this.category,
    required this.preference,
    required this.bitePoint,
    this.biteDirection = BiteMeta.defaultDir,
    this.widthFactor = BiteMeta.defaultWidth,
    this.anchor,
    this.stickerPixelSize,
  });

  /// Chế độ neo tương ứng cho solver (Bước 3).
  AnchorMode get anchorMode {
    switch (preference) {
      case AnchorPreference.topEdge:
        return AnchorMode.topEdge;
      case AnchorPreference.center:
        return AnchorMode.hug;
      case AnchorPreference.bottomEdge:
      case AnchorPreference.bottomScene:
        return AnchorMode.scene;
    }
  }

  StickerMetadata copyWith({
    String? id,
    String? assetPath,
    StickerCategory? category,
    AnchorPreference? preference,
    ui.Offset? bitePoint,
    ui.Offset? biteDirection,
    double? widthFactor,
    ObjectAnchor? anchor,
    ui.Size? stickerPixelSize,
  }) {
    return StickerMetadata(
      id: id ?? this.id,
      assetPath: assetPath ?? this.assetPath,
      category: category ?? this.category,
      preference: preference ?? this.preference,
      bitePoint: bitePoint ?? this.bitePoint,
      biteDirection: biteDirection ?? this.biteDirection,
      widthFactor: widthFactor ?? this.widthFactor,
      anchor: anchor ?? this.anchor,
      stickerPixelSize: stickerPixelSize ?? this.stickerPixelSize,
    );
  }
}

class StickerAnchoringEngine {
  static const String biteDirPrefix = 'assets/memes/bite/';
  static const String biteMetaAssetPath = 'assets/memes/bite/bite_meta.json';

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

  static Map<String, BiteMeta>? _cachedBiteMeta;
  static List<String>? _cachedBitePool;

  static bool isBiteAssetPath(String path) => path.startsWith(biteDirPrefix);

  /// Đọc và cache `assets/memes/bite/bite_meta.json` đúng 1 lần.
  static Future<Map<String, BiteMeta>> loadBiteMetaMap() async {
    final cached = _cachedBiteMeta;
    if (cached != null) return cached;
    try {
      final rawJson = await rootBundle.loadString(biteMetaAssetPath);
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final parsed = BiteMeta.parseJsonMap(decoded);
        _cachedBiteMeta = parsed;
        return parsed;
      } else if (decoded is Map) {
        final parsed = BiteMeta.parseJsonMap(Map<String, dynamic>.from(decoded));
        _cachedBiteMeta = parsed;
        return parsed;
      }
    } catch (e) {
      debugPrint('BiteMeta JSON fallback (chưa có hoặc lỗi đọc): $e');
    }
    _cachedBiteMeta = const {};
    return _cachedBiteMeta!;
  }

  /// Lấy `BiteMeta` cho 1 đường dẫn asset (không có trong JSON thì trả mặc định).
  static Future<BiteMeta> getBiteMetaForAsset(String assetPath) async {
    final map = await loadBiteMetaMap();
    return BiteMeta.lookup(map, assetPath);
  }

  /// Liệt kê các ảnh meme "cắn" thực sự tồn tại trong `assets/memes/bite/`.
  /// Nếu thư mục chưa có file PNG/WebP nào -> trả rỗng để fallback về hành vi cũ, không crash.
  static Future<List<String>> getAvailableBiteAssets() async {
    final cached = _cachedBitePool;
    if (cached != null) return cached;

    final metaMap = await loadBiteMetaMap();
    final found = <String>{};

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith(biteDirPrefix)) continue;
        final lower = asset.toLowerCase();
        if (lower.endsWith('.png') || lower.endsWith('.webp')) {
          found.add(asset);
        }
      }
    } catch (_) {
      for (final key in metaMap.keys) {
        final candidate = key.startsWith('assets/') ? key : '$biteDirPrefix$key';
        final lower = candidate.toLowerCase();
        if ((lower.endsWith('.png') || lower.endsWith('.webp')) &&
            await loadStickerPixelSize(candidate) != null) {
          found.add(candidate);
        }
      }
    }

    final sorted = found.toList()..sort();
    _cachedBitePool = List.unmodifiable(sorted);
    return _cachedBitePool!;
  }

  static StickerMetadata pickStickerForCategory(
    StickerCategory category, {
    List<String> bitePool = const [],
    Map<String, BiteMeta> biteMetaMap = const {},
  }) {
    final rand = math.Random();

    if (category == StickerCategory.scene) {
      // KHÔNG CÓ VẬT THỂ RÕ RÀNG -> Chụp phong cảnh thư giãn -> Capybara chill ngâm bồn, đội cam
      final path = capybaraMemes[rand.nextInt(capybaraMemes.length)];
      return StickerMetadata(
        id: 'scene_capybara',
        assetPath: path,
        category: StickerCategory.scene,
        preference: AnchorPreference.bottomScene,
        bitePoint: const ui.Offset(0.5, 1.0),
        biteDirection: BiteMeta.defaultDir,
        widthFactor: 0.30,
      );
    }

    // Nếu pool meme "cắn" có ≥ 1 ảnh: mọi category có vật thể rõ ràng (kể cả beverage)
    // đều chọn ngẫu nhiên từ pool bite và neo cắn mép (`topEdge`).
    if (bitePool.isNotEmpty) {
      final path = bitePool[rand.nextInt(bitePool.length)];
      final meta = BiteMeta.lookup(biteMetaMap, path);
      return StickerMetadata(
        id: 'bite_${category.name}',
        assetPath: path,
        category: category,
        preference: AnchorPreference.topEdge,
        bitePoint: meta.bite,
        biteDirection: meta.dir,
        widthFactor: meta.width,
      );
    }

    // Fallback khi thư mục `assets/memes/bite/` chưa có ảnh PNG: giữ hành vi cũ,
    // nhưng đọc `bitePoint`, `biteDirection`, `width` qua `BiteMeta` thay vì hằng cứng.
    StickerMetadata fromLegacyPool(String id, List<String> pool) {
      final path = pool[rand.nextInt(pool.length)];
      final meta = BiteMeta.lookup(biteMetaMap, path);
      return StickerMetadata(
        id: id,
        assetPath: path,
        category: category,
        preference: AnchorPreference.topEdge,
        bitePoint: meta.bite,
        biteDirection: meta.dir,
        widthFactor: meta.width,
      );
    }

    switch (category) {
      case StickerCategory.animal:
        // Động vật, thú cưng, chó mèo -> Chọn từ kho 29 meme mèo bựa & cute
        return fromLegacyPool('animal_cat', catMemes);
      case StickerCategory.person:
        // Con người, khuôn mặt, selfie -> Chọn từ kho 64 meme biểu cảm hài hước
        return fromLegacyPool('person_funny', funnyMemes);
      case StickerCategory.food:
        // Đồ ăn -> Chọn từ các meme thèm ăn, há miệng háo hức trong funnyMemes & catMemes
        return fromLegacyPool('food_meme', [...funnyMemes, ...catMemes]);
      case StickerCategory.beverage:
        // Đồ uống (chỉ dùng `hug` khi pool bite rỗng)
        final drinkPool = [...funnyMemes, ...catMemes];
        final path = drinkPool[rand.nextInt(drinkPool.length)];
        return StickerMetadata(
          id: 'drink_meme',
          assetPath: path,
          category: StickerCategory.beverage,
          preference: AnchorPreference.center,
          bitePoint: const ui.Offset(0.5, 0.5),
          biteDirection: BiteMeta.defaultDir,
          widthFactor: StickerPlacementSolver.hugWidthFactor,
        );
      case StickerCategory.electronics:
        // Công nghệ, laptop, máy tính, điện thoại -> Meme mèo gõ phím, công nghệ
        return fromLegacyPool('tech_cat', catMemes);
      case StickerCategory.general:
        // CÓ VẬT THỂ RÕ RÀNG NHƯNG LÀ ĐỒ VẬT KHÁC (móc khóa, bàn làm việc, đồ chơi, sách vở...)
        // -> Chọn ngẫu nhiên phong phú từ toàn bộ 115 meme (Mèo, Capybara, Reaction)
        return fromLegacyPool('general_meme', allMemes);
      case StickerCategory.scene:
        // Đã xử lý ở trên
        return fromLegacyPool('scene_capybara', capybaraMemes);
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

      // 1. Chạy song song ObjectDetector, ImageLabeler và nạp BiteMeta cache
      final detectorFuture = _getObjectDetector().processImage(inputImage);
      final labelerFuture = _getLabeler().processImage(inputImage);
      final bitePoolFuture = getAvailableBiteAssets();
      final biteMetaFuture = loadBiteMetaMap();

      // Tách chủ thể (chỉ Android) chạy song song để lấy đường viền thật cho
      // Bước 2. Có timeout để không bao giờ giữ màn hình "AI đang nhận diện".
      final Future<SubjectSegmentationResult?> segmenterFuture = Platform.isIOS
          ? Future<SubjectSegmentationResult?>.value(null)
          : _getSegmenter()
              .processImage(inputImage)
              .then<SubjectSegmentationResult?>((v) => v)
              .timeout(const Duration(seconds: 4), onTimeout: () => null)
              .catchError((_) => null);

      final results = await Future.wait([
        detectorFuture.then<dynamic>((v) => v).catchError((_) => <DetectedObject>[]),
        labelerFuture.then<dynamic>((v) => v).catchError((_) => <ImageLabel>[]),
        bitePoolFuture,
        biteMetaFuture,
      ]);

      final objects = (results[0] as List<DetectedObject>?) ?? [];
      final labels = (results[1] as List<ImageLabel>?) ?? [];
      final bitePool = (results[2] as List<String>?) ?? const [];
      final biteMetaMap = (results[3] as Map<String, BiteMeta>?) ?? const {};

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

      final metadata = pickStickerForCategory(
        category,
        bitePool: bitePool,
        biteMetaMap: biteMetaMap,
      );

      // 4. Bước 2 của đặc tả: lấy đỉnh + tiếp tuyến mép trên từ đường viền thật
      //    (mặt nạ tách chủ thể). Không có mặt nạ thì dùng bbox (đỉnh = giữa cạnh trên).
      ObjectAnchor? anchor;
      if (hasClearObject && origW > 0 && origH > 0) {
        anchor = await _buildAnchor(
          imageSize: ui.Size(origW, origH),
          detectedBounds: targetRect,
          segmenterFuture: segmenterFuture,
        );
      }

      return metadata.copyWith(
        anchor: anchor,
        stickerPixelSize: await loadStickerPixelSize(metadata.assetPath),
      );
    } catch (e) {
      debugPrint('detectAndSuggestSticker Error: $e');
      return null;
    }
  }

  /// Dựng [ObjectAnchor] cho vật thể mà ObjectDetector tìm thấy.
  /// Trả null (-> chế độ cảnh) nếu toạ độ ML Kit không khớp không gian ảnh
  /// (ví dụ lệch hướng EXIF), vì neo sai còn tệ hơn không neo.
  static Future<ObjectAnchor?> _buildAnchor({
    required ui.Size imageSize,
    required Rect detectedBounds,
    required Future<SubjectSegmentationResult?> segmenterFuture,
  }) async {
    const tolerance = 1.05;
    if (detectedBounds.right > imageSize.width * tolerance ||
        detectedBounds.bottom > imageSize.height * tolerance) {
      debugPrint('Anchor skipped: bbox $detectedBounds vượt ảnh $imageSize');
      return null;
    }

    final bounds = detectedBounds.intersect(
      Rect.fromLTWH(0, 0, imageSize.width, imageSize.height),
    );

    try {
      final seg = await segmenterFuture;
      final subjects = seg?.subjects ?? const [];
      if (subjects.isNotEmpty) {
        final rects = [
          for (final s in subjects)
            Rect.fromLTWH(
              s.startX.toDouble(),
              s.startY.toDouble(),
              s.width.toDouble(),
              s.height.toDouble(),
            ),
        ];
        final idx = AnchorMath.bestOverlapIndex(bounds, rects);
        if (idx >= 0) {
          final s = subjects[idx];
          final confidence = s.confidenceMask;
          if (confidence != null &&
              s.width > 0 &&
              s.height > 0 &&
              confidence.length == s.width * s.height) {
            return AnchorMath.anchorFromMask(
              imageSize: imageSize,
              bounds: rects[idx],
              mask: BinaryMask.fromConfidence(confidence, s.width, s.height),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Subject mask unavailable, dùng bbox: $e');
    }

    return ObjectAnchor.fromBounds(imageSize, bounds);
  }

  static final Map<String, ui.Size> _stickerSizeCache = {};

  /// Kích thước pixel của PNG sticker, chỉ đọc header (không decode ảnh).
  static Future<ui.Size?> loadStickerPixelSize(String assetPath) async {
    final cached = _stickerSizeCache[assetPath];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(assetPath);
      final buffer = await ui.ImmutableBuffer.fromUint8List(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final size = ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
        descriptor.dispose();
        _stickerSizeCache[assetPath] = size;
        return size;
      } finally {
        buffer.dispose();
      }
    } catch (e) {
      debugPrint('loadStickerPixelSize($assetPath) failed: $e');
      return null;
    }
  }

  /// Kích thước pixel của file sticker cục bộ (tạo từ thư viện máy), chỉ đọc header.
  static Future<ui.Size?> loadFileStickerPixelSize(String filePath) async {
    final cacheKey = 'file:$filePath';
    final cached = _stickerSizeCache[cacheKey];
    if (cached != null) return cached;
    try {
      final bytes = await File(filePath).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        final size = ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
        descriptor.dispose();
        _stickerSizeCache[cacheKey] = size;
        return size;
      } finally {
        buffer.dispose();
      }
    } catch (e) {
      debugPrint('loadFileStickerPixelSize($filePath) failed: $e');
      return null;
    }
  }
}
