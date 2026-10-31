import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import 'package:icnative/settings/theme_colors.dart';

enum ScannerMode {
  any,
  addFriend,
  backupLogin,
}

class QRScannerScreen extends StatefulWidget {
  final ScannerMode mode;

  const QRScannerScreen({
    super.key,
    this.mode = ScannerMode.any,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  bool _isProcessing = false;
  bool _isLockedOn = false;

  late final AnimationController _hugAnimController;
  late final Animation<double> _boxScaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // Animation ôm mã QR: Co khung ngắm từ 260px xuống 215px và phát sáng viền vàng
    _hugAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _boxScaleAnimation = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _hugAnimController, curve: Curves.easeOutBack),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hugAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hugAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Thực hiện zoom camera mượt mà để ôm trọn mã QR
  Future<void> _smoothZoomIn() async {
    try {
      for (double z = 0.0; z <= 0.40; z += 0.08) {
        if (!mounted) break;
        await _controller.setZoomScale(z);
        await Future.delayed(const Duration(milliseconds: 20));
      }
    } catch (_) {}
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _isLockedOn = true;
    });

    // Kích hoạt animation camera zoom và khung viền ôm mã QR
    _hugAnimController.forward();
    await _smoothZoomIn();

    try {
      final data = jsonDecode(rawValue) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'iconnative_add_friend') {
        await _processAddFriend(data);
      } else if (type == 'iconnative_account_backup') {
        await _processAccountBackup(rawValue, data);
      } else {
        _showSnackbar('Mã QR này không thuộc về ứng dụng ICNative.');
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      // Not a valid JSON payload
      _showSnackbar('Mã QR không đúng định dạng của ICNative.');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isLockedOn = false;
        });
        _hugAnimController.reverse();
        try {
          _controller.setZoomScale(0.0);
        } catch (_) {}
      }
    }
  }

  Future<void> _processAddFriend(Map<String, dynamic> data) async {
    final uid = data['uid'] as String? ?? '';
    final name = data['name'] as String? ?? 'Bạn bè';

    final result = await FriendService.instance.sendFriendRequestOrConnect(
      friendUid: uid,
      friendName: name,
    );

    if (!mounted) return;

    if (result == FriendAddResult.selfError) {
      _showSnackbar('Đây là mã kết bạn của chính bạn!');
      await Future.delayed(const Duration(seconds: 2));
      return;
    }

    if (result == FriendAddResult.alreadyFriends) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: OrbitColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.people_alt_rounded, color: Color(0xFFFFD54F), size: 28),
              SizedBox(width: 10),
              Text(
                'Đã Là Bạn Bè',
                style: TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn và "$name" đã là bạn bè trên vòng tròn Orbit từ trước!',
            style: TextStyle(color: OrbitColors.deepOlive.withValues(alpha: 0.8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Đã hiểu', style: TextStyle(color: Color(0xFFE59866), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (result == FriendAddResult.acceptedImmediately) {
      // Cả 2 đã quét mã của nhau -> Kết bạn thành công 2 chiều tức thì!
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: OrbitColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFFFFD54F), size: 28),
              SizedBox(width: 10),
              Text(
                'Kết Nối Thành Công! 🪐',
                style: TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Đã kết nối 2 chiều với "$name"!\nCả hai bạn hiện đã cùng xuất hiện trên vòng tròn quỹ đạo của nhau để chia sẻ ảnh chụp và tương tác lên Widget màn hình chính.',
            style: TextStyle(color: OrbitColors.deepOlive.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OrbitColors.buttonPrimary,
                foregroundColor: OrbitColors.textLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Vào Vòng Tròn Quỹ Đạo 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (result == FriendAddResult.requestSent) {
      // Đã gửi lời mời -> Chờ người kia bấm Chấp nhận
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: OrbitColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_read_rounded, color: Color(0xFFFFD54F), size: 28),
              SizedBox(width: 10),
              Text(
                'Đã Gửi Lời Mời! 💌',
                style: TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Lời mời kết bạn đã được gửi đến "$name".\n\nKhi "$name" mở ứng dụng Orbit và bấm "Chấp nhận", cả hai sẽ lập tức cùng xuất hiện trên vòng tròn quỹ đạo của nhau!',
            style: TextStyle(color: OrbitColors.deepOlive.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OrbitColors.buttonPrimary,
                foregroundColor: OrbitColors.textLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text('Tuyệt vời', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    _showSnackbar('Không thể gửi lời mời kết bạn. Vui lòng kiểm tra kết nối mạng.');
  }

  Future<void> _processAccountBackup(String rawJson, Map<String, dynamic> data) async {
    final uid = data['uid'] as String? ?? '';
    final name = data['name'] as String? ?? 'Tài khoản cũ';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff2d2c38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: Color(0xffFCB600), size: 28),
            SizedBox(width: 10),
            Text('Khôi Phục Tài Khoản', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Tìm thấy tài khoản: "$name" ($uid).\n\nBạn có muốn đăng nhập vào tài khoản này trên thiết bị này không?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffFCB600),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng Nhập', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await AuthService.instance.restoreFromBackupPayload(rawJson);
      if (success) {
        await FriendService.instance.syncFriendsFromFirestore();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã khôi phục tài khoản "$name" thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        _showSnackbar('Mã sao lưu không hợp lệ.');
      }
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xff333333),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Quét Mã QR';
    String hint = 'Căn chỉnh mã QR vào khung để quét';
    if (widget.mode == ScannerMode.addFriend) {
      title = 'Quét Mã Kết Bạn';
      hint = 'Căn chỉnh mã kết bạn của người kia vào khung viền';
    } else if (widget.mode == ScannerMode.backupLogin) {
      title = 'Quét Mã Đăng Nhập';
      hint = 'Quét mã khôi phục tài khoản từ thiết bị cũ của bạn';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),

          // Khung ngắm quét mã QR với Animation co giãn ôm mã QR & Hào quang vàng sống động
          Center(
            child: AnimatedBuilder(
              animation: _hugAnimController,
              builder: (context, child) {
                final double currentSize = 260.0 * _boxScaleAnimation.value;
                final double glow = _glowAnimation.value;

                return Container(
                  width: currentSize,
                  height: currentSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24 * _boxScaleAnimation.value),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFFFFD54F),
                        const Color(0xFF66BB6A),
                        glow,
                      )!,
                      width: _isLockedOn ? 3.8 : 2.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color.lerp(
                          const Color(0xFFFFD54F).withValues(alpha: 0.35),
                          const Color(0xFF66BB6A).withValues(alpha: 0.65),
                          glow,
                        )!,
                        blurRadius: 18 * (1.0 + glow),
                        spreadRadius: 2.0 * (1.0 + glow),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 4 góc ngắm quang học (Optical corner brackets)
                      CustomPaint(
                        size: Size(currentSize, currentSize),
                        painter: _ScannerCornersPainter(
                          color: _isLockedOn ? const Color(0xFF66BB6A) : const Color(0xFFFFD54F),
                          bracketLength: 26.0 * _boxScaleAnimation.value,
                          strokeWidth: 4.0,
                        ),
                      ),

                      if (_isProcessing)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isLockedOn ? Icons.lock_rounded : Icons.qr_code_scanner_rounded,
                              color: const Color(0xFFFFD54F),
                              size: 44 * _boxScaleAnimation.value,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _isLockedOn ? 'Đã khóa mã QR...' : 'Đang đọc mã...',
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Hint
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vẽ 4 góc định vị của khung ngắm camera
class _ScannerCornersPainter extends CustomPainter {
  final Color color;
  final double bracketLength;
  final double strokeWidth;

  _ScannerCornersPainter({
    required this.color,
    required this.bracketLength,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), Offset(bracketLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, bracketLength), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - bracketLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, bracketLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(bracketLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - bracketLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - bracketLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - bracketLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornersPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.bracketLength != bracketLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
