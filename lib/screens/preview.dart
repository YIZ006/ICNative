import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import 'package:icnative/screens/sticker_generator_sheet.dart';
import 'package:icnative/services/anchor_math.dart';
import 'package:icnative/services/auth_service.dart';
import 'package:icnative/services/custom_sticker_service.dart';
import 'package:icnative/services/location_service.dart';
import 'package:icnative/services/sticker_anchoring_engine.dart';
import 'package:icnative/services/sync_service.dart';
import 'package:icnative/settings/global.dart';
import 'package:icnative/settings/theme_colors.dart';

class ImagePreview extends StatefulWidget {
  const ImagePreview({
    super.key,
    required this.imagePath,
    required this.onSend,
  });

  final String imagePath;
  final void Function() onSend;

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  late String currentImagePath;
  final TextEditingController _captionController = TextEditingController();

  bool isProcessingAi = true;
  bool isSending = false;

  // Sticker meme tự động neo vào mép vật thể (khoá chỉnh tay / xoá)
  CustomStickerItem? activeCustomSticker;
  Offset stickerPosition = const Offset(0.55, 0.15); // Ti le 0.0 -> 1.0 tren khung anh
  double stickerScale = 1.0;
  double stickerRotation = 0.05;
  bool stickerFlipX = false;
  ObjectAnchor? _anchor;
  AnchorMode _detectedMode = AnchorMode.topEdge;
  Offset _activeBitePoint = BiteMeta.defaultBite;
  Size _activeStickerPixelSize = Size.zero;
  Offset? _debugTargetInFrame;
  List<CustomStickerItem> _biteTrayItems = const [];
  StickerCategory _detectedCategory = StickerCategory.scene;
  late bool _showDebugBoundingBox = isDemoModeNotifier.value;

  // Location & Time Badges
  String? locationBadgeText;
  bool isDetectingLocation = false;
  Offset locationBadgePosition = const Offset(0.06, 0.06);

  String? timeBadgeText;
  Offset timeBadgePosition = const Offset(0.66, 0.06);

