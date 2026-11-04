import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:icnative/services/custom_sticker_service.dart';

class _DrawStroke {
  final List<Offset> points;
  final Color color;
  static const double width = 4.5;

  _DrawStroke({
    required this.points,
    required this.color,
  });
}

class StickerGeneratorSheet extends StatefulWidget {
  final String initialPath;
  final bool isAsset;
  final String? capturedPhotoPath;

  const StickerGeneratorSheet({
    super.key,
    required this.initialPath,
    this.isAsset = true,
    this.capturedPhotoPath,
  });

  /// Mở màn hình Full-Screen Sticker Studio phong cách Google Messages / TikTok.
  /// Mặc định mở ngay với bộ ảnh mẫu có sẵn trong App (Mèo La Hét AAAA, Capybara, Shiba...)
  /// kèm ảnh vừa chụp và nút chọn từ Thư viện máy, đảm bảo không bao giờ bị văng (crash).
  static Future<CustomStickerItem?> show(
    BuildContext context, {
    String? initialPath,
    bool isAsset = false,
    String? capturedPhotoPath,
  }) async {
    final defaultSample = CustomStickerService.inAppSamplePhotos.first;
    final String startPath = (initialPath != null && initialPath.isNotEmpty)
        ? initialPath
        : defaultSample.assetPath;
    final bool startIsAsset = (initialPath != null && initialPath.isNotEmpty)
        ? isAsset
        : true;

    return Navigator.of(context, rootNavigator: true).push<CustomStickerItem>(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: StickerGeneratorSheet(
              initialPath: startPath,
              isAsset: startIsAsset,
              capturedPhotoPath: capturedPhotoPath,
            ),
          );
        },
      ),
    );
  }

  @override
  State<StickerGeneratorSheet> createState() => _StickerGeneratorSheetState();
}

class _StickerGeneratorSheetState extends State<StickerGeneratorSheet> {
  late String currentSourcePath;
  late bool isAssetSource;
  StickerEditMode activeMode = StickerEditMode.outline;

  Map<StickerEditMode, String> _variations = {};
  bool isGenerating = true;
  bool isSaving = false;

  // Các công cụ chỉnh sửa góc trên bên phải (〰️ Vẽ tay, Aa Chữ, 😊 Emoji)
  final GlobalKey _canvasBoundaryKey = GlobalKey();
  bool isDrawingMode = false;
  Color activeDrawColor = Colors.white;
  final List<_DrawStroke> _strokes = [];
  _DrawStroke? _currentStroke;

  String overlayText = '';
  Color overlayTextColor = Colors.white;
  Offset overlayTextPos = const Offset(0.5, 0.14);

  String? overlayEmoji;
  Offset overlayEmojiPos = const Offset(0.82, 0.18);

  bool showEmojiBar = false;
  bool showPhotoStrip = true;

