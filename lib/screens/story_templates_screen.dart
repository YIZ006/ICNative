import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/story_share_service.dart';

/// Các lựa chọn khi bấm "Lưu Story".
enum _StoryExportAction { instagramStory, saveVideo, saveImage, shareOther }

class StoryTemplateItem {
  final int id;
  final String name;
  final String theme;
  final String headline;
  final String subHeadline;
  final String centerIcon;
  final Color primaryColor;
  final Color accentColor;
  final Gradient backgroundGradient;
  final bool isDark;

  const StoryTemplateItem({
    required this.id,
    required this.name,
    required this.theme,
    required this.headline,
    required this.subHeadline,
    required this.centerIcon,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundGradient,
    this.isDark = true,
  });
}

class StoryTemplatesScreen extends StatefulWidget {
  const StoryTemplatesScreen({super.key});

  static List<StoryTemplateItem> get templates => _StoryTemplatesScreenState.templates;
  static String cleanDisplayName(String? raw) => _StoryTemplatesScreenState.cleanDisplayName(raw);

  @override
  State<StoryTemplatesScreen> createState() => _StoryTemplatesScreenState();
}

class _StoryTemplatesScreenState extends State<StoryTemplatesScreen> with TickerProviderStateMixin {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  int _selectedTemplateIndex = 0;
  bool _isExporting = false;
  double _exportProgress = 0;
  String _exportLabel = '';

  late final AnimationController _colorFlowController;
  late final AnimationController _spinController;
  late final AnimationController _pulseController;

  final Map<String, String> _customPhotos = {};

