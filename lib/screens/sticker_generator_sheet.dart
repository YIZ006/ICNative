import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:icnative/services/custom_sticker_service.dart';

class StickerGeneratorSheet extends StatefulWidget {
  final String imagePath;

  const StickerGeneratorSheet({
    super.key,
    required this.imagePath,
  });

  /// Mở màn hình tạo Sticker với 3 chế độ: Original, Outline, Full
  /// Chỉ tập trung đúng 3 chế độ trên ảnh người dùng đã chọn từ máy/thư viện.
  static Future<CustomStickerItem?> show(
    BuildContext context, {
    String? initialPath,
  }) async {
    String? selectedPath = initialPath;

    // Nếu chưa có ảnh truyền vào, mở hộp thoại chọn từ Thư viện hoặc Máy ảnh
    if (selectedPath == null || selectedPath.isEmpty) {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF1E1E20),
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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'CHỌN ẢNH ĐỂ TẠO STICKER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
                  title: const Text('Chọn từ Thư viện ảnh', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const Divider(color: Colors.white12, height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                  title: const Text('Chụp ảnh mới', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
        ),
      );

      if (source == null) return null;

      try {
        final picked = await picker.pickImage(
          source: source,
          maxWidth: 960,
          maxHeight: 960,
          imageQuality: 90,
        );
        if (picked == null) return null;
        selectedPath = picked.path;
      } catch (e) {
        debugPrint('ImagePicker error: $e');
        return null;
      }
    }

    if (!context.mounted) return null;

    return Navigator.of(context, rootNavigator: true).push<CustomStickerItem>(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: true,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: StickerGeneratorSheet(
              imagePath: selectedPath!,
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
  StickerEditMode activeMode = StickerEditMode.outline;
  Map<StickerEditMode, String> _variations = {};
  bool isGenerating = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _processImage();
  }

  Future<void> _processImage() async {
    setState(() => isGenerating = true);
    try {
      final result = await CustomStickerService.instance.generateAllStickerVariations(
        sourcePath: widget.imagePath,
        isAsset: false,
      );
      if (mounted) {
        setState(() {
          _variations = result;
          isGenerating = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating sticker variations: $e');
      if (mounted) {
        setState(() => isGenerating = false);
      }
    }
  }

  Future<void> _saveAndReturn() async {
    if (isGenerating || isSaving) return;
    setState(() => isSaving = true);

    try {
      final finalPath = _variations[activeMode] ?? widget.imagePath;
      final item = CustomStickerItem(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        path: finalPath,
        isAsset: false,
        mode: activeMode,
        title: 'Custom Sticker',
        caption: null,
      );

      await CustomStickerService.instance.saveCustomSticker(item);

      if (mounted) {
        Navigator.of(context).pop(item);
      }
    } catch (e) {
      debugPrint('Error saving custom sticker: $e');
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeVariationPath = _variations[activeMode];
    final screenWidth = MediaQuery.of(context).size.width;
    final double previewSide = (screenWidth - 48).clamp(260.0, 380.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Nút quay lại (Top-left back button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'Quay lại',
                ),
              ),
            ),

            // 2. Vùng hiển thị Sticker trung tâm (Center Sticker Preview)
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
                                'Đang xử lý tách nền & tạo viền...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : (activeVariationPath != null
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Image.file(
                                File(activeVariationPath),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            )
                          : const SizedBox.shrink()),
                ),
              ),
            ),

            // 3. Đúng 3 ô Thumbnail chế độ: Original | Outline | Full
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildVariationThumbnail(
                    mode: StickerEditMode.original,
                    label: 'Original',
                  ),
                  const SizedBox(width: 16),
                  _buildVariationThumbnail(
                    mode: StickerEditMode.outline,
                    label: 'Outline',
                  ),
                  const SizedBox(width: 16),
                  _buildVariationThumbnail(
                    mode: StickerEditMode.full,
                    label: 'Full',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Nút Save màu trắng bo tròn ở góc dưới bên phải
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 24, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: (isGenerating || isSaving) ? null : _saveAndReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white38,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
            duration: const Duration(milliseconds: 150),
            width: 78,
            height: 78,
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
          const SizedBox(height: 8),
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
}
