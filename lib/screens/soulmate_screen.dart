import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/soulmate_service.dart';
import '../utils/avatar_helper.dart';

class SoulmateScreen extends StatefulWidget {
  const SoulmateScreen({super.key});

  @override
  State<SoulmateScreen> createState() => _SoulmateScreenState();
}

class _VisualParticle {
  final String emoji;
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  final double scale;
  final double rotation;

  _VisualParticle({
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.scale,
    required this.rotation,
  });
}

class _SoulmateScreenState extends State<SoulmateScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _orbitController;
  late AnimationController _radarController;
  late AnimationController _visualFxController;

  double? _calculatedDistanceKm;
  bool _isLoadingLocation = false;
  String? _lastSentInteractionType;
  Color _activeFxColor = const Color(0xFFFF3366);
  final List<_VisualParticle> _activeParticles = [];

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

    _visualFxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _refreshLocationAndBroadcast();

    // Lắng nghe tương tác đến để kích hoạt hiệu ứng trực quan hoá ngay trên màn hình
    SoulmateService.instance.incomingInteractionNotifier.addListener(_onIncomingInteractionReceived);

    // Lắng nghe lời mời kết nối Quỹ đạo Cận tâm gửi đến mình
    SoulmateService.instance.incomingRequestNotifier.addListener(_onIncomingRequestChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIncomingRequestOnOpen();
    });
  }

  @override
  void dispose() {
    SoulmateService.instance.incomingInteractionNotifier.removeListener(_onIncomingInteractionReceived);
    SoulmateService.instance.incomingRequestNotifier.removeListener(_onIncomingRequestChanged);
    _pulseController.dispose();
    _orbitController.dispose();
    _radarController.dispose();
    _visualFxController.dispose();
    super.dispose();
  }

  void _onIncomingInteractionReceived() {
    final incoming = SoulmateService.instance.incomingInteractionNotifier.value;
    if (incoming != null && mounted) {
      _triggerVisualInteraction(incoming.type, isIncoming: true);
    }
  }

  void _onIncomingRequestChanged() {
    final req = SoulmateService.instance.incomingRequestNotifier.value;
    if (req != null && mounted) {
      _showIncomingSoulmateRequestDialog(req);
    }
  }

  void _checkIncomingRequestOnOpen() {
    final req = SoulmateService.instance.incomingRequestNotifier.value;
    if (req != null && mounted) {
      _showIncomingSoulmateRequestDialog(req);
    }
  }

  /// Trực quan hoá tương tác thời gian thực (Particle wave & Shockwave)
  void _triggerVisualInteraction(String type, {bool isIncoming = false}) {
    switch (type) {
      case 'heartbeat':
        _activeFxColor = const Color(0xFFFF3366);
        break;
      case 'kiss':
        _activeFxColor = const Color(0xFFFF6699);
        break;
      case 'miss_you':
        _activeFxColor = const Color(0xFF66B2FF);
        break;
      case 'hug':
        _activeFxColor = const Color(0xFFFFB84D);
        break;
      case 'poke':
        _activeFxColor = const Color(0xFF00FF66);
        break;
      default:
        _activeFxColor = const Color(0xFFFF3366);
    }

    // Sinh 16 hạt hiệu ứng chuyển động đa hướng
    final rand = math.Random();
    final emojis = _getEmojisForType(type);
    _activeParticles.clear();

    for (int i = 0; i < 16; i++) {
      final emoji = emojis[rand.nextInt(emojis.length)];
      // Xuất phát từ hành tinh người gửi hướng sang người nhận
      final startX = isIncoming ? 0.75 + (rand.nextDouble() * 0.1) : 0.25 + (rand.nextDouble() * 0.1);
      final startY = 0.45 + (rand.nextDouble() * 0.15 - 0.075);
      final targetX = isIncoming ? 0.15 + (rand.nextDouble() * 0.2) : 0.65 + (rand.nextDouble() * 0.25);
      final targetY = 0.25 + (rand.nextDouble() * 0.5);

      _activeParticles.add(_VisualParticle(
        emoji: emoji,
        startX: startX,
        startY: startY,
        targetX: targetX,
        targetY: targetY,
        scale: 0.8 + (rand.nextDouble() * 0.8),
        rotation: (rand.nextDouble() - 0.5) * 2.0,
      ));
    }

    _visualFxController.forward(from: 0.0);
    setState(() {});
  }

  List<String> _getEmojisForType(String type) {
    switch (type) {
      case 'heartbeat':
        return ['💓', '💖', '💗', '❤️', '💕', '💓', '✨'];
      case 'kiss':
        return ['💋', '😘', '💋', '💄', '💖', '💋', '✨'];
      case 'miss_you':
        return ['🥺', '🤍', '💭', '🥺', '✨', '⭐', '🥺'];
      case 'hug':
        return ['🫂', '🧡', '✨', '🫂', '💛', '🤗', '🫂'];
      case 'poke':
        return ['🛸', '⚡', '✨', '🛸', '🟢', '🛸', '💥'];
      default:
        return ['✨', '💖', '💓', '🌟'];
    }
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

  /// Gửi tương tác trực tiếp sang điện thoại của Soulmate & trực quan hoá tức thì
  Future<void> _sendInteraction(String type, {String? message}) async {
    HapticFeedback.heavyImpact();
    setState(() => _lastSentInteractionType = type);

    // Kích hoạt trực quan hoá hiệu ứng ngay lập tức trên máy mình
    _triggerVisualInteraction(type, isIncoming: false);

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

  /// Hộp thoại nhận lời mời kết nối Quỹ đạo Cận tâm từ bạn bè
  void _showIncomingSoulmateRequestDialog(SoulmateRequest req) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFFFF3366), width: 2),
        ),
        title: const Row(
          children: [
            Text('🪐', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'LỜI MỜI QUỸ ĐẠO CẬN TÂM 💕',
                style: TextStyle(
                  color: Color(0xFFFF99BB),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarHelper.buildAvatar(
              displayName: req.senderName,
              avatarBase64: req.senderAvatarBase64,
              avatarPath: req.senderAvatar,
              uid: req.senderUid,
              size: 72,
              border: Border.all(color: const Color(0xFFFF3366), width: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              cleanDisplayName(req.senderName),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (req.senderPlaceName != null && req.senderPlaceName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 13, color: Color(0xFF00F0FF)),
                  const SizedBox(width: 4),
                  Text(
                    req.senderPlaceName!,
                    style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${cleanDisplayName(req.senderName)} muốn kết nối Quỹ đạo Cận tâm độc quyền (#1) với bạn!\n\n'
              'Hai bạn sẽ cùng chia sẻ vị trí thực tế, gửi nhịp tim rung máy và tương tác trực tiếp lên Widget màn hình chính.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              SoulmateService.instance.declineSoulmateRequest(req);
            },
            child: Text('Để sau', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3366),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await SoulmateService.instance.acceptSoulmateRequest(req);
              if (mounted) {
                _refreshLocationAndBroadcast();
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
                        const Text('🎉', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Đã kết nối thành công với ${cleanDisplayName(req.senderName)}!',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
            child: const Text('Đồng ý kết nối 💕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Sheet chọn bạn thân / đổi Soulmate kèm xác nhận gửi lời mời
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
                      leading: AvatarHelper.buildAvatar(
                        displayName: f.displayName,
                        avatarBase64: f.avatarBase64,
                        uid: f.uid,
                        size: 40,
                        border: Border.all(color: const Color(0xFFFF3366), width: 1.5),
                      ),
                      title: Text(cleanName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'UID: ${f.uid}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontFamily: 'monospace'),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _confirmAndSendSoulmateRequest(f);
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

  /// Hộp thoại xác nhận gửi lời mời kết nối Quỹ đạo Cận tâm
  void _confirmAndSendSoulmateRequest(Friend f) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
        ),
        title: const Row(
          children: [
            Text('💕', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Kết Nối Quỹ Đạo Cận Tâm',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarHelper.buildAvatar(
              displayName: f.displayName,
              avatarBase64: f.avatarBase64,
              uid: f.uid,
              size: 64,
              border: Border.all(color: const Color(0xFFFF3366), width: 2),
            ),
            const SizedBox(height: 12),
            Text(
              cleanDisplayName(f.displayName),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Gửi lời mời kết nối Quỹ đạo Cận tâm tới ${cleanDisplayName(f.displayName)}?\n\n'
              'Khi người ấy chấp nhận, hai bạn sẽ cùng chia sẻ vị trí thực tế, gửi nhịp tim rung máy và tương tác trực tiếp lên Widget màn hình chính.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Hủy', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              await SoulmateService.instance.sendSoulmateRequest(f);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF2C0A1E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
                    ),
                    content: Row(
                      children: [
                        const Text('💌', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Đã gửi lời mời tới ${cleanDisplayName(f.displayName)}! Đang đợi người ấy chấp nhận...',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            },
            child: const Text('Gửi lời mời 💕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLoveNoteDialog(SoulmateData soulmate) {
    final controller = TextEditingController(text: soulmate.lastNote ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C0A1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
        ),
        title: const Row(
          children: [
            Text('💌', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Ghim Lời Nhắn Lên Widget',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lời nhắn này sẽ xuất hiện ngay lập tức trên Widget màn hình chính của ${cleanDisplayName(soulmate.displayName)} 💕',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              maxLength: 60,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nhập lời nhắn yêu thương (VD: Hôm nay cậu nhớ ăn đúng giờ nha)...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12.5),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                counterStyle: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3366),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                await SoulmateService.instance.updateLoveNote(text);
              }
            },
            child: const Text('Ghim ngay ✨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMoodSheet(SoulmateData soulmate) {
    const moods = [
      'Đang nhớ bạn 💭',
      'Đang bận xíu 💼',
      'Đang ăn ngon 🍜',
      'Muốn đi chơi 🛵',
      'Đang buồn ngủ 😴',
      'Nhớ cậu phát điên 💖',
      'Đang tập thể dục 🏃',
      'Chill nghe nhạc 🎧',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1020),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
                'Cập nhật trạng thái tâm trạng 💭',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: moods.length,
                itemBuilder: (ctx, i) {
                  final m = moods[i];
                  return ListTile(
                    title: Text(m, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SoulmateData?>(
      valueListenable: SoulmateService.instance.soulmateNotifier,
      builder: (context, soulmate, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F020A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F020A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            centerTitle: true,
            title: const Text(
              'Quỹ đạo Cận tâm 🪐',
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                tooltip: 'Đổi người kết nối',
                onPressed: _showSelectSoulmateSheet,
              ),
            ],
          ),
          body: soulmate == null
              ? _buildEmptyState()
              : Stack(
                  children: [
                    _buildSoulmateContent(soulmate),
                    _buildVisualFxLayer(),
                    _buildLiveNotificationOverlay(),
                  ],
                ),
        );
      },
    );
  }

  /// Lớp hiệu ứng trực quan hoá tương tác bay lượn trên sân khấu
  Widget _buildVisualFxLayer() {
    return AnimatedBuilder(
      animation: _visualFxController,
      builder: (context, _) {
        if (!_visualFxController.isAnimating) return const SizedBox.shrink();

        final progress = _visualFxController.value;
        final opacity = progress < 0.2
            ? progress / 0.2
            : progress > 0.8
                ? (1.0 - progress) / 0.2
                : 1.0;

        return IgnorePointer(
          child: Stack(
            children: _activeParticles.map((p) {
              final curX = p.startX + (p.targetX - p.startX) * progress;
              // Đường cong parabola nhẹ
              final arc = math.sin(progress * math.pi) * 0.15;
              final curY = p.startY + (p.targetY - p.startY) * progress - arc;

              return Positioned(
                left: MediaQuery.of(context).size.width * curX,
                top: 260 * curY + 60,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: p.rotation * progress * 2 * math.pi,
                    child: Transform.scale(
                      scale: p.scale * (0.8 + progress * 0.5),
                      child: Text(
                        p.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
                              cleanDisplayName(incoming.senderName),
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
                child: Text('💕', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quỹ đạo Cận tâm đang trống',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Chọn 1 người đặc biệt nhất (#1) để cùng chia sẻ vị trí thực tế, nhịp tim đồng bộ và tương tác trực tiếp lên Widget.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3366),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _showSelectSoulmateSheet,
              icon: const Icon(Icons.favorite, color: Colors.white),
              label: const Text(
                'Chọn người kết nối 💕',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
    final myLocName = SoulmateService.instance.myLastLocation?.displayName ??
        (_isLoadingLocation ? 'Đang định vị...' : 'Vị trí của tôi');

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
                      AnimatedBuilder(
                        animation: Listenable.merge([_pulseController, _visualFxController]),
                        builder: (context, _) {
                          return CustomPaint(
                            size: const Size(double.infinity, 190),
                            painter: _BinaryOrbitPainter(
                              pulse: _pulseController.value,
                              visualFxProgress: _visualFxController.value,
                              activeColor: _activeFxColor,
                            ),
                          );
                        },
                      ),

                      // Trọng tâm vũ trụ: Trái tim nhịp đập tương tác
                      GestureDetector(
                        onTap: () => _sendInteraction('heartbeat'),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_pulseController, _visualFxController]),
                          builder: (context, child) {
                            final isTriggered = _lastSentInteractionType == 'heartbeat' || _visualFxController.isAnimating;
                            final fxBoost = _visualFxController.isAnimating ? (math.sin(_visualFxController.value * math.pi) * 0.35) : 0.0;
                            final scale = (isTriggered ? 1.35 : 1.0 + (_pulseController.value * 0.15)) + fxBoost;

                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [_activeFxColor, const Color(0xFFB30036)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _activeFxColor.withValues(alpha: 0.7),
                                      blurRadius: 28,
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
                            avatarBase64: myUser?.avatarBase64,
                            uid: myUser?.uid,
                            borderColor: const Color(0xFF00F0FF),
                            glowColor: const Color(0xFF00F0FF),
                          ),

                          _buildPlanetNode(
                            name: soulmateCleanName,
                            subLabel: soulmate.placeName ?? (_isLoadingLocation ? 'Đang định vị...' : 'Chưa chia sẻ vị trí'),
                            avatarPath: soulmate.avatarPath,
                            avatarBase64: soulmate.avatarBase64,
                            uid: soulmate.uid,
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
                  'Chạm vào trái tim để gửi nhịp tim rung máy người ấy 💖',
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

                // Địa điểm chi tiết THỰC TẾ của Soulmate (100% Không dùng vị trí ảo)
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
                        'Vị trí người ấy: ${soulmate.placeName ?? (_isLoadingLocation ? "Đang định vị GPS..." : "Chưa chia sẻ vị trí")}',
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
                        Text('📜', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 6),
                        Text(
                          'Nhật Ký Tương Tác Gần Đây',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: interactions.take(8).length,
                      separatorBuilder: (ctx, i) => Divider(color: Colors.white.withValues(alpha: 0.08), height: 16),
                      itemBuilder: (ctx, i) {
                        final act = interactions[i];
                        final isMe = act.senderId == myUser?.uid;
                        return Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMe
                                    ? const Color(0xFF00F0FF).withValues(alpha: 0.15)
                                    : const Color(0xFFFF3366).withValues(alpha: 0.15),
                              ),
                              child: Center(
                                child: Text(act.typeEmoji, style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMe ? 'Bạn ${act.typeTitle}' : '${cleanDisplayName(act.senderName)}: ${act.typeTitle}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                  if (act.message != null && act.message!.isNotEmpty)
                                    Text(
                                      '“${act.message}”',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              act.timeAgo,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 30),
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
    String? avatarBase64,
    String? uid,
    required Color borderColor,
    required Color glowColor,
  }) {
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
            child: AvatarHelper.buildAvatar(
              avatarPath: avatarPath,
              avatarBase64: avatarBase64,
              displayName: name,
              uid: uid,
              size: 74,
            ),
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

/// Vẽ đường elip quỹ đạo và sóng hấp dẫn kết nối hai hành tinh (Kèm Shockwave tương tác)
class _BinaryOrbitPainter extends CustomPainter {
  final double pulse;
  final double visualFxProgress;
  final Color activeColor;

  _BinaryOrbitPainter({
    required this.pulse,
    this.visualFxProgress = 0.0,
    this.activeColor = const Color(0xFFFF3366),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: size.width * 0.88, height: 110);

    final orbitPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(rect, orbitPaint);

    final wavePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.18 * (1.0 - pulse))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 40 + (pulse * 25), wavePaint);

    // Shockwave bùng nổ khi có tương tác trực tiếp
    if (visualFxProgress > 0.0) {
      final fxWave1 = Paint()
        ..color = activeColor.withValues(alpha: (1.0 - visualFxProgress) * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(center, 30 + (visualFxProgress * 85), fxWave1);

      if (visualFxProgress > 0.2) {
        final subProgress = (visualFxProgress - 0.2) / 0.8;
        final fxWave2 = Paint()
          ..color = activeColor.withValues(alpha: (1.0 - subProgress) * 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, 30 + (subProgress * 110), fxWave2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BinaryOrbitPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.visualFxProgress != visualFxProgress ||
        oldDelegate.activeColor != activeColor;
  }
}
