import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/secret_photo_service.dart';

class ScratchPhotoScreen extends StatefulWidget {
  final SecretPhoto secretPhoto;

  const ScratchPhotoScreen({
    super.key,
    required this.secretPhoto,
  });

  @override
  State<ScratchPhotoScreen> createState() => _ScratchPhotoScreenState();
}

class _ScratchPhotoScreenState extends State<ScratchPhotoScreen> {
  static const _scratchChannel = MethodChannel('com.abom.utas.utas/scratch_sfx');

  final List<Offset?> _points = [];
  double _scratchProgress = 0.0;
  bool _thresholdReached = false;
  bool _milestone10 = false;
  bool _milestone25 = false;
  Offset? _lastSoundPoint;
  DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  final Set<String> _scratchedCells = {};
  static const int _gridResolution = 20; // 20x20 grid = 400 cells

  String get _cleanSenderName {
    final raw = widget.secretPhoto.senderName;
    return raw.replaceAll(RegExp(r'\s*#\d+.*$'), '').trim();
  }

  void _playScratchSfx() {
    try {
      _scratchChannel.invokeMethod('playScratch');
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
    HapticFeedback.selectionClick();
  }

  void _addPoint(Offset localPosition, Size size) {
    final now = DateTime.now();
    // Kích hoạt âm thanh ma sát thẻ cào thật và rung nhẹ: Cooldown 80ms và khoảng cách >= 26px
    // Ngăn chặn hoàn toàn hiện tượng lặp tần số cao gây cảm giác ù rè như điện giật
    if (_lastSoundPoint == null ||
        ((localPosition - _lastSoundPoint!).distance >= 26.0 &&
            now.difference(_lastSoundTime).inMilliseconds >= 80)) {
      _lastSoundPoint = localPosition;
      _lastSoundTime = now;
      _playScratchSfx();
    }

    setState(() {
      _points.add(localPosition);

      // Tính toán vùng cào dựa trên lưới grid để đo chính xác diện tích cào
      if (size.width > 0 && size.height > 0) {
        final cellX = (localPosition.dx / (size.width / _gridResolution)).floor().clamp(0, _gridResolution - 1);
        final cellY = (localPosition.dy / (size.height / _gridResolution)).floor().clamp(0, _gridResolution - 1);

        // Bán kính cào (brush size ~38px)
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            final nx = (cellX + dx).clamp(0, _gridResolution - 1);
            final ny = (cellY + dy).clamp(0, _gridResolution - 1);
            _scratchedCells.add('$nx,$ny');
          }
        }

        const totalCells = _gridResolution * _gridResolution;
        _scratchProgress = (_scratchedCells.length / totalCells).clamp(0.0, 1.0);

        if (_scratchProgress >= 0.10 && !_milestone10) {
          _milestone10 = true;
          HapticFeedback.lightImpact();
        }

        if (_scratchProgress >= 0.25 && !_milestone25) {
          _milestone25 = true;
          HapticFeedback.mediumImpact();
        }

        if (_scratchProgress >= 0.35 && !_thresholdReached) {
          _thresholdReached = true;
          HapticFeedback.heavyImpact();
          SecretPhotoService.instance.markAsRevealed(widget.secretPhoto.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cleanName = _cleanSenderName;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Bức ảnh bí mật 🤫',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sender Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    _buildSenderAvatar(cleanName),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.secretPhoto.teaserMessage,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _scratchProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _scratchProgress >= 0.35 ? const Color(0xFF00FF66) : const Color(0xFF00F0FF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(_scratchProgress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Scratch Area
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(constraints.maxWidth, constraints.maxHeight);
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Ảnh bên dưới (Underlying Photo)
                              _buildPhotoUnderneath(cleanName),

                              // 2. Lớp cào tráng bạc (Scratch Overlay)
                              GestureDetector(
                                onPanStart: (details) => _addPoint(details.localPosition, size),
                                onPanUpdate: (details) => _addPoint(details.localPosition, size),
                                onPanEnd: (_) {
                                  _lastSoundPoint = null;
                                  setState(() => _points.add(null));
                                },
                                child: CustomPaint(
                                  painter: _ScratchPainter(points: _points),
                                  size: Size.infinite,
                                ),
                              ),

                              // Hướng dẫn nếu chưa cào
                              if (_points.isEmpty)
                                IgnorePointer(
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(color: Colors.white30),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.touch_app, color: Colors.amber, size: 22),
                                          SizedBox(width: 8),
                                          Text(
                                            'Dùng ngón tay cào lớp bạc 🤫',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Viral Teaser Popup / Banner khi cào đạt 35%
            if (_thresholdReached)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF00FF66), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF66).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Text('🎉', style: TextStyle(fontSize: 26)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Đã hé lộ bức ảnh! Tò mò chưa?',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Chụp 1 tấm ảnh đáp trả lại ngay lên màn hình chính (Widget) của $cleanName nhé!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.camera_alt, color: Colors.black),
                              label: const Text(
                                'Chụp ảnh đáp trả 📸',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FF66),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Cào màn hình để khám phá bức ảnh ẩn bên dưới',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(String cleanName) {
    // 1. Thử lấy avatar từ user hiện tại nếu tự xem lại ảnh của mình
    final currentUser = AuthService.instance.currentUser;
    if (currentUser != null && currentUser.avatarPath != null && currentUser.avatarPath!.isNotEmpty) {
      final file = File(currentUser.avatarPath!);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(file, width: 44, height: 44, fit: BoxFit.cover),
        );
      }
    }

    // 2. Fallback: Avatar chữ cái đầu với gradient ngân hà
    final initial = cleanName.isNotEmpty ? cleanName.substring(0, 1).toUpperCase() : 'O';
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF00F0FF), Color(0xFF7000FF)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildPhotoUnderneath(String cleanName) {
    final file = File(widget.secretPhoto.imagePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    // Fallback UI nếu ảnh demo
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFff9966), Color(0xFFff5e62)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 70, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              'Bức ảnh từ $cleanName',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScratchPainter extends CustomPainter {
  final List<Offset?> points;

  _ScratchPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Vẽ lớp tráng bạc kim loại (Silver Scratch Foil)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const gradient = LinearGradient(
      colors: [
        Color(0xFFB0B0B8),
        Color(0xFFDCDCE0),
        Color(0xFF909098),
        Color(0xFFE8E8EC),
        Color(0xFFA0A0A8),
      ],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(math.pi / 4),
    );

    final bgPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Vẽ hoạ tiết hạt kim loại / holographic pattern
    final patternPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = -size.width; i < size.width * 2; i += 24) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), patternPaint);
    }

    // 2. Xóa các vệt cào bằng BlendMode.clear
    final scratchPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 42.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, scratchPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScratchPainter oldDelegate) {
    return oldDelegate.points.length != points.length;
  }
}