  Future<void> _toggleLocationBadge() async {
    if (locationBadgeText != null) {
      setState(() => locationBadgeText = null);
      return;
    }

    setState(() => isDetectingLocation = true);
    String? statusMessage;
    final result = await LocationService.instance.getCurrentLocationWithSmartName(
      onStatusMessage: (msg) => statusMessage = msg,
    );
    if (mounted) {
      setState(() {
        isDetectingLocation = false;
        if (result != null) {
          locationBadgeText = '📍 ${result.displayName}';
        }
      });
      if (result == null && statusMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusMessage!),
            backgroundColor: OrbitColors.buttonPrimary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleTimeBadge() {
    setState(() {
      if (timeBadgeText != null) {
        timeBadgeText = null;
      } else {
        final now = DateTime.now();
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        timeBadgeText = '🕒 $hh:$mm';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    currentImagePath = widget.imagePath;
    _runAiContextualEngine();
    CustomStickerService.instance.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Cạnh ô ảnh preview vuông. Dùng chung cho build() và bước neo sticker.
  static double _boxSizeFor(double screenWidth) => (screenWidth - 36).clamp(240.0, 380.0);

  /// 1. Tự động chạy mô hình On-Device AI nhận diện bối cảnh và gắn sticker meme thông minh (0 VNĐ, Offline)
  Future<void> _runAiContextualEngine() async {
    try {
      final biteAssetsFuture = StickerAnchoringEngine.getAvailableBiteAssets();
      final suggested = await StickerAnchoringEngine.detectAndSuggestSticker(widget.imagePath);
      final biteAssets = await biteAssetsFuture;

      final resolved = suggested ??
          StickerAnchoringEngine.pickStickerForCategory(StickerCategory.scene);
      final stickerPx = resolved.stickerPixelSize ??
          await StickerAnchoringEngine.loadStickerPixelSize(resolved.assetPath);

      // Chỉ hiển thị khay meme cắn khi là đồ ăn, thức uống hoặc selfie con người
      final bool isBiteEligible = resolved.category == StickerCategory.food ||
          resolved.category == StickerCategory.beverage ||
          resolved.category == StickerCategory.person;

      final List<String> trayPool = isBiteEligible && biteAssets.isNotEmpty
          ? biteAssets
          : (resolved.category == StickerCategory.animal
              ? StickerAnchoringEngine.catMemes
              : (resolved.category == StickerCategory.scene
                  ? StickerAnchoringEngine.capybaraMemes
                  : StickerAnchoringEngine.allMemes));

      final trayItems = <CustomStickerItem>[
        for (final assetPath in trayPool)
          CustomStickerItem(
            id: 'tray_asset_${assetPath.split('/').last}',
            path: assetPath,
            title: assetPath.split('/').last,
            isAsset: true,
          ),
      ];

      if (mounted) {
        final photoBox = _boxSizeFor(MediaQuery.of(context).size.width);
        final placement = stickerPx == null
            ? null
            : StickerPlacementSolver.solve(
                mode: resolved.anchorMode,
                anchor: resolved.anchor,
                bitePoint: resolved.bitePoint,
                biteDirection: resolved.biteDirection,
                widthFactor: resolved.widthFactor,
                biteDepthFraction: StickerPlacementSolver.defaultBiteDepthFraction,
                stickerPixelSize: stickerPx,
                photoBoxSize: photoBox,
              );
        setState(() {
          _biteTrayItems = trayItems;
          _detectedCategory = resolved.category;
          _anchor = resolved.anchor;
          _detectedMode = resolved.anchorMode;
          _activeBitePoint = resolved.bitePoint;
          _activeStickerPixelSize = stickerPx ?? Size.zero;
          _debugTargetInFrame = placement?.targetInFrame;
          activeCustomSticker = CustomStickerItem(
            id: resolved.id,
            path: resolved.assetPath,
            title: resolved.id,
            isAsset: true,
          );
          stickerPosition = placement?.position ?? const Offset(0.08, 0.35);
          stickerScale = placement?.scale ?? 1.0;
          stickerRotation = placement?.rotation ?? 0.04;
          stickerFlipX = placement?.flipX ?? false;
        });
      }
    } catch (e) {
      debugPrint('AI Contextual Engine Error: $e');
    } finally {
      if (mounted) {
        setState(() => isProcessingAi = false);
      }
    }
  }

  /// Đổi sang meme / sticker khác và tự động neo lại bằng solver theo `ObjectAnchor` đã phát hiện.
  Future<void> _applyStickerWithSolver(CustomStickerItem item) async {
    final Size? stickerPx = item.isAsset
        ? await StickerAnchoringEngine.loadStickerPixelSize(item.path)
        : await StickerAnchoringEngine.loadFileStickerPixelSize(item.path);
    if (!mounted) return;

    final AnchorMode mode;
    final Offset bitePoint;
    final Offset biteDir;
    final double widthFactor;

    if (_anchor == null || _detectedMode == AnchorMode.scene) {
      mode = AnchorMode.scene;
      bitePoint = const Offset(0.5, 1.0);
      biteDir = BiteMeta.defaultDir;
      widthFactor = 0.30;
    } else if (!item.isAsset) {
      // Sticker tự tạo từ thư viện máy: neo tự động với bitePoint mặc định (0.5, 0.9) và dir (0, 1).
      mode = AnchorMode.topEdge;
      bitePoint = const Offset(0.5, 0.9);
      biteDir = const Offset(0.0, 1.0);
      widthFactor = BiteMeta.defaultWidth;
    } else {
      final meta = await StickerAnchoringEngine.getBiteMetaForAsset(item.path);
      if (!mounted) return;
      if (_detectedMode == AnchorMode.hug ||
          !StickerAnchoringEngine.isBiteAssetPath(item.path)) {
        mode = _detectedMode == AnchorMode.hug ? AnchorMode.hug : AnchorMode.topEdge;
        bitePoint = const Offset(0.5, 0.5);
        biteDir = meta.dir;
        widthFactor = StickerPlacementSolver.hugWidthFactor;
      } else {
        mode = AnchorMode.topEdge;
        bitePoint = meta.bite;
        biteDir = meta.dir;
        widthFactor = meta.width;
      }
    }

    final photoBox = _boxSizeFor(MediaQuery.of(context).size.width);
    final resolvedPx = stickerPx ?? const Size(512, 512);
    final placement = StickerPlacementSolver.solve(
      mode: mode,
      anchor: _anchor,
      bitePoint: bitePoint,
      biteDirection: biteDir,
      widthFactor: widthFactor,
      biteDepthFraction: StickerPlacementSolver.defaultBiteDepthFraction,
      stickerPixelSize: resolvedPx,
      photoBoxSize: photoBox,
    );

    setState(() {
      activeCustomSticker = item;
      _activeBitePoint = bitePoint;
      _activeStickerPixelSize = resolvedPx;
      _debugTargetInFrame = placement.targetInFrame;
      stickerPosition = placement.position;
      stickerScale = placement.scale;
      stickerRotation = placement.rotation;
      stickerFlipX = placement.flipX;
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  /// Mở màn hình tạo Sticker tự chọn (Original | Outline | Full)
  void _openCustomStickerFromGallery() async {
    final newSticker = await StickerGeneratorSheet.show(context);
    if (newSticker != null && mounted) {
      await _applyStickerWithSolver(newSticker);
    }
  }

  /// Khắc Custom Sticker và Caption trực tiếp vào Bitmap trước khi gửi Widget
  Future<String> _burnStickerAndCaptionToImage({
    required String imagePath,
    required String caption,
    required double previewBoxSize,
    CustomStickerItem? sticker,
  }) async {
    try {
      final baseBytes = await File(imagePath).readAsBytes();
      final baseCodec = await ui.instantiateImageCodec(baseBytes);
      final baseFrame = await baseCodec.getNextFrame();
      final ui.Image baseImg = baseFrame.image;

      final double imgW = baseImg.width.toDouble();
      final double imgH = baseImg.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // 1. Ve anh goc (da co sticker AI theo ngu canh)
      canvas.drawImage(baseImg, ui.Offset.zero, ui.Paint());

      // 2. Ve them custom sticker (neu nguoi dung chon)
      if (sticker != null) {
        Uint8List stickerBytes;
        if (sticker.isAsset) {
          final data = await rootBundle.load(sticker.path);
          stickerBytes = data.buffer.asUint8List();
        } else {
          stickerBytes = await File(sticker.path).readAsBytes();
        }

        final stickerCodec = await ui.instantiateImageCodec(stickerBytes);
        final stickerFrame = await stickerCodec.getNextFrame();
        final ui.Image stickerImg = stickerFrame.image;

        // Cùng hình học với preview (StickerGeometry): ô vuông + padding + BoxFit.contain,
        // còn ảnh gốc được cắt vuông giữa giống BoxFit.cover. `k` quy đổi px khung preview -> px ảnh,
        // nhờ vậy sticker neo vào vật thể trong preview sẽ nằm đúng chỗ trên ảnh gửi đi.
        final geo = StickerGeometry(photoBoxSize: previewBoxSize, scale: stickerScale);
        final cover = CoverMapping(
          imageSize: ui.Size(imgW, imgH),
          frameSide: StickerGeometry.frameSide(previewBoxSize),
        );
        final double k = 1 / cover.scale;
        final Offset boxTopLeft = geo.topLeftFor(stickerPosition);
        final double boxSide = geo.size * k;
        final double posX = cover.cropOrigin.dx + boxTopLeft.dx * k;
        final double posY = cover.cropOrigin.dy + boxTopLeft.dy * k;
        final double targetStickerW = boxSide;
        final double targetStickerH = boxSide;

        canvas.save();
        canvas.translate(posX + boxSide / 2, posY + boxSide / 2);
        canvas.rotate(stickerRotation);
        canvas.translate(-boxSide / 2, -boxSide / 2);

        final localImageRect = geo.imageRectInBox(
          ui.Size(stickerImg.width.toDouble(), stickerImg.height.toDouble()),
        );
        final srcRect = Rect.fromLTWH(0, 0, stickerImg.width.toDouble(), stickerImg.height.toDouble());
        final dstRect = Rect.fromLTWH(
          localImageRect.left * k,
          localImageRect.top * k,
          localImageRect.width * k,
          localImageRect.height * k,
        );

        canvas.save();
        if (stickerFlipX) {
          canvas.translate(boxSide / 2, boxSide / 2);
          canvas.scale(-1.0, 1.0);
          canvas.translate(-boxSide / 2, -boxSide / 2);
        }
        canvas.drawImageRect(stickerImg, srcRect, dstRect, ui.Paint()..filterQuality = ui.FilterQuality.high);
        canvas.restore();

        // Khắc kèm nhãn Meme Caption nếu sticker có caption
        if (sticker.caption != null && sticker.caption!.trim().isNotEmpty) {
          final captionText = sticker.caption!.trim();
          final double captionFontSize = (targetStickerW * 0.16).clamp(18.0, 36.0);
          final textSpan = TextSpan(
            text: captionText,
            style: TextStyle(
              color: OrbitColors.textLight,
              fontSize: captionFontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: targetStickerW * 1.3);

          final padH = captionFontSize * 0.75;
          final padV = captionFontSize * 0.35;
          final pillW = textPainter.width + padH * 2;
          final pillH = textPainter.height + padV * 2;
          final pillLeft = (targetStickerW - pillW) / 2;
          final pillTop = targetStickerH + 4;

          final pillRRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(pillLeft, pillTop, pillW, pillH),
            Radius.circular(pillH / 2),
          );

          canvas.drawRRect(pillRRect.shift(const Offset(0, 3)), ui.Paint()..color = Colors.black.withValues(alpha: 0.35));
          canvas.drawRRect(pillRRect, ui.Paint()..color = OrbitColors.deepOlive.withValues(alpha: 0.95));
          canvas.drawRRect(pillRRect, ui.Paint()..color = OrbitColors.khakiGold..style = ui.PaintingStyle.stroke..strokeWidth = 2);
          textPainter.paint(canvas, Offset(pillLeft + padH, pillTop + padV));
        }

        canvas.restore();

        stickerImg.dispose();
        stickerCodec.dispose();
      }

      // 3. Ve Caption Pill
      final text = caption.trim();
      if (text.isNotEmpty) {
        final double fontSize = (imgW * 0.042).clamp(24.0, 52.0);
        final textSpan = TextSpan(
          text: text,
          style: TextStyle(
            color: OrbitColors.textLight,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 2,
          ellipsis: '...',
        );

        final double maxTextWidth = imgW * 0.80;
        textPainter.layout(maxWidth: maxTextWidth);

        final double pillPadH = fontSize * 0.85;
        final double pillPadV = fontSize * 0.45;
        final double pillWidth = textPainter.width + (pillPadH * 2);
        final double pillHeight = textPainter.height + (pillPadV * 2);

        final double pillLeft = (imgW - pillWidth) / 2;
        final double pillTop = imgH - pillHeight - (imgH * 0.08);

        final pillRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
          Radius.circular(pillHeight / 2),
        );

        // Shadow behind pill
        final shadowPaint = ui.Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
        canvas.drawRRect(pillRRect.shift(const Offset(0, 4)), shadowPaint);

        // Deep Olive Pill Background
        final pillPaint = ui.Paint()
          ..color = OrbitColors.deepOlive.withValues(alpha: 0.88)
          ..style = ui.PaintingStyle.fill;
        canvas.drawRRect(pillRRect, pillPaint);

        // Border
        final borderPaint = ui.Paint()
          ..color = OrbitColors.buttonPrimary
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRRect(pillRRect, borderPaint);

        // Paint Text
        final textOffset = Offset(
          pillLeft + (pillWidth - textPainter.width) / 2,
          pillTop + (pillHeight - textPainter.height) / 2,
        );
        textPainter.paint(canvas, textOffset);
      }

      // 4. Ve Location Badge (neu nguoi dung bat)
      if (locationBadgeText != null && locationBadgeText!.isNotEmpty) {
        final double badgeFontSize = (imgW * 0.034).clamp(20.0, 42.0);
        final locSpan = TextSpan(
          text: locationBadgeText!,
          style: TextStyle(
            color: OrbitColors.textLight,
            fontSize: badgeFontSize,
            fontWeight: FontWeight.bold,
          ),
        );
        final locPainter = TextPainter(
          text: locSpan,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: imgW * 0.85);

        final padH = badgeFontSize * 0.7;
        final padV = badgeFontSize * 0.4;
        final bW = locPainter.width + padH * 2;
        final bH = locPainter.height + padV * 2;
        final bX = locationBadgePosition.dx * (imgW - bW);
        final bY = locationBadgePosition.dy * (imgH - bH);

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(bX, bY, bW, bH),
          Radius.circular(bH / 2),
        );
        canvas.drawRRect(rrect.shift(const Offset(0, 3)), ui.Paint()..color = Colors.black.withValues(alpha: 0.3));
        canvas.drawRRect(rrect, ui.Paint()..color = OrbitColors.deepOlive.withValues(alpha: 0.92));
        canvas.drawRRect(rrect, ui.Paint()..color = OrbitColors.terracotta..style = ui.PaintingStyle.stroke..strokeWidth = 2);
        locPainter.paint(canvas, Offset(bX + padH, bY + padV));
      }

      // 5. Ve Time Badge (neu nguoi dung bat)
      if (timeBadgeText != null && timeBadgeText!.isNotEmpty) {
        final double badgeFontSize = (imgW * 0.034).clamp(20.0, 42.0);
        final timeSpan = TextSpan(
          text: timeBadgeText!,
          style: TextStyle(
            color: OrbitColors.textLight,
            fontSize: badgeFontSize,
            fontWeight: FontWeight.bold,
          ),
        );
        final timePainter = TextPainter(
          text: timeSpan,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: imgW * 0.85);

        final padH = badgeFontSize * 0.7;
        final padV = badgeFontSize * 0.4;
        final bW = timePainter.width + padH * 2;
        final bH = timePainter.height + padV * 2;
        final bX = timeBadgePosition.dx * (imgW - bW);
        final bY = timeBadgePosition.dy * (imgH - bH);

        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(bX, bY, bW, bH),
          Radius.circular(bH / 2),
        );
        canvas.drawRRect(rrect.shift(const Offset(0, 3)), ui.Paint()..color = Colors.black.withValues(alpha: 0.3));
        canvas.drawRRect(rrect, ui.Paint()..color = OrbitColors.deepOlive.withValues(alpha: 0.92));
        canvas.drawRRect(rrect, ui.Paint()..color = OrbitColors.khakiGold..style = ui.PaintingStyle.stroke..strokeWidth = 2);
        timePainter.paint(canvas, Offset(bX + padH, bY + padV));
      }

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(baseImg.width, baseImg.height);
      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

      baseImg.dispose();
      baseCodec.dispose();

      if (byteData == null) return imagePath;

      final directory = await getTemporaryDirectory();
      final outPath = '${directory.path}/composite_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outPath).writeAsBytes(byteData.buffer.asUint8List());
      return outPath;
    } catch (e) {
      debugPrint('Error burning sticker & caption: $e');
      return imagePath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final photoBoxSize = _boxSizeFor(screenWidth);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final baseStickers = CustomStickerService.instance.stickers;
    final existingPaths = <String>{for (final s in baseStickers) s.path};
    final stickerList = <CustomStickerItem>[
      if (activeCustomSticker != null && !existingPaths.contains(activeCustomSticker!.path))
        activeCustomSticker!,
      ...baseStickers,
      for (final b in _biteTrayItems)
        if (!existingPaths.contains(b.path) && b.path != activeCustomSticker?.path) b,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: OrbitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33283618),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 14,
            bottom: keyboardHeight > 0 ? keyboardHeight + 14 : 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: OrbitColors.deepOlive,
                        size: 26,
                      ),
                      tooltip: "Hủy",
                    ),
                    const Text(
                      'XEM TRƯỚC ẢNH & MEME',
                      style: TextStyle(
                        color: OrbitColors.deepOlive,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (isDemoModeNotifier.value)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showDebugBoundingBox = !_showDebugBoundingBox;
                          });
                        },
                        icon: Icon(
                          _showDebugBoundingBox ? Icons.radar_rounded : Icons.radar_outlined,
                          color: _showDebugBoundingBox ? const Color(0xFF00E5FF) : OrbitColors.deepOlive,
                          size: 24,
                        ),
                        tooltip: "Bật/Tắt vùng nhận diện AI",
                      )
                    else
                      const SizedBox(width: 48), // Canh giữa với nút hủy bên trái
                  ],
                ),
                const SizedBox(height: 6),

                // Photo Card with AI contextual meme & interactive overlay
                Container(
                  width: photoBoxSize,
                  height: photoBoxSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: OrbitColors.buttonPrimary,
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // 1. Anh da chup (Ho tro thu phong 2 ngon tay InteractiveViewer)
                        Positioned.fill(
                          child: InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            clipBehavior: Clip.hardEdge,
                            child: Image.file(
                              File(currentImagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // 2. Loading overlay khi AI dang phan tich ngu canh
                        if (isProcessingAi)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: OrbitColors.textLight,
                                      strokeWidth: 3,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'AI đang nhận diện & gắn meme...',
                                      style: TextStyle(
                                        color: OrbitColors.textLight,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // 3. Auto-Anchored Meme Overlay (Locked: không cho kéo/zoom/xoay/xoá)
                        if (activeCustomSticker != null) () {
                          // Hình học dùng chung với bước khắc ảnh để preview và ảnh gửi đi không lệch nhau
                          final geo = StickerGeometry(photoBoxSize: photoBoxSize, scale: stickerScale);
                          final double stickerPixelSize = geo.size;
                          final Offset stickerTopLeft = geo.topLeftFor(stickerPosition);
                          final double left = stickerTopLeft.dx;
                          final double top = stickerTopLeft.dy;
                          final Offset effBite = stickerFlipX
                              ? Offset(1.0 - _activeBitePoint.dx, _activeBitePoint.dy)
                              : _activeBitePoint;
                          final Offset debugBiteLocal = geo.biteLocal(
                            effBite,
                            _activeStickerPixelSize,
                          );

                          return Positioned(
                            left: left,
                            top: top,
                            child: IgnorePointer(
                              child: Transform.rotate(
                                angle: stickerRotation,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Transform(
                                          transform: Matrix4.diagonal3Values(
                                            stickerFlipX ? -1.0 : 1.0,
                                            1.0,
                                            1.0,
                                          ),
                                          alignment: Alignment.center,
                                          child: Container(
                                            width: stickerPixelSize,
                                            height: stickerPixelSize,
                                            padding: const EdgeInsets.all(4),
                                            child: activeCustomSticker!.isAsset
                                                ? Image.asset(
                                                    activeCustomSticker!.path,
                                                    fit: BoxFit.contain,
                                                    filterQuality: FilterQuality.high,
                                                  )
                                                : Image.file(
                                                    File(activeCustomSticker!.path),
                                                    fit: BoxFit.contain,
                                                    filterQuality: FilterQuality.high,
                                                  ),
                                          ),
                                        ),
                                        if (AnchorMath.debugBiteEnabled)
                                          Positioned(
                                            left: debugBiteLocal.dx - 5,
                                            top: debugBiteLocal.dy - 5,
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 1.5),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (activeCustomSticker!.caption != null &&
                                        activeCustomSticker!.caption!.trim().isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: OrbitColors.deepOlive.withValues(alpha: 0.95),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: OrbitColors.khakiGold, width: 1.4),
                                          boxShadow: const [
                                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                          ],
                                        ),
                                        child: Text(
                                          activeCustomSticker!.caption!,
                                          style: const TextStyle(
                                            color: OrbitColors.textLight,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }(),

                        // ĐƯỜNG VIỀN THỰC TẾ & KHUNG NHẬN DIỆN AI (Chỉ hiển thị trong bản Showcase / Demo Mode)
                        if (_showDebugBoundingBox && _anchor != null) ...[
                          if (_anchor!.contourPoints != null && _anchor!.contourPoints!.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: NeonContourPainter(
                                    points: _anchor!.contourPoints!,
                                    mapping: CoverMapping(
                                      imageSize: _anchor!.imageSize,
                                      frameSide: photoBoxSize,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else () {
                            final mapping = CoverMapping(
                              imageSize: _anchor!.imageSize,
                              frameSide: photoBoxSize,
                            );
                            final rect = mapping.rectToFrame(_anchor!.bounds);

                            return Positioned(
                              left: rect.left,
                              top: rect.top,
                              width: rect.width.clamp(0.0, photoBoxSize),
                              height: rect.height.clamp(0.0, photoBoxSize),
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFF00E5FF),
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }(),

                          // AI Badge hiển thị thông tin
                          () {
                            final mapping = CoverMapping(
                              imageSize: _anchor!.imageSize,
                              frameSide: photoBoxSize,
                            );
                            final rect = mapping.rectToFrame(_anchor!.bounds);
                            final hasContour = _anchor!.contourPoints != null && _anchor!.contourPoints!.isNotEmpty;

                            return Positioned(
                              left: rect.left.clamp(8.0, photoBoxSize - 180.0),
                              top: (rect.top - 14).clamp(8.0, photoBoxSize - 30.0),
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 4),
                                    ],
                                  ),
                                  child: Text(
                                    hasContour
                                        ? 'AI: ĐƯỜNG VIỀN [${_detectedCategory.name.toUpperCase()}] (${_anchor!.bounds.width.toInt()}x${_anchor!.bounds.height.toInt()})'
                                        : 'AI: ${_detectedMode == AnchorMode.scene ? "BỐI CẢNH" : "VẬT THỂ"} (${_anchor!.bounds.width.toInt()}x${_anchor!.bounds.height.toInt()})',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }(),
                        ],

                        // Chấm xanh debug tại điểm neo trên mép vật thể
                        if ((AnchorMath.debugBiteEnabled || _showDebugBoundingBox) && _debugTargetInFrame != null)
                          Positioned(
                            left: _debugTargetInFrame!.dx - 6,
                            top: _debugTargetInFrame!.dy - 6,
                            child: IgnorePointer(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black87, width: 2),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0xFF00E5FF), blurRadius: 6),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Draggable Location Badge (Gán tên địa danh / đường)
                        if (locationBadgeText != null) () {
                          final double maxLeft = photoBoxSize - 160;
                          final double maxTop = photoBoxSize - 45 - 65;
                          final left = (locationBadgePosition.dx * (maxLeft > 0 ? maxLeft : 1)).clamp(0.0, maxLeft > 0 ? maxLeft : 0.0);
                          final top = (locationBadgePosition.dy * (maxTop > 0 ? maxTop : 1)).clamp(0.0, maxTop > 0 ? maxTop : 0.0);

                          return Positioned(
                            left: left,
                            top: top,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  final newX = (left + details.delta.dx) / (maxLeft > 0 ? maxLeft : 1);
                                  final newY = (top + details.delta.dy) / (maxTop > 0 ? maxTop : 1);
                                  locationBadgePosition = Offset(newX.clamp(0.0, 1.0), newY.clamp(0.0, 1.0));
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: OrbitColors.deepOlive.withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: OrbitColors.terracotta, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      locationBadgeText!,
                                      style: const TextStyle(
                                        color: OrbitColors.textLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => setState(() => locationBadgeText = null),
                                      child: const Icon(Icons.close, color: OrbitColors.textLight, size: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }(),

                        // Draggable Time Badge (Gán giờ và phút)
                        if (timeBadgeText != null) () {
                          final double maxLeft = photoBoxSize - 100;
                          final double maxTop = photoBoxSize - 45 - 65;
                          final left = (timeBadgePosition.dx * (maxLeft > 0 ? maxLeft : 1)).clamp(0.0, maxLeft > 0 ? maxLeft : 0.0);
                          final top = (timeBadgePosition.dy * (maxTop > 0 ? maxTop : 1)).clamp(0.0, maxTop > 0 ? maxTop : 0.0);

                          return Positioned(
                            left: left,
                            top: top,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  final newX = (left + details.delta.dx) / (maxLeft > 0 ? maxLeft : 1);
                                  final newY = (top + details.delta.dy) / (maxTop > 0 ? maxTop : 1);
                                  timeBadgePosition = Offset(newX.clamp(0.0, 1.0), newY.clamp(0.0, 1.0));
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: OrbitColors.deepOlive.withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: OrbitColors.khakiGold, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      timeBadgeText!,
                                      style: const TextStyle(
                                        color: OrbitColors.textLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => setState(() => timeBadgeText = null),
                                      child: const Icon(Icons.close, color: OrbitColors.textLight, size: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }(),

                        // 4. Caption Input Pill at bottom of photo
                        Positioned(
                          bottom: 14,
                          left: 14,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: OrbitColors.deepOlive.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: OrbitColors.buttonPrimary,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_note_rounded,
                                  color: OrbitColors.khakiGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _captionController,
                                    maxLength: 50,
                                    style: const TextStyle(
                                      color: OrbitColors.textLight,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Viết ghi chú cùng ảnh...",
                                      hintStyle: TextStyle(
                                        color: OrbitColors.textLight.withValues(alpha: 0.65),
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      counterText: "",
                                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    ),
                                  ),
                                ),
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _captionController,
                                  builder: (context, val, _) {
                                    if (val.text.isEmpty) return const SizedBox.shrink();
                                    return GestureDetector(
                                      onTap: () => _captionController.clear(),
                                      child: const Icon(
                                        Icons.cancel,
                                        color: OrbitColors.textLight,
                                        size: 16,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                const SizedBox(height: 12),

                // Quick Location & Time Badges Bar
                Row(
                  children: [
                    // Nút Địa Điểm
                    GestureDetector(
                      onTap: isDetectingLocation ? null : _toggleLocationBadge,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: locationBadgeText != null
                              ? OrbitColors.terracotta
                              : OrbitColors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: locationBadgeText != null
                                ? OrbitColors.terracotta
                                : OrbitColors.buttonPrimary.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDetectingLocation)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: OrbitColors.buttonPrimary,
                                ),
                              )
                            else
                              Icon(
                                Icons.location_on_rounded,
                                size: 15,
                                color: locationBadgeText != null
                                    ? OrbitColors.textLight
                                    : OrbitColors.buttonPrimary,
                              ),
                            const SizedBox(width: 5),
                            Text(
                              locationBadgeText != null
                                  ? (locationBadgeText!.length > 18
                                      ? '${locationBadgeText!.substring(0, 16)}...'
                                      : locationBadgeText!)
                                  : 'Gán địa điểm',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: locationBadgeText != null
                                    ? OrbitColors.textLight
                                    : OrbitColors.deepOlive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút Thời Gian (Giờ & Phút)
                    GestureDetector(
                      onTap: _toggleTimeBadge,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: timeBadgeText != null
                              ? OrbitColors.buttonPrimary
                              : OrbitColors.surfaceCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: timeBadgeText != null
                                ? OrbitColors.buttonPrimary
                                : OrbitColors.buttonPrimary.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_filled_rounded,
                              size: 15,
                              color: timeBadgeText != null
                                  ? OrbitColors.textLight
                                  : OrbitColors.buttonPrimary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              timeBadgeText ?? 'Gán giờ & phút',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: timeBadgeText != null
                                    ? OrbitColors.textLight
                                    : OrbitColors.deepOlive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sticker Selection Tray (Khay sticker & nut tao custom meme tu thu vien may)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Meme & Sticker dán kèm:',
                          style: TextStyle(
                            color: OrbitColors.deepOlive,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: _openCustomStickerFromGallery,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: OrbitColors.buttonPrimary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded, size: 15, color: OrbitColors.buttonPrimary),
                                SizedBox(width: 4),
                                Text(
                                  '+ Tự tạo từ thư viện máy',
                                  style: TextStyle(
                                    color: OrbitColors.buttonPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontal List of Stickers (Nút thêm từ Thư viện + 115 meme gốc phân loại)
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stickerList.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          // Nút đầu tiên: Cho phép chọn ảnh từ Thư viện của máy để tạo sticker dán thêm
                          if (index == 0) {
                            return GestureDetector(
                              onTap: _openCustomStickerFromGallery,
                              child: Container(
                                width: 56,
                                height: 56,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: OrbitColors.surfaceCream,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: OrbitColors.buttonPrimary,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate_rounded,
                                      color: OrbitColors.buttonPrimary,
                                      size: 20,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '+ Thư viện',
                                      style: TextStyle(
                                        color: OrbitColors.deepOlive,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final item = stickerList[index - 1];
                          final isSelected = activeCustomSticker != null &&
                              (activeCustomSticker!.id == item.id ||
                                  activeCustomSticker!.path == item.path);

                          return GestureDetector(
                            onTap: () {
                              if (isSelected) return;
                              _applyStickerWithSolver(item);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: OrbitColors.surfaceCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? OrbitColors.buttonPrimary : OrbitColors.borderSubtle,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: item.isAsset
                                  ? Image.asset(
                                      item.path,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    )
                                  : Image.file(
                                      File(item.path),
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Big Send Button in Olive #606C38
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrbitColors.buttonPrimary,
                      foregroundColor: OrbitColors.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 4,
                      shadowColor: OrbitColors.deepOlive.withValues(alpha: 0.4),
                    ),
                    onPressed: isSending || isProcessingAi
                        ? null
                        : () async {
                            setState(() => isSending = true);
                            try {
                              final finalImagePath = await _burnStickerAndCaptionToImage(
                                imagePath: currentImagePath,
                                caption: _captionController.text,
                                previewBoxSize: photoBoxSize,
                                sticker: activeCustomSticker,
                              );

                              final directory = await getApplicationDocumentsDirectory();
                              final fileName = 'widget_image_${DateTime.now().millisecondsSinceEpoch}.png';
                              final savedImage = await File(finalImagePath).copy('${directory.path}/$fileName');

                              images.add(savedImage.path);
                              final myName = AuthService.instance.currentUser?.displayName ?? 'Tôi';
                              await SyncService.savePhotoMetadata(savedImage.path, myName);

                              await HomeWidget.saveWidgetData<String>('widget_image_path', savedImage.path);
                              await HomeWidget.saveWidgetData<String>('widget_sender_name', myName);
                              await SyncService.updateAllHomeWidgets();

                              // Gửi ảnh đồng bộ lên đám mây 0 VNĐ cho toàn bộ bạn bè
                              final bool sentCloud = await SyncService.instance.broadcastPhotoToFriends(
                                localImagePath: savedImage.path,
                                caption: _captionController.text,
                              );

                              widget.onSend();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          sentCloud ? Icons.cloud_done_rounded : Icons.check_circle_rounded,
                                          color: const Color(0xFFFFD54F),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            sentCloud
                                                ? 'Đã gửi ảnh lên Widget của bạn bè thành công! 🚀'
                                                : 'Đã lưu ảnh và ghim lên Widget trên máy! 📸',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: OrbitColors.deepOlive,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              debugPrint('Error saving to widget: $e');
                            } finally {
                              if (mounted) setState(() => isSending = false);
                            }
                          },
                    icon: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: OrbitColors.textLight,
                            ),
                          )
                        : const Icon(Icons.rocket_launch_rounded, size: 20),
                    label: Text(
                      isSending ? "ĐANG GỬI..." : "GỬI LÊN WIDGET BẠN BÈ",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter vẽ đường viền phát sáng Neon Cyan bám sát hình khối thực tế của vật thể
/// (Dành riêng cho bản Demo Showcase để kiểm tra vị trí AI bóc tách đối tượng)
class NeonContourPainter extends CustomPainter {
  final List<Offset> points;
  final CoverMapping mapping;

  const NeonContourPainter({required this.points, required this.mapping});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final glowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
      ..style = PaintingStyle.fill;

    final corePaint = Paint()
      ..color = const Color(0xFFF0FFFF)
      ..style = PaintingStyle.fill;

    // Vẽ các điểm pixel biên với hiệu ứng hạt viền phát sáng
    for (int i = 0; i < points.length; i += 2) {
      final p = mapping.toFrame(points[i]);
      if (p.dx >= -4 && p.dx <= size.width + 4 && p.dy >= -4 && p.dy <= size.height + 4) {
        canvas.drawCircle(p, 3.2, glowPaint);
        canvas.drawCircle(p, 1.5, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NeonContourPainter oldDelegate) =>
      oldDelegate.points != points;
}