  static const List<Color> _paletteColors = [
    Colors.white,
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF00C7BE),
    Color(0xFFFF2D55),
  ];

  static const List<String> _emojiList = [
    '😂',
    '😭',
    '🔥',
    '❤️',
    '💀',
    '🥺',
    '✨',
    '💢',
    '👑',
    '🕶️',
    '🐱',
    '🧋',
  ];

  @override
  void initState() {
    super.initState();
    currentSourcePath = widget.initialPath;
    isAssetSource = widget.isAsset;
    _generateAllVariationsForCurrentSource();
  }

  Future<void> _generateAllVariationsForCurrentSource() async {
    setState(() {
      isGenerating = true;
    });

    try {
      final result = await CustomStickerService.instance.generateAllStickerVariations(
        sourcePath: currentSourcePath,
        isAsset: isAssetSource,
      );
      if (mounted) {
        setState(() {
          _variations = result;
          isGenerating = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating variations: $e');
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  void _selectSource(String path, bool isAsset) {
    if (currentSourcePath == path && isAssetSource == isAsset && _variations.isNotEmpty) {
      return;
    }
    setState(() {
      currentSourcePath = path;
      isAssetSource = isAsset;
      _strokes.clear();
    });
    _generateAllVariationsForCurrentSource();
  }

  Future<void> _pickFromDevice(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 90,
      );
      if (picked != null && mounted) {
        _selectSource(picked.path, false);
      }
    } catch (e) {
      debugPrint('ImagePicker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở thư viện ảnh: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _openTextEditorDialog() async {
    final controller = TextEditingController(text: overlayText);
    Color tempColor = overlayTextColor;
    final quickTags = [
      'AAAAAAAAAAA',
      '10 ĐIỂM',
      'HẾT CỨU',
      'ỦA GÌ DỢ?',
      'CHILL PHẾT',
      'CỰC CĂNG',
      'DỖI RỒI',
    ];

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: bottomInset + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chèn chữ lên Sticker (Aa)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx, {
                            'text': controller.text.trim(),
                            'color': tempColor,
                          });
                        },
                        child: const Text(
                          'Xong',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 28,
                    style: TextStyle(
                      color: tempColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập chữ meme (VD: AAAAAAAAAAA)...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2E),
                      counterStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => controller.clear(),
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: quickTags.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final tag = quickTags[idx];
                        return GestureDetector(
                          onTap: () {
                            controller.text = tag;
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Màu chữ:',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      for (final c in _paletteColors)
                        GestureDetector(
                          onTap: () => setModalState(() => tempColor = c),
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tempColor == c ? Colors.white : Colors.white24,
                                width: tempColor == c ? 2.5 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        overlayText = (result['text'] as String? ?? '').trim();
        overlayTextColor = result['color'] as Color? ?? Colors.white;
      });
    }
  }

  Future<void> _saveSticker() async {
    if (isGenerating || isSaving) return;
    setState(() => isSaving = true);

    try {
      String finalPath = _variations[activeMode] ?? currentSourcePath;
      final bool hasCustomOverlays = _strokes.isNotEmpty ||
          overlayText.isNotEmpty ||
          (overlayEmoji != null && overlayEmoji!.isNotEmpty);

      // Nếu người dùng có vẽ thêm nét (〰️), chèn chữ (Aa) hoặc gắn emoji (😊),
      // xuất toàn bộ khung canvas thành PNG trong suốt độ nét cao
      if (hasCustomOverlays) {
        final boundary = _canvasBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image capturedImg = await boundary.toImage(pixelRatio: 2.2);
          final byteData = await capturedImg.toByteData(format: ui.ImageByteFormat.png);
          capturedImg.dispose();
          if (byteData != null) {
            final tempDir = await getTemporaryDirectory();
            final customOut = '${tempDir.path}/sticker_custom_${DateTime.now().millisecondsSinceEpoch}.png';
            await File(customOut).writeAsBytes(byteData.buffer.asUint8List());
            finalPath = customOut;
          }
        }
      }

      final item = CustomStickerItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        path: finalPath,
        isAsset: false,
        mode: activeMode,
        title: overlayText.isNotEmpty ? overlayText : 'Custom Sticker',
        caption: null,
      );

      await CustomStickerService.instance.saveCustomSticker(item);

      if (mounted) {
        Navigator.of(context).pop(item);
      }
    } catch (e) {
      debugPrint('Error saving sticker: $e');
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeVariationPath = _variations[activeMode];
    final screenSize = MediaQuery.of(context).size;
    final double previewSide = (screenSize.width - 36).clamp(260.0, 370.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Bố cục chính từ trên xuống dưới
            Column(
              children: [
                // 1. Thanh điều hướng trên cùng (Nút Back bên trái + Chọn kho ảnh giữa)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        tooltip: 'Quay lại',
                      ),
                      const Spacer(),
                      // Nút bật/tắt nhanh thanh chọn ảnh mẫu trong app & thư viện
                      GestureDetector(
                        onTap: () => setState(() => showPhotoStrip = !showPhotoStrip),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F22),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.collections_rounded, color: Colors.white, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                showPhotoStrip ? 'Ẩn kho ảnh' : 'Đổi ảnh khác',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 52),
                    ],
                  ),
                ),

                // 2. Vùng Preview Sticker lớn ở chính giữa màn hình đen (Giống hệt ảnh Message/TikTok)
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: previewSide,
                      height: previewSide,
                      child: isGenerating
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Đang tách nền & tạo viền Sticker...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RepaintBoundary(
                              key: _canvasBoundaryKey,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: isDrawingMode
                                    ? (details) {
                                        setState(() {
                                          _currentStroke = _DrawStroke(
                                            points: [details.localPosition],
                                            color: activeDrawColor,
                                          );
                                          _strokes.add(_currentStroke!);
                                        });
                                      }
                                    : null,
                                onPanUpdate: isDrawingMode
                                    ? (details) {
                                        setState(() {
                                          _currentStroke?.points.add(details.localPosition);
                                        });
                                      }
                                    : null,
                                onPanEnd: isDrawingMode
                                    ? (_) {
                                        _currentStroke = null;
                                      }
                                    : null,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Ảnh Sticker theo chế độ đang chọn (Original / Outline / Full)
                                    if (activeVariationPath != null)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.file(
                                          File(activeVariationPath),
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.high,
                                        ),
                                      ),

                                    // Lớp vẽ tay tự do (〰️)
                                    if (_strokes.isNotEmpty)
                                      CustomPaint(
                                        painter: _StickerScribblePainter(strokes: _strokes),
                                      ),

                                    // Lớp chữ Meme kéo thả (Aa)
                                    if (overlayText.isNotEmpty)
                                      Positioned(
                                        left: (overlayTextPos.dx * (previewSide - 160)).clamp(4.0, previewSide - 80),
                                        top: (overlayTextPos.dy * (previewSide - 50)).clamp(4.0, previewSide - 45),
                                        child: GestureDetector(
                                          onPanUpdate: (d) {
                                            setState(() {
                                              final nx = overlayTextPos.dx + d.delta.dx / previewSide;
                                              final ny = overlayTextPos.dy + d.delta.dy / previewSide;
                                              overlayTextPos = Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
                                            });
                                          },
                                          onTap: _openTextEditorDialog,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.45),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              overlayText,
                                              style: TextStyle(
                                                color: overlayTextColor,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                                shadows: const [
                                                  Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Lớp Emoji kéo thả (😊)
                                    if (overlayEmoji != null && overlayEmoji!.isNotEmpty)
                                      Positioned(
                                        left: (overlayEmojiPos.dx * (previewSide - 56)).clamp(4.0, previewSide - 56),
                                        top: (overlayEmojiPos.dy * (previewSide - 56)).clamp(4.0, previewSide - 56),
                                        child: GestureDetector(
                                          onPanUpdate: (d) {
                                            setState(() {
                                              final nx = overlayEmojiPos.dx + d.delta.dx / previewSide;
                                              final ny = overlayEmojiPos.dy + d.delta.dy / previewSide;
                                              overlayEmojiPos = Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
                                            });
                                          },
                                          onLongPress: () => setState(() => overlayEmoji = null),
                                          child: Text(
                                            overlayEmoji!,
                                            style: const TextStyle(fontSize: 42),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                // 3. Thanh công cụ phụ khi bật Vẽ tay (〰️) hoặc chọn Emoji (😊)
                if (isDrawingMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final c in _paletteColors)
                          GestureDetector(
                            onTap: () => setState(() => activeDrawColor = c),
                            child: Container(
                              width: 26,
                              height: 26,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: activeDrawColor == c ? Colors.white : Colors.white24,
                                  width: activeDrawColor == c ? 2.5 : 1,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (_strokes.isNotEmpty)
                          IconButton(
                            onPressed: () => setState(() => _strokes.removeLast()),
                            icon: const Icon(Icons.undo_rounded, color: Colors.white, size: 22),
                            tooltip: 'Hoàn tác nét vẽ',
                          ),
                      ],
                    ),
                  ),

                if (showEmojiBar)
                  Container(
                    height: 44,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _emojiList.length + (overlayEmoji != null ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, idx) {
                        if (overlayEmoji != null && idx == 0) {
                          return GestureDetector(
                            onTap: () => setState(() {
                              overlayEmoji = null;
                              showEmojiBar = false;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.close, color: Colors.white70, size: 18),
                            ),
                          );
                        }
                        final emoji = _emojiList[overlayEmoji != null ? idx - 1 : idx];
                        return GestureDetector(
                          onTap: () => setState(() {
                            overlayEmoji = emoji;
                            showEmojiBar = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: overlayEmoji == emoji
                                  ? Colors.white24
                                  : const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ),
                        );
                      },
                    ),
                  ),

                // 4. Kho ảnh tích hợp sẵn trong App + Nút chọn từ Thư viện / Máy ảnh
                if (showPhotoStrip)
                  Container(
                    height: 62,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Nút chọn ảnh từ Thư viện máy
                        _buildSourceActionTile(
                          icon: Icons.photo_library_rounded,
                          label: 'Thư viện',
                          onTap: () => _pickFromDevice(ImageSource.gallery),
                        ),
                        const SizedBox(width: 8),
                        // Nút chụp ảnh mới
                        _buildSourceActionTile(
                          icon: Icons.camera_alt_rounded,
                          label: 'Máy ảnh',
                          onTap: () => _pickFromDevice(ImageSource.camera),
                        ),
                        // Ảnh vừa chụp từ màn hình Preview (nếu có)
                        if (widget.capturedPhotoPath != null &&
                            widget.capturedPhotoPath!.isNotEmpty &&
                            File(widget.capturedPhotoPath!).existsSync()) ...[
                          const SizedBox(width: 8),
                          _buildSourcePhotoTile(
                            title: 'Ảnh chụp',
                            path: widget.capturedPhotoPath!,
                            isAsset: false,
                          ),
                        ],
                        // Danh sách 7 ảnh mẫu có sẵn trong App (Mèo AAAA, Mèo Cười, Shiba, Capybara...)
                        for (final sample in CustomStickerService.inAppSamplePhotos) ...[
                          const SizedBox(width: 8),
                          _buildSourcePhotoTile(
                            title: sample.title,
                            path: sample.assetPath,
                            isAsset: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                // 5. Ba ô Thumbnail chế độ: Original | Outline | Full (Giống hệt 100% ảnh Message/TikTok)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildVariationThumbnail(
                        mode: StickerEditMode.original,
                        label: 'Original',
                      ),
                      const SizedBox(width: 14),
                      _buildVariationThumbnail(
                        mode: StickerEditMode.outline,
                        label: 'Outline',
                      ),
                      const SizedBox(width: 14),
                      _buildVariationThumbnail(
                        mode: StickerEditMode.full,
                        label: 'Full',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 6. Nút Save màu trắng bo tròn ở góc dưới bên phải (Giống hệt ảnh Message/TikTok)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: (isGenerating || isSaving) ? null : _saveSticker,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 4,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Cột 3 nút công cụ nổi ở góc trên bên phải (〰️ Vẽ tay, Aa Chữ, 😊 Emoji) giống hệt ảnh Message/TikTok
            Positioned(
              top: 12,
              right: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Nút Vẽ nét tự do (〰️ Scribble)
                  _buildRightToolButton(
                    isActive: isDrawingMode,
                    onTap: () {
                      setState(() {
                        isDrawingMode = !isDrawingMode;
                        if (isDrawingMode) showEmojiBar = false;
                      });
                    },
                    child: const Icon(
                      Icons.gesture_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Nút Chữ (Aa)
                  _buildRightToolButton(
                    isActive: overlayText.isNotEmpty,
                    onTap: () {
                      setState(() {
                        isDrawingMode = false;
                        showEmojiBar = false;
                      });
                      _openTextEditorDialog();
                    },
                    child: const Text(
                      'Aa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Nút Biểu cảm (😊 Emoji)
                  _buildRightToolButton(
                    isActive: showEmojiBar || overlayEmoji != null,
                    onTap: () {
                      setState(() {
                        isDrawingMode = false;
                        showEmojiBar = !showEmojiBar;
                      });
                    },
                    child: const Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightToolButton({
    required bool isActive,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white24 : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: child,
      ),
    );
  }

  Widget _buildVariationThumbnail({
    required StickerEditMode mode,
    required String label,
  }) {
    final bool isSelected = activeMode == mode;
    final String? thumbPath = _variations[mode];

    return GestureDetector(
      onTap: () {
        if (activeMode != mode) {
          setState(() => activeMode = mode);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 76,
            height: 76,
            padding: EdgeInsets.all(mode == StickerEditMode.full ? 2 : 6),
            decoration: BoxDecoration(
              color: const Color(0xFF262628),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white12,
                width: isSelected ? 2.5 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumbPath != null
                  ? Image.file(
                      File(thumbPath),
                      fit: mode == StickerEditMode.full ? BoxFit.cover : BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    )
                  : const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white38,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E8E93),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePhotoTile({
    required String title,
    required String path,
    required bool isAsset,
  }) {
    final bool isSelected = currentSourcePath == path && isAssetSource == isAsset;
    return GestureDetector(
      onTap: () => _selectSource(path, isAsset),
      child: Container(
        width: 62,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white12,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              isAsset
                  ? Image.asset(path, fit: BoxFit.cover)
                  : Image.file(File(path), fit: BoxFit.cover),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 3),
                  color: Colors.black.withValues(alpha: 0.6),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerScribblePainter extends CustomPainter {
  final List<_DrawStroke> strokes;

  _StickerScribblePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = _DrawStroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, _DrawStroke.width / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StickerScribblePainter oldDelegate) => true;
}
