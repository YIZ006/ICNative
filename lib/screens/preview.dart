import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';

import 'package:icnative/screens/sticker_generator_sheet.dart';
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

  // Custom Sticker them vao (neu nguoi dung muon gan them hoac tu tao)
  CustomStickerItem? activeCustomSticker;
  Offset stickerPosition = const Offset(0.60, 0.15); // Ti le 0.0 -> 1.0 tren khung anh
  double stickerScale = 1.0;
  double stickerRotation = 0.05;

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
    final result = await LocationService.instance.getCurrentLocationWithSmartName();
    if (mounted) {
      setState(() {
        isDetectingLocation = false;
        if (result != null) {
          locationBadgeText = '📍 ${result.displayName}';
        } else {
          locationBadgeText = '📍 Vị trí hiện tại';
        }
      });
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
    CustomStickerService.instance.initialize();
  }

  /// 1. Tự động chạy mô hình On-Device AI nhận diện bối cảnh và gắn sticker meme phù hợp (0 VNĐ, Offline)
  Future<void> _runAiContextualEngine() async {
    try {
      final mergedPath = await StickerAnchoringEngine.processAndMerge(widget.imagePath);
      if (mergedPath != null && mounted) {
        setState(() {
          currentImagePath = mergedPath;
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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _openStickerGenerator() async {
    final newSticker = await StickerGeneratorSheet.show(context);
    if (newSticker != null && mounted) {
      setState(() {
        activeCustomSticker = newSticker;
        stickerPosition = const Offset(0.50, 0.20);
        stickerScale = 1.0;
      });
    }
  }

  /// Khắc Custom Sticker và Caption trực tiếp vào Bitmap trước khi gửi Widget
  Future<String> _burnStickerAndCaptionToImage({
    required String imagePath,
    required String caption,
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

        final double targetStickerW = (imgW * 0.28) * stickerScale;
        final double targetStickerH = (targetStickerW / stickerImg.width) * stickerImg.height;

        final double posX = stickerPosition.dx * (imgW - targetStickerW);
        final double posY = stickerPosition.dy * (imgH - targetStickerH);

        canvas.save();
        canvas.translate(posX + targetStickerW / 2, posY + targetStickerH / 2);
        canvas.rotate(stickerRotation);
        canvas.translate(-targetStickerW / 2, -targetStickerH / 2);

        final srcRect = Rect.fromLTWH(0, 0, stickerImg.width.toDouble(), stickerImg.height.toDouble());
        final dstRect = Rect.fromLTWH(0, 0, targetStickerW, targetStickerH);
        canvas.drawImageRect(stickerImg, srcRect, dstRect, ui.Paint()..filterQuality = ui.FilterQuality.high);
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
    final photoBoxSize = (screenWidth - 36).clamp(240.0, 380.0);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final stickerList = CustomStickerService.instance.stickers;

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
                      'XEM TRƯỚC & GẮN STICKER',
                      style: TextStyle(
                        color: OrbitColors.deepOlive,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    IconButton(
                      onPressed: _openStickerGenerator,
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: OrbitColors.buttonPrimary,
                        size: 24,
                      ),
                      tooltip: "Tự tạo Sticker",
                    ),
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
                        // 1. Anh da chup (da duoc AI tu dong gan meme theo ngu canh)
                        Positioned.fill(
                          child: Image.file(
                            File(currentImagePath),
                            fit: BoxFit.cover,
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

                        // 3. Interactive Custom Sticker Overlay (neu nguoi dung muon them)
                        if (activeCustomSticker != null)
                          LayoutBuilder(
                            builder: (ctx, constraints) {
                              final double stickerPixelSize = 90.0 * stickerScale;
                              final double maxLeft = constraints.maxWidth - stickerPixelSize;
                              final double maxTop = constraints.maxHeight - stickerPixelSize;

                              final left = (stickerPosition.dx * maxLeft).clamp(0.0, maxLeft);
                              final top = (stickerPosition.dy * maxTop).clamp(0.0, maxTop);

                              return Positioned(
                                left: left,
                                top: top,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      final newX = (left + details.delta.dx) / (maxLeft > 0 ? maxLeft : 1);
                                      final newY = (top + details.delta.dy) / (maxTop > 0 ? maxTop : 1);
                                      stickerPosition = Offset(
                                        newX.clamp(0.0, 1.0),
                                        newY.clamp(0.0, 1.0),
                                      );
                                    });
                                  },
                                  child: Transform.rotate(
                                    angle: stickerRotation,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: stickerPixelSize,
                                          height: stickerPixelSize,
                                          padding: const EdgeInsets.all(4),
                                          child: activeCustomSticker!.isAsset
                                              ? Image.asset(
                                                  activeCustomSticker!.path,
                                                  fit: BoxFit.contain,
                                                )
                                              : Image.file(
                                                  File(activeCustomSticker!.path),
                                                  fit: BoxFit.contain,
                                                ),
                                        ),
                                        Positioned(
                                          top: -6,
                                          right: -6,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() => activeCustomSticker = null);
                                            },
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                color: OrbitColors.deepOlive,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: OrbitColors.textLight,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Draggable Location Badge (Gán tên địa danh / đường)
                        if (locationBadgeText != null)
                          LayoutBuilder(
                            builder: (ctx, constraints) {
                              final double maxLeft = constraints.maxWidth - 160;
                              final double maxTop = constraints.maxHeight - 45;
                              final left = (locationBadgePosition.dx * maxLeft).clamp(0.0, maxLeft);
                              final top = (locationBadgePosition.dy * maxTop).clamp(0.0, maxTop);

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
                            },
                          ),

                        // Draggable Time Badge (Gán giờ và phút)
                        if (timeBadgeText != null)
                          LayoutBuilder(
                            builder: (ctx, constraints) {
                              final double maxLeft = constraints.maxWidth - 100;
                              final double maxTop = constraints.maxHeight - 45;
                              final left = (timeBadgePosition.dx * maxLeft).clamp(0.0, maxLeft);
                              final top = (timeBadgePosition.dy * maxTop).clamp(0.0, maxTop);

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
                            },
                          ),

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

                // Sticker Selection Tray (Khay sticker & nut tao custom meme)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Thêm Sticker / Meme khác:',
                          style: TextStyle(
                            color: OrbitColors.deepOlive,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: _openStickerGenerator,
                          child: const Text(
                            '+ Tự tạo custom sticker',
                            style: TextStyle(
                              color: OrbitColors.buttonPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Horizontal List of Stickers
                    SizedBox(
                      height: 54,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stickerList.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return GestureDetector(
                              onTap: _openStickerGenerator,
                              child: Container(
                                width: 52,
                                height: 52,
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
                                      size: 18,
                                    ),
                                    Text(
                                      'Tạo mới',
                                      style: TextStyle(
                                        color: OrbitColors.buttonPrimary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final item = stickerList[index - 1];
                          final isSelected = activeCustomSticker?.id == item.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                activeCustomSticker = item;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              padding: const EdgeInsets.all(4),
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
                                  ? Image.asset(item.path, fit: BoxFit.contain)
                                  : Image.file(File(item.path), fit: BoxFit.contain),
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

                              SyncService.instance.broadcastPhotoToFriends(
                                localImagePath: savedImage.path,
                                caption: _captionController.text,
                              );

                              widget.onSend();
                              if (context.mounted) {
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
