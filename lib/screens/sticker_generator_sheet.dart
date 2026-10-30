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

  static Future<CustomStickerItem?> show(
    BuildContext context, {
    String? initialPath,
    bool isAsset = false,
  }) async {
    String path = initialPath ?? '';
    bool assetMode = isAsset;

    // Neu chua co anh, cho nguoi dung chon tu thu vien hoac anh mau
    if (path.isEmpty) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
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

  final TextEditingController _titleController = TextEditingController(text: 'Sticker Meme');

  @override
  void initState() {
    super.initState();
    currentSourcePath = widget.initialPath;
    isAssetSource = widget.isAsset;
    _generateCurrentMode();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
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

  void _saveAndUse() async {
    final path = _cachedVariations[activeMode] ?? currentSourcePath;
    final item = CustomStickerItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      path: path,
      isAsset: false,
      mode: activeMode,
      title: _titleController.text.trim().isEmpty ? 'Sticker' : _titleController.text.trim(),
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
        child: Padding(
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

              // Tieu de
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
                        'Tạo Sticker Tùy Chỉnh',
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
                    icon: const Icon(Icons.photo_library_outlined, size: 16, color: OrbitColors.buttonPrimary),
                    label: const Text(
                      'Đổi ảnh',
                      style: TextStyle(
                        color: OrbitColors.buttonPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Khung Preview Sticker
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCard,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Luoi caro mien phi mieu ta nen trong suot
                    CustomPaint(
                      painter: _CheckerboardPainter(),
                    ),

                    // Anh Sticker Preview
                    if (isGenerating)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: OrbitColors.buttonPrimary,
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Đang tách & vẽ viền AI...',
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
                          child: Image.file(
                            File(currentImagePath),
                            fit: BoxFit.contain,
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
              const SizedBox(height: 16),

              // 3 Che do Generator (Original, Outline, Full)
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
                      mode: StickerEditMode.original,
                      icon: Icons.image_outlined,
                      label: 'Gốc (Original)',
                    ),
                    _buildModeTab(
                      mode: StickerEditMode.outline,
                      icon: Icons.crop_free_rounded,
                      label: 'Viền Trắng (Outline)',
                    ),
                    _buildModeTab(
                      mode: StickerEditMode.full,
                      icon: Icons.lens_blur_rounded,
                      label: 'Tách Nền (Full)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mo ta che do dang chon
              Text(
                activeMode == StickerEditMode.outline
                    ? '✨ Viền trắng dày bao quanh như sticker cắt dán chuẩn Messenger/iMessage.'
                    : activeMode == StickerEditMode.full
                        ? '✂️ Bóc tách nền 100% On-Device, chỉ giữ lại chủ thể trong suốt.'
                        : '📷 Giữ nguyên tỷ lệ ảnh meme gốc bo viền mềm mại.',
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Nut Xac nhan su dung
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

/// Ve nen caro de nhan biet vung anh trong suot
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
