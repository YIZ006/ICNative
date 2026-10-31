import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:icnative/services/custom_sticker_service.dart';
import 'package:icnative/settings/theme_colors.dart';

class StickerGeneratorSheet extends StatefulWidget {
  final String initialPath;
  final bool isAsset;

  const StickerGeneratorSheet({
    super.key,
    required this.initialPath,
    this.isAsset = false,
  });

  /// Mở Sticker Generator Sheet.
  /// Nếu [initialPath] có sẵn (ví dụ ảnh người dùng vừa chụp), dùng luôn không cần chọn lại!
  /// Nếu [initialPath] trống, hiển thị popup cho chọn "Chụp ảnh mới" hoặc "Chọn từ Thư viện".
  static Future<CustomStickerItem?> show(
    BuildContext context, {
    String? initialPath,
    bool isAsset = false,
  }) async {
    String path = initialPath ?? '';
    bool assetMode = isAsset;

    // Nếu chưa có ảnh, cho người dùng chọn: Chụp ảnh mới hoặc Chọn từ thư viện
    if (path.isEmpty) {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: OrbitColors.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'CHỌN ẢNH TỪ MÁY ĐỂ TẠO STICKER DÁN THÊM',
                  style: TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: OrbitColors.buttonPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: OrbitColors.buttonPrimary),
                  ),
                  title: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.bold, color: OrbitColors.deepOlive)),
                  subtitle: const Text('Chụp biểu cảm, thú cưng, đồ ăn để làm meme', style: TextStyle(fontSize: 11, color: OrbitColors.textMuted)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: OrbitColors.buttonPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: OrbitColors.buttonPrimary),
                  ),
                  title: const Text('Chọn từ Thư viện ảnh', style: TextStyle(fontWeight: FontWeight.bold, color: OrbitColors.deepOlive)),
                  subtitle: const Text('Lấy ảnh meme có sẵn trong máy', style: TextStyle(fontSize: 11, color: OrbitColors.textMuted)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
      if (source == null) return null;

      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 92,
      );
      if (picked == null) return null;
      path = picked.path;
      assetMode = false;
    }

    if (!context.mounted) return null;

    return showModalBottomSheet<CustomStickerItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StickerGeneratorSheet(
        initialPath: path,
        isAsset: assetMode,
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

  final Map<StickerEditMode, String> _cachedVariations = {};
  bool isGenerating = true;
  String? errorMessage;

  final TextEditingController _captionController = TextEditingController();
  final List<String> _quickMemeTags = [
    '10 ĐIỂM',
    'ALOOO?',
    'CHILL',
    'ỦA GÌ DỢ?',
    'CỰC CĂNG',
    'DỖI RỒI',
    'BÓ TAY',
    'HẾT CỨU',
    'QUẨY LÊN',
  ];

  @override
  void initState() {
    super.initState();
    currentSourcePath = widget.initialPath;
    isAssetSource = widget.isAsset;
    _generateCurrentMode();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _generateCurrentMode() async {
    if (_cachedVariations.containsKey(activeMode)) {
      setState(() => isGenerating = false);
      return;
    }

    setState(() {
      isGenerating = true;
      errorMessage = null;
    });

    try {
      final resultPath = await CustomStickerService.instance.generateStickerVariation(
        sourcePath: currentSourcePath,
        isAsset: isAssetSource,
        mode: activeMode,
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      );
      _cachedVariations[activeMode] = resultPath;
    } catch (e) {
      errorMessage = 'Không thể tạo sticker: $e';
    } finally {
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  void _onModeChanged(StickerEditMode newMode) {
    if (activeMode == newMode) return;
    setState(() => activeMode = newMode);
    _generateCurrentMode();
  }

  Future<void> _pickAnotherImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: OrbitColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: OrbitColors.buttonPrimary),
              title: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: OrbitColors.buttonPrimary),
              title: const Text('Chọn từ Thư viện', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 92,
      );
      if (picked != null) {
        setState(() {
          currentSourcePath = picked.path;
          isAssetSource = false;
          _cachedVariations.clear();
        });
        _generateCurrentMode();
      }
    }
  }

  void _saveAndUse() async {
    final path = _cachedVariations[activeMode] ?? currentSourcePath;
    final captionText = _captionController.text.trim();
    final item = CustomStickerItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      path: path,
      isAsset: false,
      mode: activeMode,
      title: captionText.isNotEmpty ? captionText : 'Sticker Meme',
      caption: captionText.isNotEmpty ? captionText : null,
    );

    await CustomStickerService.instance.saveCustomSticker(item);

    if (mounted) {
      Navigator.pop(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final currentImagePath = _cachedVariations[activeMode];

    return Container(
      decoration: const BoxDecoration(
        color: OrbitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33283618),
            blurRadius: 25,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: keyboardHeight > 0 ? keyboardHeight + 14 : 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tiêu đề & Nút đổi ảnh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: OrbitColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: OrbitColors.textLight,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Gene Sticker Meme',
                        style: TextStyle(
                          color: OrbitColors.deepOlive,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _pickAnotherImage,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: OrbitColors.buttonPrimary),
                    label: const Text(
                      'Đổi ảnh khác',
                      style: TextStyle(
                        color: OrbitColors.buttonPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Khung Preview Sticker độ nét cao (220x220)
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: OrbitColors.buttonPrimary.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Nền caro nhận biết vùng trong suốt
                    CustomPaint(
                      painter: _CheckerboardPainter(),
                    ),

                    // Ảnh Sticker Preview
                    if (isGenerating)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: OrbitColors.buttonPrimary,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Đang bóc tách & dựng nét AI...',
                              style: TextStyle(
                                color: OrbitColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (currentImagePath != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Image.file(
                                  File(currentImagePath),
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              // Live Meme Caption Badge Preview
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _captionController,
                                builder: (ctx, val, _) {
                                  if (val.text.trim().isEmpty) return const SizedBox.shrink();
                                  return Container(
                                    margin: const EdgeInsets.only(top: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: OrbitColors.deepOlive.withValues(alpha: 0.95),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: OrbitColors.khakiGold, width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: Text(
                                      val.text.trim(),
                                      style: const TextStyle(
                                        color: OrbitColors.textLight,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4 Chế độ Sticker Generator (Outline, Full, Badge, Original)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCream,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: OrbitColors.buttonPrimary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    _buildModeTab(
                      mode: StickerEditMode.outline,
                      icon: Icons.crop_free_rounded,
                      label: 'Viền Trắng',
                    ),
                    _buildModeTab(
                      mode: StickerEditMode.full,
                      icon: Icons.lens_blur_rounded,
                      label: 'Tách Nền',
                    ),
                    _buildModeTab(
                      mode: StickerEditMode.badge,
                      icon: Icons.stars_rounded,
                      label: 'Huy Hiệu',
                    ),
                    _buildModeTab(
                      mode: StickerEditMode.original,
                      icon: Icons.image_outlined,
                      label: 'Ảnh Gốc',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Mô tả ngắn chế độ đang chọn
              Text(
                activeMode == StickerEditMode.outline
                    ? '✨ Viền trắng dày bao quanh như sticker cắt dán chuẩn Messenger/iMessage.'
                    : activeMode == StickerEditMode.full
                        ? '✂️ Bóc tách nền 100% On-Device, chỉ giữ lại chủ thể sắc nét.'
                        : activeMode == StickerEditMode.badge
                            ? '🏅 Khung huy hiệu tròn phong cách Warm Earth cổ điển.'
                            : '📷 Giữ nguyên ảnh gốc đã tối ưu độ phân giải cao.',
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Meme Caption & Quick Presets Tags
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gán nhãn Meme hài hước:',
                    style: TextStyle(
                      color: OrbitColors.deepOlive,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Quick Meme Tags Chips
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickMemeTags.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final tag = _quickMemeTags[index];
                        final isSelected = _captionController.text == tag;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _captionController.clear();
                              } else {
                                _captionController.text = tag;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? OrbitColors.buttonPrimary : OrbitColors.surfaceCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? OrbitColors.buttonPrimary : OrbitColors.borderSubtle,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? OrbitColors.textLight : OrbitColors.deepOlive,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Custom Caption Input Field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: OrbitColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.subtitles_rounded, size: 18, color: OrbitColors.buttonPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _captionController,
                            maxLength: 25,
                            style: const TextStyle(
                              color: OrbitColors.deepOlive,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Hoặc tự gõ chữ meme (VD: 10 ĐIỂM, CHILL PHẾT)...',
                              hintStyle: TextStyle(
                                color: OrbitColors.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_captionController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _captionController.clear()),
                            child: const Icon(Icons.cancel, size: 16, color: OrbitColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nút Xác nhận sử dụng Sticker này
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isGenerating ? null : _saveAndUse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrbitColors.buttonPrimary,
                    foregroundColor: OrbitColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'DÙNG STICKER NÀY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required StickerEditMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onModeChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? OrbitColors.buttonPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? OrbitColors.textLight : OrbitColors.deepOlive,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? OrbitColors.textLight : OrbitColors.deepOlive,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vẽ nền caro để nhận biết vùng ảnh trong suốt
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const squareSize = 10.0;
    final paint1 = Paint()..color = const Color(0xFFF7F5EC);
    final paint2 = Paint()..color = const Color(0xFFEBE6D0);

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final isEven = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, squareSize, squareSize),
          isEven ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
