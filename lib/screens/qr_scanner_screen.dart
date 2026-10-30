import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';

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

class _QRScannerScreenState extends State<QRScannerScreen> {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _isProcessing = true);

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
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processAddFriend(Map<String, dynamic> data) async {
    final uid = data['uid'] as String? ?? '';
    final name = data['name'] as String? ?? 'Bạn bè';

    final myUid = AuthService.instance.currentUser?.uid;
    if (uid == myUid) {
      _showSnackbar('Đây là mã kết bạn của chính bạn!');
      await Future.delayed(const Duration(seconds: 2));
      return;
    }

    final success = await FriendService.instance.addFriendFromQr(uid, name);

    if (mounted) {
      if (success) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xff2d2c38),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xffFCB600), size: 28),
                SizedBox(width: 10),
                Text('Kết Bạn Thành Công!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Đã kết nối với "$name". Bây giờ cả 2 có thể gửi ảnh lên Widget màn hình chính của nhau!',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Tuyệt vời', style: TextStyle(color: Color(0xffFCB600), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        _showSnackbar('Không thể thêm bạn bè. Vui lòng thử lại.');
      }
    }
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
      hint = 'Quét mã kết bạn của người khác để liên kết widget';
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

          // Transparent overlay with rounded scan cutout
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xffFCB600), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  if (_isProcessing)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xffFCB600),
                      ),
                    ),
                ],
              ),
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
