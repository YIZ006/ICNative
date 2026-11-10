import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/soulmate_service.dart';

class SoulmateScreen extends StatefulWidget {
  const SoulmateScreen({super.key});

  @override
  State<SoulmateScreen> createState() => _SoulmateScreenState();
}

class _SoulmateScreenState extends State<SoulmateScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _radarController;

  double? _calculatedDistanceKm;
  bool _isLoadingLocation = false;
  String? _lastSentInteractionType;

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
      duration: const Duration(seconds: 14),
    )..repeat();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _refreshLocationAndBroadcast();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  /// Cập nhật GPS chuẩn xác và phát sóng vị trí cho đối phương
  Future<void> _refreshLocationAndBroadcast() async {
    final soulmate = SoulmateService.instance.currentSoulmate;
    if (soulmate == null) return;

    setState(() => _isLoadingLocation = true);
    _radarController.repeat();

    try {
      final loc = await SoulmateService.instance.broadcastMyLocationAndStatus();
      if (loc != null && mounted) {
        setState(() {
          _calculatedDistanceKm = SoulmateService.instance.calculateDistanceKm(
            loc.latitude,
            loc.longitude,
          );
        });
      }
    } catch (e) {
      debugPrint('Error updating soulmate location: $e');
    }

    if (mounted) {
      setState(() => _isLoadingLocation = false);
      _radarController.stop();
      _radarController.reset();
    }
  }

  /// Gửi tương tác trực tiếp sang điện thoại của Soulmate
  Future<void> _sendInteraction(String type, {String? message}) async {
    HapticFeedback.heavyImpact();
    setState(() => _lastSentInteractionType = type);

    await SoulmateService.instance.sendInteraction(
      type: type,
      message: message,
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _lastSentInteractionType = null);
    });

    if (!mounted) return;

    String actionMsg;
    String actionEmoji;
    switch (type) {
      case 'heartbeat':
        actionEmoji = '💓';
        actionMsg = 'Đã gửi nhịp tim rung máy sang người ấy!';
        break;
      case 'kiss':
        actionEmoji = '💋';
        actionMsg = 'Đã gửi một nụ hôn nồng ấm!';
        break;
      case 'miss_you':
        actionEmoji = '🥺';
        actionMsg = 'Đã gửi thông báo nhớ người ấy!';
        break;
      case 'hug':
        actionEmoji = '🫂';
        actionMsg = 'Đã gửi một cái ôm ấm áp!';
        break;
      case 'poke':
        actionEmoji = '🛸';
        actionMsg = 'Đã chọt màn hình người ấy!';
        break;
      case 'love_note':
        actionEmoji = '💌';
        actionMsg = 'Đã ghim lời nhắn lên Widget của người ấy!';
        break;
      default:
        actionEmoji = '✨';
        actionMsg = 'Đã gửi tương tác!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2C0A1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
        ),
        content: Row(
          children: [
            Text(actionEmoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                actionMsg,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Dialog viết lời nhắn yêu thương ghim lên Widget người ấy
  void _showLoveNoteDialog(SoulmateData soulmate) {
    final cleanName = cleanDisplayName(soulmate.displayName);
    final textController = TextEditingController(text: soulmate.lastNote ?? '');

    final quickSuggestions = [
      'Nhớ uống nước nha 🥤',
      'Hôm nay làm tốt lắm ❤️',
      'Tối nay gặp nhau nhé 🛵',
      'Yêu cậu nhiều 💕',
      'Đang nhớ bạn nè 🥺',
      'Cố lên sắp được về rồi ✨',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F0B18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('💌', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ghim Lời Nhắn Lên Widget Của $cleanName',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mẩu tin này sẽ nhảy thẳng lên màn hình chính của $cleanName!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: textController,
                maxLength: 60,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Nhập lời nhắn yêu thương (VD: Tối nay ăn gì nà?)...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFFF3366)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFFF3366), width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              const Text('Gợi ý nhanh:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickSuggestions.map((s) {
                  return GestureDetector(
                    onTap: () => textController.text = s,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final text = textController.text.trim();
                    if (text.isNotEmpty) {
                      Navigator.pop(ctx);
                      await SoulmateService.instance.updateLoveNote(text);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  label: const Text('Ghim lên Widget người ấy 🚀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3366),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Sheet đổi tâm trạng (Mood Status)
  void _showMoodSheet(SoulmateData soulmate) {
    final moods = [
      'Đang nhớ bạn 💭',
      'Đang đi học / đi làm 💼',
      'Đang đi ăn ngon nè 🍜',
      'Đang chill cà phê ☕',
      'Hơi mệt một tẹo 🥺',
      'Đang tập thể dục 🏃',
      'Chuẩn bị ngủ rồi 🌙',
      'Hạnh phúc vô cùng 🥰',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                  'Chọn tâm trạng chia sẻ cùng người ấy 💬',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: moods.length,
                  itemBuilder: (ctx, idx) {
                    final m = moods[idx];
                    final isCurrent = m == soulmate.statusMood;
                    return ListTile(
                      title: Text(
                        m,
                        style: TextStyle(
                          color: isCurrent ? const Color(0xFFFF3366) : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isCurrent ? const Icon(Icons.check, color: Color(0xFFFF3366)) : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await SoulmateService.instance.updateMood(m);
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

  /// Sheet chọn bạn thân / đổi Soulmate
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
                        _refreshLocationAndBroadcast();
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
                icon: RotationTransition(
                  turns: _radarController,
                  child: const Icon(Icons.sync, color: Color(0xFF00F0FF)),
                ),
                tooltip: 'Làm mới vị trí GPS',
                onPressed: _isLoadingLocation ? null : _refreshLocationAndBroadcast,
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.white),
                tooltip: 'Đổi Soulmate',
                onPressed: _showSelectSoulmateSheet,
              ),
            ],
          ),
          body: soulmate == null
              ? _buildEmptyState()
              : Stack(
                  children: [
                    _buildSoulmateContent(soulmate),
                    _buildLiveNotificationOverlay(),
                  ],
                ),
        );
      },
    );
  }

  /// Banner thông báo trực tiếp nổi lên khi người ấy vừa gửi tương tác
  Widget _buildLiveNotificationOverlay() {
    return ValueListenableBuilder<CoupleInteraction?>(
      valueListenable: SoulmateService.instance.incomingInteractionNotifier,
      builder: (context, incoming, _) {
        if (incoming == null) return const SizedBox.shrink();

        return Positioned(
          top: 10,
          left: 16,
          right: 16,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -50, end: 0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, val, child) {
              return Transform.translate(
                offset: Offset(0, val),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B0B24), Color(0xFF1E0513)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF3366), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFFF3366).withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFFF3366), Color(0xFFFF6699)]),
                    ),
                    child: Center(
                      child: Text(incoming.typeEmoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              incoming.senderName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const Text('Vừa xong', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          incoming.message ?? incoming.typeTitle,
                          style: const TextStyle(color: Color(0xFFFFB3CC), fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      SoulmateService.instance.dismissIncomingInteraction();
                      _sendInteraction('heartbeat');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('💓 Đáp lại', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 16),
                    onPressed: () => SoulmateService.instance.dismissIncomingInteraction(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
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
              'Dành riêng cho 1 người quan trọng nhất (Người yêu hoặc Bạn thân nhất).\nTheo dõi khoảng cách GPS chuẩn, bắn nhịp tim rung máy và ghim lời nhắn lên Widget!',
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
    final myLocName = SoulmateService.instance.myLastLocation?.displayName ?? 'Hà Nội';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // SÂN KHẤU QUỸ ĐẠO TRỌNG LỰC ĐÔI (BINARY ORBIT STAGE)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.3,
                colors: [
                  const Color(0xFF3D081F).withValues(alpha: 0.95),
                  const Color(0xFF18030E),
                  const Color(0xFF0A0006),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF3366).withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 3),
              ],
            ),
            child: Column(
              children: [
                // Tag Tiêu đề Quỹ đạo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🪐', style: TextStyle(fontSize: 13)),
                          SizedBox(width: 5),
                          Text(
                            'QUỸ ĐẠO CẬN TÂM ĐỘC QUYỀN',
                            style: TextStyle(
                              color: Color(0xFFFF99BB),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Huy hiệu Trực tuyến
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00FF66),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          soulmate.timeAgo,
                          style: const TextStyle(color: Color(0xFF00FF66), fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // KHÔNG GIAN QUỸ ĐẠO ĐÔI
                SizedBox(
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 190),
                        painter: _BinaryOrbitPainter(pulse: _pulseController.value),
                      ),

                      // Trọng tâm vũ trụ: Trái tim nhịp đập tương tác
                      GestureDetector(
                        onTap: () => _sendInteraction('heartbeat'),
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final isTriggered = _lastSentInteractionType == 'heartbeat';
                            final scale = isTriggered ? 1.4 : 1.0 + (_pulseController.value * 0.15);
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [Color(0xFFFF3366), Color(0xFFB30036)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF3366).withValues(alpha: 0.65),
                                      blurRadius: 26,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('💓', style: TextStyle(fontSize: 28)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Hai hành tinh hai bên
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPlanetNode(
                            name: myCleanName,
                            subLabel: myLocName,
                            avatarPath: myUser?.avatarPath,
                            defaultIcon: '🧑‍🚀',
                            borderColor: const Color(0xFF00F0FF),
                            glowColor: const Color(0xFF00F0FF),
                          ),

                          _buildPlanetNode(
                            name: soulmateCleanName,
                            subLabel: soulmate.placeName ?? 'Hồ Tây, Hà Nội',
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

                const SizedBox(height: 6),
                const Text(
                  'Chạm vào trái tim để gửi nhịp tim rung máy người ấy 💓',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Telemetry Chips (GPS Chuẩn & Ngày gắn kết)
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
                          ? 'Đang đo GPS...'
                          : SoulmateService.instance.formatDistance(_calculatedDistanceKm),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Địa điểm chi tiết của Soulmate
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF00F0FF), size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'Vị trí người ấy: ${soulmate.placeName ?? "Hồ Tây, Hà Nội"}',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Tâm trạng hiện tại
                GestureDetector(
                  onTap: () => _showMoodSheet(soulmate),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3366).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          soulmate.statusMood,
                          style: const TextStyle(color: Color(0xFFFF99BB), fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: Color(0xFFFF99BB)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // THANH TƯƠNG TÁC TRỰC TIẾP 1-CHẠM (DIRECT LIVE ACTIONS)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      'Tương Tác Trực Tiếp 1-Chạm (Live Ping)',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Bấm là gửi hiệu ứng & rung điện thoại người ấy ngay lập tức',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildActionButton(
                      emoji: '💓',
                      label: 'Nhịp tim',
                      type: 'heartbeat',
                      glowColor: const Color(0xFFFF3366),
                    ),
                    _buildActionButton(
                      emoji: '💋',
                      label: 'Gửi hôn',
                      type: 'kiss',
                      glowColor: const Color(0xFFFF6699),
                    ),
                    _buildActionButton(
                      emoji: '🥺',
                      label: 'Nhớ cậu',
                      type: 'miss_you',
                      glowColor: const Color(0xFF66B2FF),
                    ),
                    _buildActionButton(
                      emoji: '🫂',
                      label: 'Ôm cái',
                      type: 'hug',
                      glowColor: const Color(0xFFFFB84D),
                    ),
                    _buildActionButton(
                      emoji: '🛸',
                      label: 'Ping',
                      type: 'poke',
                      glowColor: const Color(0xFF00FF66),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // LỜI NHẮN YÊU THƯƠNG GHIM LÊN WIDGET (LOVE STICKY NOTE)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1724), Color(0xFF1D0A16)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('💌', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          'Lời Nhắn Ghim Lên Widget',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => _showLoveNoteDialog(soulmate),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3366),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 11, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Viết mới', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        soulmate.lastNote != null && soulmate.lastNote!.isNotEmpty
                            ? '“${soulmate.lastNote}”'
                            : '“Chưa có lời nhắn nào được ghim. Chạm Viết mới để gửi nhé!”',
                        style: const TextStyle(
                          color: Color(0xFFFFE6EE),
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Đang hiển thị trên Widget màn hình chính của $soulmateCleanName',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // NHẬT KÝ TƯƠNG TÁC GẦN ĐÂY (LIVE ACTIVITY LOG)
          ValueListenableBuilder<List<CoupleInteraction>>(
            valueListenable: SoulmateService.instance.interactionsNotifier,
            builder: (context, interactions, _) {
              if (interactions.isEmpty) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('⏱️', style: TextStyle(fontSize: 15)),
                        SizedBox(width: 6),
                        Text(
                          'Nhật Ký Tương Tác Gần Đây',
                          style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    ...interactions.take(4).map((act) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Text(act.typeEmoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${act.senderName}: ${act.typeTitle}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  if (act.message != null && act.message!.isNotEmpty)
                                    Text(
                                      act.message!,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            Text(act.timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // NÚT BẮN ẢNH TỨC THÌ SANG WIDGET
          Container(
            padding: const EdgeInsets.all(18),
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
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bức ảnh sẽ chiếm sóng ngay lập tức trên Widget màn hình chính của $soulmateCleanName.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5),
                ),
                const SizedBox(height: 14),
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

  Widget _buildActionButton({
    required String emoji,
    required String label,
    required String type,
    required Color glowColor,
  }) {
    final isSelected = _lastSentInteractionType == type;

    return GestureDetector(
      onTap: () => _sendInteraction(type),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isSelected ? 52 : 46,
            height: isSelected ? 52 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: isSelected ? glowColor : Colors.white24, width: isSelected ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? glowColor.withValues(alpha: 0.6) : Colors.black26,
                  blurRadius: isSelected ? 16 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? glowColor : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanetNode({
    required String name,
    required String subLabel,
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
      width: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
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
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subLabel,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
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

    final orbitPaint = Paint()
      ..color = const Color(0xFFFF3366).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(rect, orbitPaint);

    final wavePaint = Paint()
      ..color = const Color(0xFFFF3366).withValues(alpha: 0.18 * (1.0 - pulse))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 40 + (pulse * 25), wavePaint);
  }

  @override
  bool shouldRepaint(covariant _BinaryOrbitPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}
