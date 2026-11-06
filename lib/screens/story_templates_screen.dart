import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';

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

  @override
  State<StoryTemplatesScreen> createState() => _StoryTemplatesScreenState();
}

class _StoryTemplatesScreenState extends State<StoryTemplatesScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  int _selectedTemplateIndex = 0;
  bool _isExporting = false;

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

  Future<void> _exportAndSaveStory() async {
    setState(() => _isExporting = true);
    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/orbit_story_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF00FF66),
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.black),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã lưu ảnh Story HD (9:16) sẵn sàng đăng lên Instagram / TikTok!',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xuất ảnh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTpl = templates[_selectedTemplateIndex];
    final user = AuthService.instance.currentUser;

    return Scaffold(
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
            onPressed: _isExporting ? null : _exportAndSaveStory,
            icon: _isExporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.ios_share, color: Color(0xFF00F0FF)),
            label: const Text(
              'Lưu Story',
              style: TextStyle(color: Color(0xFF00F0FF), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 9:16 Story Preview Card
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
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: currentTpl.backgroundGradient,
                        ),
                        child: _buildStoryCardContent(currentTpl, user),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Template Selector Bottom Carousel
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
                          textAlign: TextAlign.right,
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
    );
  }

  /// Bộ điều hướng layout sáng tạo theo từng mẫu chuyên biệt
  Widget _buildStoryCardContent(StoryTemplateItem tpl, UserProfile? user) {
    final displayNameClean = cleanDisplayName(user?.displayName);
    final userUid = user?.uid ?? 'orbit_user';

    // 1. Mẫu 3: Retro Polaroid 90s (Khung ảnh Polaroid nghiêng + Washi tape + Chữ ký)
    if (tpl.id == 3) {
      return _buildPolaroidStory(tpl, user, displayNameClean, userUid);
    }

    // 2. Mẫu 11: Korean 4-Cut Photobooth (Dải ảnh Life4Cuts Hàn Quốc + Barcode)
    if (tpl.id == 11) {
      return _buildPhotoboothStory(tpl, user, displayNameClean, userUid);
    }

    // 3. Mẫu 15: iOS Lock Screen Drop (Màn hình khóa iPhone 11:11 + Banner thông báo kính mờ)
    if (tpl.id == 15) {
      return _buildIosLockScreenStory(tpl, user, displayNameClean, userUid);
    }

    // 4. Mẫu 18: Spotify Music Duo (Đĩa than xoay tròn + Thanh phát nhạc Spotify + Nút Play)
    if (tpl.id == 18) {
      return _buildSpotifyStory(tpl, user, displayNameClean, userUid);
    }

    // 5. Mẫu 9 & 20: Soulmate Duo & Sợi chỉ đỏ (Hai hành tinh kết nối vô cực + Dành cho Bestie #1)
    if (tpl.id == 9 || tpl.id == 20) {
      return _buildSoulmateStory(tpl, user, displayNameClean, userUid);
    }

    // 6. Mẫu 2 & 12: Y2K Cyber Chrome (Ngôi sao kim loại ✦ + Vòng xoay holographic)
    if (tpl.id == 2 || tpl.id == 12) {
      return _buildY2kStory(tpl, user, displayNameClean, userUid);
    }

    // 7. Mẫu 6 & 19: Golden Hour & Sunset Beach (Hoàng hôn thơ mộng + Typography thanh lịch)
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: Column(
        children: [
          // Băng dính Washi Tape phía trên
          Container(
            width: 90,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFC4A482).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
              ],
            ),
            child: const Center(
              child: Text('✦ ORBIT ✦', style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),

          // Lời mời nhẹ nhàng phong cách Story Instagram
          const Text(
            'drop a memory on my screen ☕',
            style: TextStyle(
              color: Color(0xFF4A3E30),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'chụp 1 tấm ảnh xinh gửi vào widget của tui nhé',
            style: TextStyle(color: Color(0xFF7A6E60), fontSize: 12),
          ),

          const Spacer(),

          // Khung ảnh Polaroid nghiêng 2 độ
          Transform.rotate(
            angle: -0.035,
            child: Container(
              width: 220,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
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
                  // Ảnh chính
                  Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      color: const Color(0xFF201B15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: _buildAvatarImage(user, name, 192, 192, borderRadius: 2),
                  ),
                  const SizedBox(height: 12),
                  // Dòng chữ viết tay & ngày tháng film
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$name :)',
                        style: const TextStyle(
                          color: Color(0xFF2C2218),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'serif',
                        ),
                      ),
                      const Text(
                        "'26 11 05",
                        style: TextStyle(
                          color: Color(0xFFFF5500),
                          fontSize: 12,
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

          // Instagram Link Sticker & Stamp quét mã tinh tế
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInstagramLinkSticker('orbit.app/connect', label: 'Thêm vào màn hình tui ↗'),
              const SizedBox(width: 10),
              _buildMiniQrBadge(uid),
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          // Dải ảnh Life4Cuts trắng tinh tế
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PHOTOISM', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2, color: Colors.black)),
                    Text('ORBIT STUDIO', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 9, color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 10),

                // Ô ảnh 1: Avatar thật người gửi
                Container(
                  width: 196,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: _buildAvatarImage(user, name, 196, 120, borderRadius: 3),
                ),
                const SizedBox(height: 8),

                // Ô ảnh 2: Slot chờ bạn thân
                Container(
                  width: 196,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFF5499C7).withValues(alpha: 0.4), style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎀', style: TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          '[ + ] Chừa slot cho bạn thân',
                          style: TextStyle(color: const Color(0xFF1B4F72).withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Barcode kiểu photobooth Hàn Quốc
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('||||| |||| || ||||| |', style: TextStyle(fontSize: 16, letterSpacing: 1.5, fontFamily: 'monospace', color: Colors.black)),
                    Text('SEOUL · ${DateTime.now().year}', style: const TextStyle(fontSize: 9, color: Colors.black45)),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Instagram Link Sticker
          _buildInstagramLinkSticker('orbit.app/photobooth', label: 'Chụp ảnh đôi cùng tui nè 📸'),
          const SizedBox(height: 8),
          _buildMiniQrBadge(uid, text: 'Quét kết bạn ngay'),
        ],
      ),
    );
  }

  // ==========================================
  // 3. MẪU MÀN HÌNH KHÓA IPHONE (Mẫu 15)
  // ==========================================
  Widget _buildIosLockScreenStory(StoryTemplateItem tpl, UserProfile? user, String name, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          // Ổ khóa iPhone
          const Icon(Icons.lock, color: Colors.white, size: 16),
          const SizedBox(height: 4),

          // Đồng hồ màn hình khóa lớn phong cách iOS
          const Text(
            '11:11',
            style: TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w200,
              letterSpacing: -2,
            ),
          ),
          const Text(
            'Thứ Hai, 5 tháng 11',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400),
          ),

          const SizedBox(height: 32),

          // Apple Frosted Glass Notification Banner
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarImage(user, name, 46, 46, borderRadius: 23),
                    const SizedBox(width: 12),
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
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [Color(0xFF00F0FF), Color(0xFFD000FF)]),
                                    ),
                                    child: const Center(child: Text('🪐', style: TextStyle(fontSize: 8))),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('ORBIT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const Text('Vừa xong', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Vừa gửi 1 khoảnh khắc mới lên màn hình chính của bạn 📸',
                            style: TextStyle(color: Colors.white, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          const SizedBox(height: 16),

          // Sticker liên kết
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: Column(
        children: [
          // Header Spotify Story
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(width: 8),
              const Text('PLAYING ON ORBIT', style: TextStyle(color: Color(0xFF1DB954), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),

          const Spacer(),

          // Đĩa than Vinyl trượt ra từ bìa album
          SizedBox(
            width: 240,
            height: 160,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Đĩa than phía sau
                Positioned(
                  right: 0,
                  top: 10,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0A0A0A),
                      border: Border.all(color: Colors.white12, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1DB954),
                        ),
                        child: const Center(child: Text('🪐', style: TextStyle(fontSize: 20))),
                      ),
                    ),
                  ),
                ),
                // Bìa Album thật hiển thị ảnh Avatar
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: _buildAvatarImage(user, name, 160, 160, borderRadius: 10),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tên bài hát & Tên người bạn
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Our Orbit Track 🪐',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
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

          // Link Sticker
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          // Header Cận tâm
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tpl.primaryColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tpl.centerIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'DUO ORBIT · ONLY FOR #1',
                  style: TextStyle(color: tpl.primaryColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'waiting for my other half 🤍',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, fontFamily: 'serif'),
          ),
          const SizedBox(height: 4),
          Text(
            'Quỹ đạo Cận tâm độc quyền dành riêng cho 2 đứa mình',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
          ),

          const Spacer(),

          // Sân khấu Sao Đôi: Node bạn và Node chờ đối phương
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Node bạn
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
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),

              const SizedBox(width: 14),

              // Biểu tượng Vô cực trái tim
              Column(
                children: [
                  Text('∞', style: TextStyle(color: tpl.primaryColor, fontSize: 32, fontWeight: FontWeight.w200)),
                  Text('~0 km', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                ],
              ),

              const SizedBox(width: 14),

              // Node chờ bạn thân
              Column(
                children: [
                  Container(
                    width: 85,
                    height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: tpl.primaryColor.withValues(alpha: 0.6), width: 2, style: BorderStyle.solid),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 28),
                          Text('Bạn thân', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Bạn số #1', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Link Sticker
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('✦ ✧ ⋆', style: TextStyle(color: tpl.accentColor, fontSize: 16)),
              Text('Y2K ORBIT', style: TextStyle(color: textColor, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
              Text('⋆ ✧ ✦', style: TextStyle(color: tpl.accentColor, fontSize: 16)),
            ],
          ),

          const Spacer(),

          // Vòng tròn Liquid Chrome Holographic
          Container(
            width: 180,
            height: 180,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFE0D4F5), Color(0xFF7A70A0), Color(0xFFD8D0F8), Color(0xFFB8C8F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF7A70A0).withValues(alpha: 0.4), blurRadius: 28, spreadRadius: 4),
              ],
            ),
            child: _buildAvatarImage(user, name, 168, 168, borderRadius: 84),
          ),

          const SizedBox(height: 20),

          Text(
            'PING MY ORBIT 🛸',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            'Bắn ảnh thẳng lên màn hình chính',
            style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          const Text(
            'golden hour with me 🌅',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'mỗi buổi chiều gửi hoàng hôn cho nhau qua màn hình',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
          ),

          const Spacer(),

          // Widget vòng tròn phát sáng ánh hoàng hôn
          Container(
            width: 175,
            height: 175,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7E5F).withValues(alpha: 0.6),
                  blurRadius: 35,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: _buildAvatarImage(user, name, 165, 165, borderRadius: 85),
          ),

          const SizedBox(height: 14),

          Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: Column(
        children: [
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: tpl.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tpl.primaryColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tpl.centerIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'ORBIT WIDGET',
                  style: TextStyle(
                    color: tpl.primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            tpl.headline,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            tpl.subHeadline,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: 12.5,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Center Avatar Widget tròn
          Container(
            width: 175,
            height: 175,
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
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tpl.isDark ? const Color(0xFF120524) : Colors.white,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatarImage(user, name, 85, 85, borderRadius: 45),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

  Widget _buildAvatarImage(UserProfile? user, String cleanName, double width, double height, {double borderRadius = 0}) {
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
    // Fallback nếu người dùng chưa đặt avatar
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
    return Container(
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
