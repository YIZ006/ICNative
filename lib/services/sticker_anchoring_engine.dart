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

    // Helper: Lấy meme từ kho 115 meme phong phú (Cat, Capybara, React)
    StickerMetadata fromLegacyPool(
      String id,
      List<String> pool, {
      AnchorPreference pref = AnchorPreference.topEdge,
      Offset bite = const Offset(0.5, 0.85),
    }) {
      final path = pool[rand.nextInt(pool.length)];
      final meta = BiteMeta.lookup(biteMetaMap, path);
      return StickerMetadata(
        id: id,
        assetPath: path,
        category: category,
        preference: pref,
        bitePoint: meta != BiteMeta.fallback ? meta.bite : bite,
        biteDirection: meta.dir,
        widthFactor: meta.width,
      );
    }

    // Helper: Lấy meme từ pool bite (chỉ áp dụng cho food, beverage, person)
    StickerMetadata fromBitePool(String id) {
      if (bitePool.isNotEmpty) {
        final path = bitePool[rand.nextInt(bitePool.length)];
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
      return fromLegacyPool(id, [...funnyMemes, ...catMemes]);
    }

    switch (category) {
      case StickerCategory.food:
        // Đồ ăn (bánh ngọt, đồ ăn vặt, mì...) -> Meme cắn mép đồ ăn khi có pool bite
        if (bitePool.isNotEmpty) {
          return fromBitePool('food_bite');
        }
        return fromLegacyPool('food_meme', funnyMemes, pref: AnchorPreference.center);

      case StickerCategory.beverage:
        // Đồ uống (ly trà sữa, cốc nước, tách cafe...) -> Meme cắn miệng ly khi có pool bite, rỗng -> hug
        if (bitePool.isNotEmpty) {
          return fromBitePool('drink_bite');
        }
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

      case StickerCategory.person:
        // Con người, selfie, chân dung -> Cắn selfie vui nhộn khi có pool bite
        if (bitePool.isNotEmpty) {
          return fromBitePool('selfie_bite');
        }
        return fromLegacyPool('person_funny', funnyMemes, pref: AnchorPreference.center);

      case StickerCategory.animal:
        // Thú cưng, chó mèo -> Chọn từ kho 29 meme mèo bựa & cute (TUYỆT ĐỐI không cắn, ôm nhẹ giữa vật thể)
        return fromLegacyPool('animal_cat', catMemes, pref: AnchorPreference.center);

      case StickerCategory.electronics:
        // Công nghệ, laptop, máy tính, điện thoại -> Meme mèo gõ phím / tech, ôm giữa vật thể
        return fromLegacyPool('tech_cat', catMemes, pref: AnchorPreference.center);

      case StickerCategory.general:
        // Đồ vật thông thường (bàn, ghế, giá đỡ, móc khóa, đồ chơi, sách vở...)
        // -> Chọn ngẫu nhiên phong phú từ toàn bộ 115 meme (Mèo, Capybara, Reaction), ôm giữa hoặc đặt cạnh, KHÔNG cắn mép
        return fromLegacyPool('general_meme', allMemes, pref: AnchorPreference.center);

      case StickerCategory.scene:
        // Không có vật thể rõ ràng (chụp cảnh) -> Capybara chill ngâm bồn, đội cam ở đáy
        return fromLegacyPool(
          'scene_capybara',
          capybaraMemes,
          pref: AnchorPreference.bottomScene,
          bite: const Offset(0.5, 1.0),
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
        segmenterFuture.then<dynamic>((v) => v).catchError((_) => null),
      ]);

      final objects = (results[0] as List<DetectedObject>?) ?? [];
      final labels = (results[1] as List<ImageLabel>?) ?? [];
      final bitePool = (results[2] as List<String>?) ?? const [];
      final biteMetaMap = (results[3] as Map<String, BiteMeta>?) ?? const {};
      final segResult = results[4] as SubjectSegmentationResult?;

      // 2. Tìm vật thể chính trong ảnh:
      // Ưu tiên cao nhất cho SubjectSegmenter (nhận diện hình khối pixel thực tế của vật thể)
      Rect? targetRect;
      double maxArea = 0;
      List<double>? subjectMask;
      int maskWidth = 0;
      int maskHeight = 0;

      if (segResult != null && segResult.subjects.isNotEmpty) {
        for (final subj in segResult.subjects) {
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
            maskWidth = subj.width;
            maskHeight = subj.height;
          }
        }
      }

      // Fallback: nếu SubjectSegmenter không tìm thấy (trên iOS hoặc ảnh quá mờ), mới dùng ObjectDetector
      if (targetRect == null) {
        for (final obj in objects) {
          final area = (obj.boundingBox.width * obj.boundingBox.height).toDouble();
          if (area > maxArea) {
            maxArea = area;
            targetRect = obj.boundingBox;
          }
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
      //    (mặt nạ tách chủ thể hoặc gradient biên vật thể). Không có mặt nạ/biên thì dùng bbox.
      ObjectAnchor? anchor;
      if (hasClearObject && origW > 0 && origH > 0) {
        anchor = await _buildAnchor(
          imageSize: ui.Size(origW, origH),
          detectedBounds: targetRect,
          subjectMask: subjectMask,
          maskWidth: maskWidth,
          maskHeight: maskHeight,
          imageBytes: bytes,
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

  /// Trích xuất các điểm viền biên (edge points) từ độ tương phản pixel (Sobel/Gradient)
  /// trong vùng bounding box của vật thể. Hoàn toàn 0 VNĐ & 100% Offline (~10ms).
  static Future<List<ui.Offset>> extractObjectEdgePoints({
    required Uint8List imageBytes,
    required ui.Size origSize,
    required Rect bounds,
  }) async {
    try {
      final double scale = 480.0 / origSize.width;
      const int targetW = 480;
      final int targetH = (origSize.height * scale).round();
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      codec.dispose();
      if (byteData == null) return [];

      final buffer = byteData.buffer.asUint8List();
      final bLeft = (bounds.left * scale).toInt().clamp(0, targetW - 3);
      final bTop = (bounds.top * scale).toInt().clamp(0, targetH - 3);
      final bRight = (bounds.right * scale).toInt().clamp(bLeft + 2, targetW - 1);
      final bBottom = (bounds.bottom * scale).toInt().clamp(bTop + 2, targetH - 1);

      final points = <ui.Offset>[];
      const int step = 2;
      final invScale = 1.0 / scale;

      for (int y = bTop + 2; y < bBottom - 2; y += step) {
        final rowOffset = y * targetW * 4;
        final nextRowOffset = (y + 2) * targetW * 4;
        for (int x = bLeft + 2; x < bRight - 2; x += step) {
          final idx = rowOffset + x * 4;
          final idxRight = rowOffset + (x + 2) * 4;
          final idxDown = nextRowOffset + x * 4;

          final r = buffer[idx];
          final g = buffer[idx + 1];
          final b = buffer[idx + 2];

          final rR = buffer[idxRight];
          final gR = buffer[idxRight + 1];
          final bR = buffer[idxRight + 2];

          final rD = buffer[idxDown];
          final gD = buffer[idxDown + 1];
          final bD = buffer[idxDown + 2];

          final diff = ((r - rR).abs() + (g - gR).abs() + (b - bR).abs() +
                        (r - rD).abs() + (g - gD).abs() + (b - bD).abs()) ~/ 6;

          if (diff > 26) {
            points.add(ui.Offset(x * invScale, y * invScale));
          }
        }
      }
      return points;
    } catch (e) {
      debugPrint('extractObjectEdgePoints error: $e');
      return [];
    }
  }

  /// Dựng [ObjectAnchor] cho vật thể mà AI tìm thấy.
  /// Ưu tiên trích xuất đường viền từ mặt nạ phân vùng pixel thực tế (Người/Thú cưng),
  /// hoặc từ gradient viền đối tượng (Bàn phím, Ghế, Đồ vật, Đồ ăn).
  static Future<ObjectAnchor?> _buildAnchor({
    required ui.Size imageSize,
    required Rect detectedBounds,
    required List<double>? subjectMask,
    required int maskWidth,
    required int maskHeight,
    Uint8List? imageBytes,
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

    // 1. Ưu tiên cao nhất: Mặt nạ phân vùng pixel từ SubjectSegmenter (Người / Thú cưng)
    if (subjectMask != null &&
        maskWidth > 0 &&
        maskHeight > 0 &&
        subjectMask.length == maskWidth * maskHeight) {
      return AnchorMath.anchorFromMask(
        imageSize: imageSize,
        bounds: bounds,
        mask: BinaryMask.fromConfidence(subjectMask, maskWidth, maskHeight),
      );
    }

    // 2. Nhận diện đường viền biên thực tế cho vật thể (Bàn phím, Ghế, Laptop, Đồ ăn...) qua gradient
    if (imageBytes != null && bounds.width > 20 && bounds.height > 20) {
      final edgePoints = await extractObjectEdgePoints(
        imageBytes: imageBytes,
        origSize: imageSize,
        bounds: bounds,
      );
      if (edgePoints.isNotEmpty) {
        return AnchorMath.anchorFromEdgePoints(
          imageSize: imageSize,
          bounds: bounds,
          points: edgePoints,
        );
      }
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
