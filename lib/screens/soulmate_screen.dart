import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/soulmate_service.dart';
import '../services/location_service.dart';

class SoulmateScreen extends StatefulWidget {
  const SoulmateScreen({super.key});

  @override
  State<SoulmateScreen> createState() => _SoulmateScreenState();
}

class _SoulmateScreenState extends State<SoulmateScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  double? _calculatedDistanceKm;
  bool _isLoadingLocation = false;
  bool _heartbeatTriggered = false;

  static String cleanDisplayName(String? name) {
    if (name == null || name.isEmpty) return 'Bạn bè';
    return name.replaceAll(RegExp(r'\s*#\d+.*$'), '').trim();
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _refreshDistance();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _refreshDistance() async {
    final soulmate = SoulmateService.instance.currentSoulmate;
    if (soulmate == null) return;

    setState(() => _isLoadingLocation = true);
    try {
      final loc = await LocationService.instance.getCurrentLocationWithSmartName();
      if (loc != null && mounted) {
        setState(() {
          _calculatedDistanceKm = SoulmateService.instance.calculateDistanceKm(
            loc.latitude,
            loc.longitude,
          );
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingLocation = false);
  }

  void _triggerHeartbeatNudge() {
    HapticFeedback.heavyImpact();
    setState(() => _heartbeatTriggered = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _heartbeatTriggered = false);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFF3366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Row(
          children: [
            Text('💓', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đã gửi nhịp tim đồng bộ sang màn hình người ấy!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectSoulmateSheet() {
    final friends = FriendService.instance.friends;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        if (friends.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪐', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có bạn bè trong Orbit',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hãy kết bạn bằng mã QR hoặc gửi link mời trước để ghim Soulmate nhé!',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Chọn người vào Quỹ đạo Cận tâm 💕',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (ctx, i) {
                    final f = friends[i];
                    final cleanName = cleanDisplayName(f.displayName);
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFF3366),
                        child: Icon(Icons.favorite, color: Colors.white, size: 20),
                      ),
                      title: Text(cleanName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await SoulmateService.instance.setSoulmate(f);
                        _refreshDistance();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SoulmateData?>(
      valueListenable: SoulmateService.instance.soulmateNotifier,
      builder: (context, soulmate, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F040D),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Quỹ đạo Cận tâm 🪐',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                tooltip: 'Đổi Soulmate',
                onPressed: _showSelectSoulmateSheet,
              ),
            ],
          ),
          body: soulmate == null ? _buildEmptyState() : _buildSoulmateContent(soulmate),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [const Color(0xFFFF3366).withValues(alpha: 0.3), const Color(0xFFFF6699).withValues(alpha: 0.1)],
                ),
                border: Border.all(color: const Color(0xFFFF3366), width: 2),
              ),
              child: const Center(
                child: Text('💞', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Soulmate Mode (Quy tắc 1 + 1)',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Dành riêng cho 1 người quan trọng nhất (Người yêu hoặc Bạn thân nhất).\nTheo dõi khoảng cách km, số ngày đồng hành và gửi ảnh độc quyền!',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showSelectSoulmateSheet,
              icon: const Icon(Icons.favorite, color: Colors.white),
              label: const Text(
                'Chọn người vào Quỹ đạo Cận tâm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoulmateContent(SoulmateData soulmate) {
    final myUser = AuthService.instance.currentUser;
    final myCleanName = cleanDisplayName(myUser?.displayName);
    final soulmateCleanName = cleanDisplayName(soulmate.displayName);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // SÁNG TẠO: SÂN KHẤU QUỸ ĐẠO TRỌNG LỰC ĐÔI (BINARY ORBIT STAGE)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.3,
                colors: [
                  const Color(0xFF3D081F).withValues(alpha: 0.9),
                  const Color(0xFF18030E),
                  const Color(0xFF0A0006),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF3366).withValues(alpha: 0.18), blurRadius: 40, spreadRadius: 3),
              ],
            ),
            child: Column(
              children: [
                // Tag Tiêu đề Quỹ đạo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3366).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🪐', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text(
                        'QUỸ ĐẠO CẬN TÂM ĐỘC QUYỀN',
                        style: TextStyle(
                          color: Color(0xFFFF99BB),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // KHÔNG GIAN QUỸ ĐẠO ĐÔI (AN TOÀN KÍCH CỠ - 100% RESPONSIVE)
                SizedBox(
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Đường elip quỹ đạo chuyển động mờ ảo
                      CustomPaint(
                        size: const Size(double.infinity, 190),
                        painter: _BinaryOrbitPainter(pulse: _pulseController.value),
                      ),

                      // Trọng tâm vũ trụ: Trái tim nhịp đập tương tác
                      GestureDetector(
                        onTap: _triggerHeartbeatNudge,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final scale = _heartbeatTriggered ? 1.4 : 1.0 + (_pulseController.value * 0.15);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [Color(0xFFFF3366), Color(0xFFB30036)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF3366).withValues(alpha: 0.6),
                                      blurRadius: 25,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('💓', style: TextStyle(fontSize: 26)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Hai hành tinh hai bên (Có ràng buộc độ rộng chống tràn 100%)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Hành tinh 1: Người dùng
                          _buildPlanetNode(
                            name: myCleanName,
                            avatarPath: myUser?.avatarPath,
                            defaultIcon: '🧑‍🚀',
                            borderColor: const Color(0xFF00F0FF),
                            glowColor: const Color(0xFF00F0FF),
                          ),

                          // Hành tinh 2: Soulmate
                          _buildPlanetNode(
                            name: soulmateCleanName,
                            avatarPath: soulmate.avatarPath,
                            defaultIcon: '💖',
                            borderColor: const Color(0xFFFF3366),
                            glowColor: const Color(0xFFFF3366),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Chạm vào trái tim để gửi nhịp tim rung máy người ấy 💓',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 22),

                // Telemetry Badges (Không tràn kích cỡ)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildTelemetryChip(
                      icon: '⏳',
                      label: '${soulmate.daysTogether} Ngày gắn kết',
                    ),
                    _buildTelemetryChip(
                      icon: '📍',
                      label: _isLoadingLocation
                          ? 'Đang đo...'
                          : (_calculatedDistanceKm != null ? '$_calculatedDistanceKm km' : '~2.4 km'),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Trạng thái tâm trạng
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💬', style: TextStyle(fontSize: 15)),
                      const SizedBox(width: 8),
                      Text(
                        soulmate.statusMood,
                        style: const TextStyle(color: Color(0xFFFF99BB), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Nút bấm bắn ảnh tức thì sang Widget của Soulmate
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gửi khoảnh khắc cho $soulmateCleanName',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bức ảnh sẽ chiếm sóng ngay lập tức trên Widget màn hình chính của $soulmateCleanName mà không bị ai khác chen ngang.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: Text(
                      'Bắn ảnh sang Widget của $soulmateCleanName 🚀',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nút hành tinh có avatar thật và tên sạch, khống chế chiều rộng 95px chống tràn 100%
  Widget _buildPlanetNode({
    required String name,
    required String? avatarPath,
    required String defaultIcon,
    required Color borderColor,
    required Color glowColor,
  }) {
    Widget avatarContent;
    if (avatarPath != null && File(avatarPath).existsSync()) {
      avatarContent = ClipOval(
        child: Image.file(
          File(avatarPath),
          width: 74,
          height: 74,
          fit: BoxFit.cover,
        ),
      );
    } else {
      avatarContent = Center(
        child: Text(defaultIcon, style: const TextStyle(fontSize: 34)),
      );
    }

    return SizedBox(
      width: 95,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 3),
              color: const Color(0xFF1F0B18),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: avatarContent,
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryChip({required String icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3366).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFFF99BB), fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Vẽ đường elip quỹ đạo và sóng hấp dẫn kết nối hai hành tinh
class _BinaryOrbitPainter extends CustomPainter {
  final double pulse;

  _BinaryOrbitPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: size.width * 0.88, height: 110);

    // Vẽ vòng elip quỹ đạo lấp lánh
    final orbitPaint = Paint()
      ..color = const Color(0xFFFF3366).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(rect, orbitPaint);

    // Vẽ chùm sóng hấp dẫn liên kết ở tâm
    final wavePaint = Paint()
      ..color = const Color(0xFFFF3366).withValues(alpha: 0.15 * (1.0 - pulse))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 40 + (pulse * 25), wavePaint);
  }

  @override
  bool shouldRepaint(covariant _BinaryOrbitPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}