  @override
  void initState() {
    super.initState();
    _colorFlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _colorFlowController.dispose();
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  static const List<StoryTemplateItem> templates = [
    // --- PACK 1 ---
    StoryTemplateItem(
      id: 1,
      name: 'Cosmic Neon',
      theme: 'Vũ trụ phát sáng & Quỹ đạo',
      headline: 'ORBIT WITH ME ✨',
      subHeadline: 'Chụp ảnh là nhảy thẳng lên màn hình chính của nhau!',
      centerIcon: '🪐',
      primaryColor: Color(0xFF00F0FF),
      accentColor: Color(0xFFD000FF),
      backgroundGradient: RadialGradient(
        center: Alignment(0, -0.6),
        radius: 1.2,
        colors: [Color(0xFF1E0B36), Color(0xFF08020F), Color(0xFF030005)],
      ),
    ),
    StoryTemplateItem(
      id: 2,
      name: 'Y2K Chrome',
      theme: 'Kim loại lấp lánh & Y2K Star',
      headline: 'PING MY SCREEN ✦',
      subHeadline: 'Ai muốn xuất hiện trên widget của tui thì bấm vô đây 🛸',
      centerIcon: '🛸',
      primaryColor: Color(0xFF1F1A3A),
      accentColor: Color(0xFF7A70A0),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFD8D0F8), Color(0xFFB8C8F0), Color(0xFFE0D4F5)],
      ),
      isDark: false,
    ),
    StoryTemplateItem(
      id: 3,
      name: 'Retro Polaroid',
      theme: 'Khung ảnh Polaroid 90s & Băng dính',
      headline: 'MEMORIES ON SCREEN',
      subHeadline: 'Gửi ảnh kỷ niệm vào màn hình chính của tui nè ☕',
      centerIcon: '🎞️',
      primaryColor: Color(0xFF3A2E20),
      accentColor: Color(0xFFFF5500),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFFEDE6D6), Color(0xFFE5DDD0)],
      ),
      isDark: false,
    ),
    StoryTemplateItem(
      id: 4,
      name: 'Minimal Pastel',
      theme: 'Café Hàn Quốc tối giản',
      headline: 'A PIECE OF MY DAY ☕',
      subHeadline: 'Mỗi ngày một tấm ảnh xinh trên màn hình',
      centerIcon: '🪴',
      primaryColor: Color(0xFF3C342C),
      accentColor: Color(0xFF9C8E80),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFAF6F0), Color(0xFFF4EAE0)],
      ),
      isDark: false,
    ),
    StoryTemplateItem(
      id: 5,
      name: 'Dark Acid Grunge',
      theme: 'Đen nhám, Barcode & Neon Green',
      headline: 'ORBIT REVOLUTION ⚡',
      subHeadline: 'Gửi khoảnh khắc thực, không filter, không khoảng cách',
      centerIcon: '⚡',
      primaryColor: Color(0xFF00FF66),
      accentColor: Colors.white,
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF080808), Color(0xFF141414)],
      ),
    ),
    StoryTemplateItem(
      id: 6,
      name: 'Golden Hour',
      theme: 'Hoàng hôn rực rỡ & Ánh cam ấm',
      headline: 'GOLDEN HOUR WITH ME 🌅',
      subHeadline: 'Gửi hoàng hôn chỗ bạn vào widget của tui nhé',
      centerIcon: '🌅',
      primaryColor: Colors.white,
      accentColor: Color(0xFFFFE0D0),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7E5F), Color(0xFFFEB47B), Color(0xFFFF6E7F)],
      ),
    ),
    StoryTemplateItem(
      id: 7,
      name: '80s Synthwave',
      theme: 'Mặt trời neon & Lưới Cyber',
      headline: 'ORBIT 1984 · SYNTHWAVE 🕹️',
      subHeadline: 'Giao diện retro hoài niệm cho widget đôi',
      centerIcon: '🕹️',
      primaryColor: Color(0xFF00F6FF),
      accentColor: Color(0xFFFF007F),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF140026), Color(0xFF2C004D)],
      ),
    ),
    StoryTemplateItem(
      id: 8,
      name: 'Aura Gradient',
      theme: 'Năng lượng Aura & Liquid Glass',
      headline: 'MATCHING ORBITS 🔮',
      subHeadline: 'Cùng tần số năng lượng, gửi ảnh cho nhau mỗi ngày',
      centerIcon: '✨',
      primaryColor: Color(0xFFFFFFFE),
      accentColor: Color(0xFFA277FF),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F0E17), Color(0xFF1F1235)],
      ),
    ),
    StoryTemplateItem(
      id: 9,
      name: 'Soulmate Infinity',
      theme: 'Quỹ đạo Cận tâm & Trái tim vô cực',
      headline: 'ONLY FOR MY #1 💕',
      subHeadline: 'Quỹ đạo Cận tâm dành riêng cho hai đứa mình',
      centerIcon: '💖',
      primaryColor: Color(0xFFFF3366),
      accentColor: Color(0xFFFF99BB),
      backgroundGradient: RadialGradient(
        center: Alignment(0, -0.4),
        radius: 1.1,
        colors: [Color(0xFF3D081F), Color(0xFF15020A), Color(0xFF080004)],
      ),
    ),
    StoryTemplateItem(
      id: 10,
      name: 'Titanium Pro',
      theme: 'Kính mờ cao cấp & Viền Titanium',
      headline: 'ORBIT PRO WIDGET 💎',
      subHeadline: 'Màn hình khóa kết nối tức thời, mượt mà tinh tế',
      centerIcon: '🪐',
      primaryColor: Color(0xFFF2F2F7),
      accentColor: Color(0xFF34C759),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF000000), Color(0xFF1C1C1E)],
      ),
    ),

    // --- PACK 2 ---
    StoryTemplateItem(
      id: 11,
      name: 'Korean 4-Cut',
      theme: 'Life4Cuts dải ảnh Hàn Quốc',
      headline: 'PHOTOISM x ORBIT 📸',
      subHeadline: 'Dải ảnh photobooth Hàn Quốc ngay trên màn hình',
      centerIcon: '🎀',
      primaryColor: Color(0xFF1B4F72),
      accentColor: Color(0xFF5499C7),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFFD4E6F1), Color(0xFFEAF2F8)],
      ),
      isDark: false,
    ),
    StoryTemplateItem(
      id: 12,
      name: 'Y2K Cyber Angel',
      theme: 'Cánh thiên thần & Ánh tím Lilac',
      headline: 'CYBER ANGEL 🪽',
      subHeadline: 'Gửi tín hiệu thiên thần vào màn hình tui nè',
      centerIcon: '🪽',
      primaryColor: Color(0xFFBCA0FF),
      accentColor: Color(0xFF8EC5FC),
      backgroundGradient: RadialGradient(
        center: Alignment(0, -0.4),
        radius: 1.2,
        colors: [Color(0xFF2A1B4E), Color(0xFF110926), Color(0xFF080314)],
      ),
    ),
    StoryTemplateItem(
      id: 13,
      name: 'Vintage Scrapbook',
      theme: 'Giấy kraft, washi tape & ghim',
      headline: 'LƯU KỶ NIỆM CHÚNG MÌNH 🌿',
      subHeadline: 'Chỉ cần 1 nút bấm là ảnh nhảy sang máy cậu 💌',
      centerIcon: '📎',
      primaryColor: Color(0xFF4E342E),
      accentColor: Color(0xFF8D6E63),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFFF5EFE6), Color(0xFFE8DEC8)],
      ),
      isDark: false,
    ),
    StoryTemplateItem(
      id: 14,
      name: 'Twilight Magic Hour',
      theme: 'Chạng vạng tím hồng & Trăng khuyết',
      headline: 'GỬI TUI BẦU TRỜI CHỖ CẬU 🌌',
      subHeadline: 'Mỗi buổi chiều ngắm hoàng hôn cùng nhau qua widget',
      centerIcon: '🌙',
      primaryColor: Color(0xFFFFD285),
      accentColor: Color(0xFFF5B7B1),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B0A2A), Color(0xFF3A1548), Color(0xFFA35D87)],
      ),
    ),
    StoryTemplateItem(
      id: 15,
      name: 'iOS Lock Screen',
      theme: 'Màn hình khóa iPhone & Thông báo',
      headline: 'LOCKSCREEN DROP 📱',
      subHeadline: 'Vừa bắn 1 tấm ảnh mới lên màn hình của bạn!',
      centerIcon: '🔔',
      primaryColor: Color(0xFF007AFF),
      accentColor: Color(0xFF34C759),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF050508), Color(0xFF16161C)],
      ),
    ),
    StoryTemplateItem(
      id: 16,
      name: 'Kodak 35mm Film',
      theme: 'Cuộn phim âm bản cổ điển & Sprocket',
      headline: 'KODAK ORBIT 400 🎞️',
      subHeadline: 'Khoảnh khắc chụp film lưu giữ trên màn hình chính',
      centerIcon: '🎞️',
      primaryColor: Color(0xFFFF9900),
      accentColor: Color(0xFFFFD285),
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
      ),
    ),
    StoryTemplateItem(
      id: 17,
      name: 'Coquette Ribbon',
      theme: 'Nơ lụa hồng pastel & Ren tiểu thư',
      headline: 'DÀNH CHO BESTIE XINH NHẤT 🎀',
      subHeadline: 'Gửi ảnh đáng yêu mỗi ngày không khoảng cách',
      centerIcon: '🎀',
      primaryColor: Color(0xFFAD1457),
      accentColor: Color(0xFFE91E63),
      backgroundGradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFF48FB1)],
      ),
      isDark: false,
    ),
    StoryTemplateItem(
      id: 18,
      name: 'Spotify Music Duo',
      theme: 'Đĩa than xoay tròn & Trình phát nhạc',
      headline: 'OUR FAVORITE TRACK 🎵',
      subHeadline: 'Giai điệu và khoảnh khắc kết nối qua màn hình chính',
      centerIcon: '🎵',
      primaryColor: Color(0xFF1DB954),
      accentColor: Colors.white,
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF121212), Color(0xFF1E1E1E)],
      ),
    ),
    StoryTemplateItem(
      id: 19,
      name: 'Sunset Beach',
      theme: 'Bãi biển hoàng hôn & Sóng vỗ',
      headline: 'CATCHING WAVES WITH YOU 🌊',
      subHeadline: 'Bức ảnh hoàng hôn biển chiều gửi đến widget của bạn',
      centerIcon: '🐚',
      primaryColor: Color(0xFFFF6F61),
      accentColor: Color(0xFFFFD166),
      backgroundGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFC5C7D), Color(0xFF6A82FB)],
      ),
    ),
    StoryTemplateItem(
      id: 20,
      name: 'Red Thread Destiny',
      theme: 'Sợi chỉ đỏ định mệnh kết nối 2 người',
      headline: 'CONNECTED BY DESTINY 🧶',
      subHeadline: 'Dù cách xa bao nhiêu km, quỹ đạo vẫn chạm vào nhau',
      centerIcon: '🧶',
      primaryColor: Color(0xFFFF2A2A),
      accentColor: Color(0xFFFF7A7A),
      backgroundGradient: RadialGradient(
        center: Alignment(0, -0.3),
        radius: 1.2,
        colors: [Color(0xFF33050B), Color(0xFF120003), Color(0xFF050001)],
      ),
    ),
  ];

  static String cleanDisplayName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Bạn thân';
    return raw.replaceAll(RegExp(r'\s*#\d+.*$'), '').trim();
  }

  /// Hiệu ứng dòng chảy gradient động (Dynamic Living Colors)
  /// Giữ nguyên 100% bảng màu gốc của từng template, dao động mượt mà theo thời gian
  Gradient _getDynamicGradient(Gradient baseGradient) {
    final phase = _colorFlowController.value * 2 * math.pi;
    if (baseGradient is LinearGradient) {
      final originalBegin = (baseGradient.begin as Alignment?) ?? Alignment.topLeft;
      final originalEnd = (baseGradient.end as Alignment?) ?? Alignment.bottomRight;

      final dx = 0.35 * math.sin(phase);
      final dy = 0.35 * math.cos(phase);

      return LinearGradient(
        begin: Alignment(
          (originalBegin.x + dx).clamp(-1.2, 1.2),
          (originalBegin.y + dy).clamp(-1.2, 1.2),
        ),
        end: Alignment(
          (originalEnd.x - dx).clamp(-1.2, 1.2),
          (originalEnd.y - dy).clamp(-1.2, 1.2),
        ),
        colors: baseGradient.colors,
        stops: baseGradient.stops,
      );
    } else if (baseGradient is RadialGradient) {
      final originalCenter = (baseGradient.center as Alignment?) ?? Alignment.center;
      final cx = (originalCenter.x + 0.15 * math.sin(phase)).clamp(-1.0, 1.0);
      final cy = (originalCenter.y + 0.12 * math.cos(phase)).clamp(-1.0, 1.0);
      final r = (baseGradient.radius + 0.15 * math.sin(phase)).clamp(0.6, 2.0);

      return RadialGradient(
        center: Alignment(cx, cy),
        radius: r,
        colors: baseGradient.colors,
        stops: baseGradient.stops,
      );
    }
    return baseGradient;
  }

  /// Chọn ảnh từ thư viện cho slot tương tác
  Future<void> _pickPhotoForSlot(String slotKey) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 88,
      );
      if (picked != null) {
        setState(() {
          _customPhotos[slotKey] = picked.path;
        });
      }
    } catch (e) {
      debugPrint('StoryTemplate: Lỗi khi chọn ảnh: $e');
    }
  }

  void _clearPhotoForSlot(String slotKey) {
    setState(() {
      _customPhotos.remove(slotKey);
    });
  }

  // ==========================================
  // XUẤT STORY: VIDEO ĐỘNG (MP4) / ẢNH TĨNH (PNG)
  // ==========================================

  /// Kích thước video Story chuẩn 9:16 cho Instagram / TikTok (vòng lặp 4s liền mạch).
  static const int _videoWidth = 720;
  static const int _videoHeight = 1280;
  static const int _videoFps = 24;
  static const int _videoSeconds = 4;

  /// Sóng tam giác 0→1→0 mô phỏng `repeat(reverse: true)` của AnimationController.
  static double _triangleWave(double cycles) {
    final f = cycles % 2.0;
    return f <= 1.0 ? f : 2.0 - f;
  }

  void _restartAnimations() {
    if (!mounted) return;
    _colorFlowController.repeat(reverse: true);
    _spinController.repeat();
    _pulseController.repeat(reverse: true);
  }

  /// Dựng toàn bộ template động đang chọn (`templates[_selectedTemplateIndex]`) thành video MP4
  /// bằng cách tự điều khiển từng khung hình animation (vòng lặp khép kín mượt mà)
  /// và mã hoá bằng MediaCodec của Android.
  Future<File> _renderStoryVideo() async {
    // Chờ 1 nhịp để UI ẩn các nút "+ Thêm ảnh" / "Đổi" trước khi chụp khung hình đầu tiên
    await WidgetsBinding.instance.endOfFrame;

    final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Không tìm thấy khung Story');

    final currentTpl = templates[_selectedTemplateIndex];
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/orbit_story_tpl${currentTpl.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final pixelRatio = _videoWidth / boundary.size.width;
    const totalFrames = _videoFps * _videoSeconds;

    // Dừng animation thời gian thực để tự "tua" từng khung hình chính xác
    _colorFlowController.stop();
    _spinController.stop();
    _pulseController.stop();

    await StoryShareService.startVideo(
      path: path,
      width: _videoWidth,
      height: _videoHeight,
      fps: _videoFps,
    );
    try {
      for (int i = 0; i < totalFrames; i++) {
        if (!mounted) throw Exception('Đã huỷ xuất video');
        final progress = i / totalFrames; // 0.0 -> 1.0 trong suốt thời lượng video
        // Chu kỳ khép kín hoàn hảo để khi Instagram lặp lại video không bị giật khớp:
        // - Đĩa than xoay tròn đủ 1 vòng 360°
        // - Nhịp đập (equalizer / tim / sao) đập 2 chu kỳ đầy đủ
        // - Dòng chảy màu nền chuyển động 1 chu kỳ khép kín
        _spinController.value = progress % 1.0;
        _pulseController.value = _triangleWave(progress * 4.0);
        _colorFlowController.value = _triangleWave(progress * 2.0);

        WidgetsBinding.instance.scheduleFrame();
        await WidgetsBinding.instance.endOfFrame;

        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final w = image.width;
        final h = image.height;
        image.dispose();
        if (byteData == null) throw Exception('Không đọc được khung hình');

        await StoryShareService.addFrame(byteData.buffer.asUint8List(), w, h);
        if (mounted) setState(() => _exportProgress = (i + 1) / totalFrames);
      }
      final out = await StoryShareService.finishVideo();
      if (out == null) throw Exception('Mã hoá video thất bại');
      return File(out);
    } catch (e) {
      await StoryShareService.cancelVideo();
      rethrow;
    } finally {
      _restartAnimations();
    }
  }

  /// Chụp ảnh tĩnh PNG Full HD của toàn bộ template đang chọn.
  Future<File> _renderStoryImage() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 30));
    final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Không tìm thấy khung Story');

    final currentTpl = templates[_selectedTemplateIndex];
    final image = await boundary.toImage(pixelRatio: 1080 / boundary.size.width);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) throw Exception('Không đọc được ảnh');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/orbit_story_tpl${currentTpl.id}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  void _showSnack(String message, {bool success = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? const Color(0xFF00FF66) : const Color(0xFFFF4D4D),
        content: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error_outline, color: Colors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runExport(_StoryExportAction action) async {
    final isVideo = action != _StoryExportAction.saveImage;
    setState(() {
      _isExporting = true;
      _exportProgress = 0;
      _exportLabel = isVideo ? 'Đang dựng video' : 'Đang xuất ảnh';
    });

    try {
      final file = isVideo ? await _renderStoryVideo() : await _renderStoryImage();
      final mime = isVideo ? StoryShareService.mimeVideo : StoryShareService.mimeImage;

      switch (action) {
        case _StoryExportAction.instagramStory:
          // Lưu bản sao vào Thư viện để dùng lại sau, rồi nhảy thẳng sang Instagram Story
          await StoryShareService.saveToGallery(file.path, mime);
          final res = await StoryShareService.shareToInstagramStory(file.path, mime);
          if (res == InstagramShareResult.chooser) {
            _showSnack('Máy chưa cài Instagram – đã lưu video vào Thư viện (Movies/Orbit).');
          }
          break;
        case _StoryExportAction.saveVideo:
          final ok = await StoryShareService.saveToGallery(file.path, mime);
          ok
              ? _showSnack('Đã lưu video Story động vào Thư viện (Movies/Orbit)!')
              : _showSnack('Không lưu được vào Thư viện trên máy này.', success: false);
          break;
        case _StoryExportAction.saveImage:
          final ok = await StoryShareService.saveToGallery(file.path, mime);
          ok
              ? _showSnack('Đã lưu ảnh Story HD vào Thư viện (Pictures/Orbit)!')
              : _showSnack('Không lưu được vào Thư viện trên máy này.', success: false);
          break;
        case _StoryExportAction.shareOther:
          await StoryShareService.shareGeneric(file.path, mime);
          break;
      }
    } catch (e) {
      _showSnack('Lỗi khi xuất Story: $e', success: false);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportSheet() {
    final currentTpl = templates[_selectedTemplateIndex];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget option(IconData icon, Color color, String title, String subtitle, _StoryExportAction action) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
            onTap: () {
              Navigator.pop(ctx);
              _runExport(action);
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Text(currentTpl.centerIcon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mẫu ${_selectedTemplateIndex + 1}/20: ${currentTpl.name}',
                          style: const TextStyle(color: Color(0xFF00FF66), fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
                option(
                    Icons.camera_alt_rounded,
                    const Color(0xFFE1306C),
                    'Đăng mẫu "${currentTpl.name}" lên Instagram Story',
                    'Đính kèm nguyên template động (${_videoSeconds}s) mở thẳng vào Story',
                    _StoryExportAction.instagramStory),
                option(Icons.movie_creation_outlined, const Color(0xFF00F0FF), 'Lưu video template động vào Thư viện',
                    'MP4 9:16 – đăng TikTok, Reels, Zalo…', _StoryExportAction.saveVideo),
                option(Icons.image_outlined, const Color(0xFF00FF66), 'Lưu ảnh tĩnh vào Thư viện',
                    'PNG Full HD 1080×1920', _StoryExportAction.saveImage),
                option(Icons.share_rounded, Colors.white70, 'Chia sẻ template qua ứng dụng khác',
                    'Gửi video động qua Messenger, Zalo, TikTok…', _StoryExportAction.shareOther),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTpl = templates[_selectedTemplateIndex];
    final user = AuthService.instance.currentUser;

    // Chặn thoát màn hình khi đang dựng video để tránh hỏng file
    return PopScope(
      canPop: !_isExporting,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Mẫu Story Orbit 🪐',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
          ),
          actions: [
            TextButton.icon(
              onPressed: _isExporting ? null : _showExportSheet,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.ios_share, color: Color(0xFF00F0FF)),
              label: Text(
                _isExporting
                    ? (_exportProgress > 0 ? '$_exportLabel ${(_exportProgress * 100).round()}%' : '$_exportLabel…')
                    : 'Lưu Story',
                style: const TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 9:16 Story Preview Card bọc bởi AnimatedBuilder cho dòng chảy màu động
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: AnimatedBuilder(
                          animation: _colorFlowController,
                          builder: (context, _) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: _getDynamicGradient(currentTpl.backgroundGradient),
                              ),
                              child: _buildStoryCardContent(currentTpl, user),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Template Selector Bottom Carousel & Toolbar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'Mẫu ${_selectedTemplateIndex + 1}/20: ${currentTpl.name}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentTpl.theme,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_customPhotos.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _customPhotos.clear()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 12, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Text('Đặt lại ảnh', style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 74,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: templates.length,
                      itemBuilder: (ctx, idx) {
                        final t = templates[idx];
                        final isSelected = idx == _selectedTemplateIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedTemplateIndex = idx),
                          child: Container(
                            width: 58,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              gradient: t.backgroundGradient,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF00FF66) : Colors.white24,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: const Color(0xFF00FF66).withValues(alpha: 0.4), blurRadius: 10)]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${t.id}',
                                style: TextStyle(
                                  color: t.isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

  /// Bộ điều hướng layout sáng tạo theo từng mẫu chuyên biệt
  Widget _buildStoryCardContent(StoryTemplateItem tpl, UserProfile? user) {
    final displayNameClean = cleanDisplayName(user?.displayName);
    final userUid = user?.uid ?? 'orbit_user';

    // 1. Mẫu 3: Retro Polaroid 90s
    if (tpl.id == 3) {
      return _buildPolaroidStory(tpl, user, displayNameClean, userUid);
    }

    // 2. Mẫu 11: Korean 4-Cut Photobooth (Life4Cuts)
    if (tpl.id == 11) {
      return _buildPhotoboothStory(tpl, user, displayNameClean, userUid);
    }

    // 3. Mẫu 15: iOS Lock Screen Drop
    if (tpl.id == 15) {
      return _buildIosLockScreenStory(tpl, user, displayNameClean, userUid);
    }

    // 4. Mẫu 18: Spotify Music Duo
    if (tpl.id == 18) {
      return _buildSpotifyStory(tpl, user, displayNameClean, userUid);
    }

    // 5. Mẫu 9 & 20: Soulmate Duo & Sợi chỉ đỏ
    if (tpl.id == 9 || tpl.id == 20) {
      return _buildSoulmateStory(tpl, user, displayNameClean, userUid);
    }

    // 6. Mẫu 2 & 12: Y2K Cyber Chrome
    if (tpl.id == 2 || tpl.id == 12) {
      return _buildY2kStory(tpl, user, displayNameClean, userUid);
    }

    // 7. Mẫu 6 & 19: Golden Hour & Sunset Beach
    if (tpl.id == 6 || tpl.id == 19) {
      return _buildGoldenHourStory(tpl, user, displayNameClean, userUid);
    }

    // 8. Các mẫu khác: Bố cục tạp chí Editorial nghệ thuật
    return _buildEditorialStory(tpl, user, displayNameClean, userUid);
  }

  // ==========================================
  // 1. MẪU POLAROID 90s SÁNG TẠO (Mẫu 3)
  // ==========================================
  Widget _buildPolaroidStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Top Bar with Washi tape & Sender Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 82,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFC4A482).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                  ],
                ),
                child: const Center(
                  child: Text('✦ ORBIT ✦',
                      style:
                          TextStyle(color: Colors.white, fontSize: 9.5, letterSpacing: 2, fontWeight: FontWeight.bold)),
                ),
              ),
              _buildSenderHeaderBadge(user, name, tpl, isDark: false),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            'drop a memory on my screen ☕',
            style: TextStyle(
              color: Color(0xFF4A3E30),
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'chụp 1 tấm ảnh xinh gửi vào widget của tui nhé',
            style: TextStyle(color: Color(0xFF7A6E60), fontSize: 11.5),
          ),

          const Spacer(),

          // Khung ảnh Polaroid nghiêng
          Transform.rotate(
            angle: -0.035,
            child: Container(
              width: 220,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFBF9),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInteractivePhotoSlot(
                    slotKey: 'polaroid',
                    width: 192,
                    height: 192,
                    borderRadius: 2,
                    placeholderLabel: 'Bấm để thêm ảnh kỷ niệm',
                    placeholderEmoji: '☕',
                    isDark: false,
                    fallbackWidget: _buildAvatarImage(user, name, 192, 192, borderRadius: 2),
                  ),
                  const SizedBox(height: 10),
                  // Dòng chữ ký & Sender avatar mini & ngày tháng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildAvatarImage(user, name, 20, 20, borderRadius: 10),
                          const SizedBox(width: 6),
                          Text(
                            '$name :)',
                            style: const TextStyle(
                              color: Color(0xFF2C2218),
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              fontFamily: 'serif',
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        "'26 11 05",
                        style: TextStyle(
                          color: Color(0xFFFF5500),
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Instagram Link Sticker & Stamp quét mã
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInstagramLinkSticker('orbit.app/connect', label: 'Thêm vào màn hình tui ↗'),
              const SizedBox(width: 8),
              _buildMiniQrBadge(uid, isDark: false),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. MẪU DẢI ẢNH HÀN QUỐC (Mẫu 11 - Life4Cuts)
  // ==========================================
  Widget _buildPhotoboothStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Column(
        children: [
          // Header Sender Badge
          Align(
            alignment: Alignment.centerRight,
            child: _buildSenderHeaderBadge(user, name, tpl, isDark: false),
          ),
          const SizedBox(height: 8),

          // Dải ảnh Life4Cuts trắng tinh tế
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header Photobooth
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PHOTOISM',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2, color: Colors.black)),
                    Text('ORBIT STUDIO',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 9, color: Colors.black.withValues(alpha: 0.6))),
                  ],
                ),
                const SizedBox(height: 8),

                // Ô ảnh 1: Avatar thật người gửi
                Stack(
                  children: [
                    Container(
                      width: 196,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: _buildAvatarImage(user, name, 196, 110, borderRadius: 3),
                    ),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '@$name',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Ô ảnh 2: Slot tương tác cho bạn thân
                _buildInteractivePhotoSlot(
                  slotKey: 'photobooth_slot2',
                  width: 196,
                  height: 110,
                  borderRadius: 3,
                  placeholderLabel: 'Chừa slot cho bạn thân',
                  placeholderEmoji: '🎀',
                  isDark: false,
                  borderColor: const Color(0xFF5499C7).withValues(alpha: 0.4),
                  backgroundColor: const Color(0xFFF7FAFC),
                ),
                const SizedBox(height: 8),

                // Barcode kiểu photobooth Hàn Quốc
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('||||| |||| || ||||| |',
                        style:
                            TextStyle(fontSize: 15, letterSpacing: 1.5, fontFamily: 'monospace', color: Colors.black)),
                    Text('SEOUL · ${DateTime.now().year}',
                        style: const TextStyle(fontSize: 8.5, color: Colors.black45)),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          _buildInstagramLinkSticker('orbit.app/photobooth', label: 'Chụp ảnh đôi cùng tui nè 📸'),
          const SizedBox(height: 8),
          _buildMiniQrBadge(uid, isDark: false, text: 'Quét kết bạn ngay'),
        ],
      ),
    );
  }

  // ==========================================
  // 3. MẪU MÀN HÌNH KHÓA IPHONE (Mẫu 15)
  // ==========================================
  Widget _buildIosLockScreenStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Ổ khóa iPhone & Header sender badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 16),
              _buildSenderHeaderBadge(user, name, tpl, isDark: true),
            ],
          ),
          const SizedBox(height: 2),

          // Đồng hồ màn hình khóa lớn phong cách iOS với dấu hai chấm nhấp nháy mượt
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final colonOpacity = 0.4 + 0.6 * _pulseController.value;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '11',
                    style: TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w200, letterSpacing: -2),
                  ),
                  Opacity(
                    opacity: colonOpacity,
                    child: const Text(
                      ':',
                      style: TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w200),
                    ),
                  ),
                  const Text(
                    '11',
                    style: TextStyle(color: Colors.white, fontSize: 54, fontWeight: FontWeight.w200, letterSpacing: -2),
                  ),
                ],
              );
            },
          ),
          const Text(
            'Thứ Hai, 5 tháng 11',
            style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w400),
          ),

          const SizedBox(height: 18),

          // Apple Frosted Glass Notification Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        _buildAvatarImage(user, name, 46, 46, borderRadius: 23),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF34C759),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 15,
                                    height: 15,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFFD000FF)]),
                                    ),
                                    child: const Center(child: Text('🪐', style: TextStyle(fontSize: 8))),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text('ORBIT',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Text('Vừa xong', style: TextStyle(color: Colors.white38, fontSize: 9.5)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Vừa gửi 1 khoảnh khắc mới lên màn hình chính 📸',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Interactive Photo Slot: iOS Photo Widget Preview
          _buildInteractivePhotoSlot(
            slotKey: 'ios_lockscreen',
            width: 210,
            height: 125,
            borderRadius: 18,
            placeholderLabel: 'Chạm để gắn ảnh widget vào màn hình khóa',
            placeholderEmoji: '🖼️',
            borderColor: Colors.white.withValues(alpha: 0.25),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            fallbackWidget: _isExporting
                ? _buildAvatarImage(user, name, 210, 125, borderRadius: 18)
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: Colors.white70, size: 28),
                        const SizedBox(height: 4),
                        const Text('Thêm ảnh Widget',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        Text('Bấm để chọn từ thư viện',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 9.5)),
                      ],
                    ),
                  ),
          ),

          const Spacer(),

          // Dải gạch Home Bar iPhone
          Container(
            width: 110,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          _buildInstagramLinkSticker('orbit.app/lockscreen', label: 'Bấm để nhận ảnh trên Widget ↗'),
        ],
      ),
    );
  }

  // ==========================================
  // 4. MẪU TRÌNH PHÁT NHẠC SPOTIFY (Mẫu 18)
  // ==========================================
  Widget _buildSpotifyStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        children: [
          // Header Spotify Story + Sender Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1DB954),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Icon(Icons.music_note, color: Colors.black, size: 12)),
                  ),
                  const SizedBox(width: 7),
                  const Text('PLAYING ON ORBIT',
                      style: TextStyle(
                          color: Color(0xFF1DB954), fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ],
              ),
              _buildSenderHeaderBadge(user, name, tpl, isDark: true),
            ],
          ),

          const Spacer(),

          // Đĩa than xoay tròn + Bìa album tương tác
          SizedBox(
            width: 240,
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Đĩa than xoay tròn phía sau
                Positioned(
                  right: 0,
                  top: 10,
                  child: RotationTransition(
                    turns: _spinController,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0A0A0A),
                        border: Border.all(color: Colors.white12, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 15),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1DB954), width: 2),
                          ),
                          child: _buildAvatarImage(user, name, 48, 48, borderRadius: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                // Bìa Album thật - Cho phép chạm để thêm/đổi ảnh
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: _buildInteractivePhotoSlot(
                      slotKey: 'spotify',
                      width: 160,
                      height: 160,
                      borderRadius: 10,
                      placeholderLabel: 'Chạm để gắn ảnh Album đôi',
                      placeholderEmoji: '🎵',
                      isDark: true,
                      fallbackWidget: _buildAvatarImage(user, name, 160, 160, borderRadius: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tên bài hát & Tên người bạn & Animated Equalizer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Our Orbit Track 🪐',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Curated by $name',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _buildEqualizer(),
            ],
          ),

          const SizedBox(height: 12),

          // Thanh thời gian Spotify
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: const LinearProgressIndicator(
                  value: 0.38,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1:11', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text('3:45', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Nút điều khiển phát nhạc
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.shuffle, color: Colors.white38, size: 20),
              Icon(Icons.skip_previous, color: Colors.white, size: 28),
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF1DB954),
                child: Icon(Icons.play_arrow, color: Colors.black, size: 30),
              ),
              Icon(Icons.skip_next, color: Colors.white, size: 28),
              Icon(Icons.favorite, color: Color(0xFF1DB954), size: 20),
            ],
          ),

          const Spacer(),

          _buildInstagramLinkSticker('spotify.link/orbit', label: 'Bấm nghe chung trên Widget ↗'),
        ],
      ),
    );
  }

  // ==========================================
  // 5. MẪU CẶP ĐÔI / BẠN THÂN (Mẫu 9 & 20)
  // ==========================================
  Widget _buildSoulmateStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          // Header Cận tâm + Sender Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tpl.primaryColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tpl.centerIcon, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      'DUO ORBIT · #1',
                      style: TextStyle(
                          color: tpl.primaryColor, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
              _buildSenderHeaderBadge(user, name, tpl, isDark: true),
            ],
          ),

          const SizedBox(height: 12),

          const Text(
            'waiting for my other half 🤍',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                fontFamily: 'serif'),
          ),
          const SizedBox(height: 3),
          Text(
            'Quỹ đạo Cận tâm độc quyền dành riêng cho 2 đứa mình',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11.5),
          ),

          const Spacer(),

          // Sân khấu Sao Đôi: Node người gửi & Node tương tác cho bạn thân
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Node 1: SENDER'S AVATAR
              Column(
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: tpl.primaryColor.withValues(alpha: 0.5), blurRadius: 20),
                      ],
                    ),
                    child: _buildAvatarImage(user, name, 85, 85, borderRadius: 45),
                  ),
                  const SizedBox(height: 8),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ),

              const SizedBox(width: 12),

              // Biểu tượng Vô cực nhịp đập
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final scale = 0.92 + 0.16 * _pulseController.value;
                  return Transform.scale(
                    scale: scale,
                    child: Column(
                      children: [
                        Text('∞', style: TextStyle(color: tpl.primaryColor, fontSize: 32, fontWeight: FontWeight.w200)),
                        Text('~0 km', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5)),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 12),

              // Node 2: Interactive Photo Slot cho Bạn Thân
              Column(
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: tpl.accentColor.withValues(alpha: 0.35), blurRadius: 18),
                      ],
                    ),
                    child: _buildInteractivePhotoSlot(
                      slotKey: 'soulmate_friend',
                      width: 85,
                      height: 85,
                      borderRadius: 45,
                      placeholderLabel: 'Gắn ảnh',
                      placeholderEmoji: '🤍',
                      isDark: true,
                      borderColor: tpl.primaryColor.withValues(alpha: 0.7),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Bạn số #1',
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12.5)),
                ],
              ),
            ],
          ),

          const Spacer(),

          _buildInstagramLinkSticker('orbit.app/soulmate', label: 'Nhận vị trí trên Widget của tui ↗'),
        ],
      ),
    );
  }

  // ==========================================
  // 6. MẪU Y2K CHROME CYBER (Mẫu 2 & 12)
  // ==========================================
  Widget _buildY2kStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    final textColor = tpl.isDark ? Colors.white : const Color(0xFF1F1A3A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildPulsingStar('✦', tpl.accentColor, fontSize: 16),
                  const SizedBox(width: 4),
                  _buildPulsingStar('✧', tpl.accentColor, fontSize: 12),
                  const SizedBox(width: 4),
                  _buildPulsingStar('⋆', tpl.accentColor, fontSize: 14),
                ],
              ),
              _buildSenderHeaderBadge(user, name, tpl, isDark: tpl.isDark),
            ],
          ),

          const Spacer(),

          // Vòng tròn Liquid Chrome Holographic - Interactive Photo Slot
          Container(
            width: 182,
            height: 182,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE0D4F5), Color(0xFF7A70A0), Color(0xFFD8D0F8), Color(0xFFB8C8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF7A70A0).withValues(alpha: 0.45), blurRadius: 28, spreadRadius: 4),
              ],
            ),
            child: _buildInteractivePhotoSlot(
              slotKey: 'y2k',
              width: 172,
              height: 172,
              borderRadius: 86,
              placeholderLabel: 'Bấm để thêm ảnh phong cách Y2K',
              placeholderEmoji: '🛸',
              isDark: tpl.isDark,
              fallbackWidget: _buildAvatarImage(user, name, 172, 172, borderRadius: 86),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'PING MY ORBIT 🛸',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            'Bắn ảnh thẳng lên màn hình chính',
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12.5),
          ),

          const Spacer(),

          _buildInstagramLinkSticker('orbit.me/y2k', label: 'Vào quỹ đạo cùng tui ↗'),
          const SizedBox(height: 8),
          _buildMiniQrBadge(uid, isDark: tpl.isDark),
        ],
      ),
    );
  }

  // ==========================================
  // 7. MẪU GOLDEN HOUR (Mẫu 6 & 19)
  // ==========================================
  Widget _buildGoldenHourStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ORBIT 17:00 🌅',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              _buildSenderHeaderBadge(user, name, tpl, isDark: true),
            ],
          ),
          const SizedBox(height: 10),

          const Text(
            'golden hour with me 🌅',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'mỗi buổi chiều gửi hoàng hôn cho nhau qua màn hình',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
          ),

          const Spacer(),

          // Widget vòng tròn phát sáng ánh hoàng hôn - Interactive Photo Slot
          Container(
            width: 176,
            height: 176,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7E5F).withValues(alpha: 0.65),
                  blurRadius: 35,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: _buildInteractivePhotoSlot(
              slotKey: 'golden_hour',
              width: 166,
              height: 166,
              borderRadius: 83,
              placeholderLabel: 'Bấm để thêm ảnh hoàng hôn',
              placeholderEmoji: '🌅',
              isDark: true,
              fallbackWidget: _buildAvatarImage(user, name, 166, 166, borderRadius: 83),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),

          const Spacer(),

          _buildInstagramLinkSticker('orbit.app/sunset', label: 'Bấm kết nối hoàng hôn ↗'),
        ],
      ),
    );
  }

  // ==========================================
  // 8. BỐ CỤC EDITORIAL TIÊU CHUẨN NGHỆ THUẬT
  // ==========================================
  Widget _buildEditorialStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    final textColor = tpl.isDark ? Colors.white : const Color(0xFF1F1A3A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Column(
        children: [
          // Header Badge + Sender Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: tpl.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tpl.primaryColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tpl.centerIcon, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      'ORBIT WIDGET',
                      style: TextStyle(
                        color: tpl.primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSenderHeaderBadge(user, name, tpl, isDark: tpl.isDark),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            tpl.headline,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 19,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            tpl.subHeadline,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Center Interactive Photo Slot
          Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [tpl.primaryColor, tpl.accentColor]),
              boxShadow: [
                BoxShadow(
                  color: tpl.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 3,
                ),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: _buildInteractivePhotoSlot(
              slotKey: 'editorial_${tpl.id}',
              width: 166,
              height: 166,
              borderRadius: 83,
              placeholderLabel: 'Chạm để gắn ảnh widget',
              placeholderEmoji: tpl.centerIcon,
              isDark: tpl.isDark,
              fallbackWidget: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tpl.isDark ? const Color(0xFF120524) : Colors.white,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildAvatarImage(user, name, 80, 80, borderRadius: 40),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          _buildInstagramLinkSticker('orbit.app/ping', label: 'Ai muốn lên màn hình tui thì bấm đây 🪐'),
          const SizedBox(height: 8),
          _buildMiniQrBadge(uid, isDark: tpl.isDark),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildEqualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final v = _pulseController.value;
        final h1 = 5.0 + 13.0 * math.sin(v * math.pi);
        final h2 = 15.0 - 10.0 * math.cos(v * math.pi);
        final h3 = 7.0 + 12.0 * math.sin((v + 0.3) * math.pi);
        final h4 = 16.0 - 9.0 * math.cos((v + 0.5) * math.pi);
        final h5 = 6.0 + 11.0 * math.sin((v + 0.7) * math.pi);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [h1, h2, h3, h4, h5].map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3.5,
              height: h.clamp(4.0, 20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPulsingStar(String char, Color color, {double fontSize = 16}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final scale = 0.88 + 0.24 * _pulseController.value;
        return Transform.scale(
          scale: scale,
          child: Text(char, style: TextStyle(color: color, fontSize: fontSize)),
        );
      },
    );
  }

  Widget _buildSenderHeaderBadge(UserProfile? user, String name, StoryTemplateItem tpl, {bool isDark = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarImage(user, name, 22, 22, borderRadius: 11),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              '@$name',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF00FF66),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractivePhotoSlot({
    required String slotKey,
    required double width,
    required double height,
    required double borderRadius,
    required String placeholderLabel,
    required String placeholderEmoji,
    Color? borderColor,
    Color? backgroundColor,
    bool isDark = true,
    Widget? fallbackWidget,
  }) {
    final photoPath = _customPhotos[slotKey];
    final hasCustomPhoto = photoPath != null && File(photoPath).existsSync();

    return GestureDetector(
      onTap: () => _pickPhotoForSlot(slotKey),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: backgroundColor ??
                  (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04)),
              border: Border.all(
                color: borderColor ??
                    (hasCustomPhoto
                        ? const Color(0xFF00FF66).withValues(alpha: 0.7)
                        : (isDark ? Colors.white24 : Colors.black12)),
                width: hasCustomPhoto ? 2.0 : 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(math.max(0, borderRadius - 1)),
              child: hasCustomPhoto
                  ? Image.file(
                      File(photoPath),
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                    )
                  : (fallbackWidget ??
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(placeholderEmoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(height: 6),
                              Text(
                                placeholderLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_isExporting) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF66).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF00FF66), width: 0.8),
                                  ),
                                  child: const Text(
                                    '+ Thêm ảnh',
                                    style: TextStyle(
                                      color: Color(0xFF00FF66),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )),
            ),
          ),

          // Action badge when custom photo is active (hidden when exporting)
          if (hasCustomPhoto && !_isExporting)
            Positioned(
              right: 6,
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _clearPhotoForSlot(slotKey),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(Icons.close, size: 10, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 10, color: Color(0xFF00FF66)),
                        SizedBox(width: 3),
                        Text(
                          'Đổi',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage(UserProfile? user, String cleanName, double width, double height,
      {double borderRadius = 0}) {
    if (user?.avatarPath != null && File(user!.avatarPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(user.avatarPath!),
          width: width,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }
    final initial = cleanName.isNotEmpty ? cleanName[0].toUpperCase() : 'O';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFF7000FF)]),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(fontSize: width * 0.4, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInstagramLinkSticker(String url, {required String label}) {
    return GestureDetector(
      onTap: _isExporting ? null : () => _runExport(_StoryExportAction.instagramStory),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, color: Color(0xFF007AFF), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF007AFF),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniQrBadge(String uid, {bool isDark = true, String text = 'Quét để vào widget'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: QrImageView(
              data: 'orbit://invite/$uid',
              version: QrVersions.auto,
              size: 22,
              padding: EdgeInsets.zero,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: isDark ? Colors.white : Colors.black,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
