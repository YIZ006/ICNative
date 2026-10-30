import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icnative/screens/feed_screen.dart';
import 'package:icnative/screens/friends_screen.dart';
import 'package:icnative/screens/history.dart';
import 'package:icnative/screens/preview.dart';
import 'package:icnative/screens/profile_screen.dart';
import 'package:icnative/services/auth_service.dart';
import 'package:icnative/services/friend_service.dart';
import 'package:icnative/settings/sizes.dart';
import 'package:icnative/settings/theme_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late CameraController controller;
  final ScrollController scrollController = ScrollController();

  bool clicked = false;
  bool _isCapturing = false;
  bool frontCamera = false;
  bool flash = false;
  bool showGrid = false;
  int timerSeconds = 0; // 0 = off, 3 = 3s, 5 = 5s
  int countdownValue = 0;

  double _currentScale = 1.0;
  double _baseScale = 1.0;

  // Selected recipient mode: null = all friends, or specific friend name
  String? selectedRecipientName;

  // 1. Zoom/Mo rong o camera chinh giua (Square expand / Circle collapse)
  bool isLensExpanded = false;

  // 2. Physics & Multi-orbit Rotation Engine
  late Ticker _orbitTicker;
  Duration _lastTickTime = Duration.zero;

  double _angleInner = 0.0;
  double _angleOuter = 0.0;

  // Base ambient rotation speeds (rad/sec)
  static const double _baseSpeedInner = 0.12;  // Cung chieu kim dong ho
  static const double _baseSpeedOuter = -0.09; // Nguoc chieu kim dong ho

  double _velocityInner = _baseSpeedInner;
  double _velocityOuter = _baseSpeedOuter;

  // Touch gesture interaction tracking
  bool _isDragging = false;
  int _activeDragRing = 1; // 1 = inner, 2 = outer
  double _lastTouchAngle = 0.0;
  DateTime _lastTouchTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Khoi tao Camera
    controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    controller.initialize().then((_) async {
      if (!mounted) return;
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      setState(() {});
    }).catchError((Object e) {
      debugPrint("Camera init error: $e");
    });

    // Khoi tao Physics Ticker cho he quy dao quay theo quan tinh
    _orbitTicker = createTicker(_onOrbitTick)..start();
  }

  void _onOrbitTick(Duration elapsed) {
    if (!mounted || isLensExpanded) return;

    if (_lastTickTime == Duration.zero) {
      _lastTickTime = elapsed;
      return;
    }

    final double dt = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    if (dt <= 0 || dt > 0.1) return; // Bo qua frame bat thuong

    if (!_isDragging) {
      // Giam toc theo quan tinh (Friction damping) cho vong trong
      if (_velocityInner.abs() > _baseSpeedInner.abs()) {
        _velocityInner *= math.exp(-2.2 * dt);
        if (_velocityInner.abs() < _baseSpeedInner.abs()) {
          _velocityInner = _baseSpeedInner;
        }
      } else {
        _velocityInner = _baseSpeedInner;
      }

      // Giam toc theo quan tinh cho vong ngoai
      if (_velocityOuter.abs() > _baseSpeedOuter.abs()) {
        _velocityOuter *= math.exp(-2.2 * dt);
        if (_velocityOuter.abs() < _baseSpeedOuter.abs()) {
          _velocityOuter = _baseSpeedOuter;
        }
      } else {
        _velocityOuter = _baseSpeedOuter;
      }

      _angleInner += _velocityInner * dt;
      _angleOuter += _velocityOuter * dt;

      setState(() {});
    }
  }

  @override
  void dispose() {
    _orbitTicker.dispose();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) async {
    // Neu dang o che do mo rong va nguoi dung pinch-in (thu nho < 0.82) -> thu ve ong kinh tron
    if (isLensExpanded && details.scale < 0.82) {
      setState(() => isLensExpanded = false);
      return;
    }

    _currentScale = (_baseScale * details.scale).clamp(1.0, await controller.getMaxZoomLevel());
    setState(() {
      controller.setZoomLevel(_currentScale);
    });
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    if (timerSeconds > 0) {
      setState(() {
        _isCapturing = true;
        countdownValue = timerSeconds;
      });

      for (int i = timerSeconds; i > 0; i--) {
        if (!mounted) return;
        setState(() => countdownValue = i);
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;
      setState(() => countdownValue = 0);
    } else {
      setState(() => _isCapturing = true);
    }

    setState(() => clicked = true);

    try {
      final value = await controller.takePicture();
      if (!mounted) return;

      await showModalBottomSheet(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        context: context,
        builder: (context) => ImagePreview(
          imagePath: value.path,
          onSend: () {
            setState(() {});
          },
        ),
      );
    } catch (e) {
      debugPrint("Capture error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          clicked = false;
          countdownValue = 0;
        });
      }
    }
  }

  void _toggleTimer() {
    setState(() {
      if (timerSeconds == 0) {
        timerSeconds = 3;
      } else if (timerSeconds == 3) {
        timerSeconds = 5;
      } else {
        timerSeconds = 0;
      }
    });
  }

  void changeCamera() {
    controller = CameraController(
      cameras[frontCamera ? 0 : 1],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        frontCamera = !frontCamera;
      });
    }).catchError((Object e) {
      debugPrint("Change camera error: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = Sizes.width(context);
    final screenH = Sizes.height(context);

    return Scaffold(
      backgroundColor: OrbitColors.background,
      body: SafeArea(
        child: SizedBox(
          width: screenW,
          height: screenH,
          child: Stack(
            children: [
              // LAYER 1: Scrollable View (Camera Page + Pull-up History)
              SingleChildScrollView(
                controller: scrollController,
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // SCREEN 1: Camera Page with strict viewport constraint
                    GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! < -250) {
                          scrollController.animateTo(
                            scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: SizedBox(
                        width: screenW,
                        height: screenH - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 1. Top Bar (Cao 50dp)
                                _buildTopBar(),

                                // 2. Central Area (Flexible Expanded - Khong bao gio tran man hinh)
                                Expanded(
                                  child: _buildCentralLensAndOrbits(
                                    availW: constraints.maxWidth,
                                    availH: constraints.maxHeight - 50 - 150,
                                  ),
                                ),

                                // 3. Bottom Controls Area (Cao 148dp, cach thanh dieu huong an toan)
                                _buildBottomControls(),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // SCREEN 2: History Screen (Pull up from bottom)
                    GestureDetector(
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
                          scrollController.animateTo(
                            scrollController.position.minScrollExtent,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      child: SizedBox(
                        width: screenW,
                        height: screenH - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                        child: HistoryScreen(
                          onBackToCamera: () {
                            scrollController.animateTo(
                              scrollController.position.minScrollExtent,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TOP APP BAR (Khong hardcode demo)
  // ==========================================
  Widget _buildTopBar() {
    final friendsCount = FriendService.instance.friends.length;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Profile Badge with Custom Avatar Support
          ValueListenableBuilder<UserProfile?>(
            valueListenable: AuthService.instance.currentUserNotifier,
            builder: (context, user, _) {
              final avatarPath = user?.avatarPath;
              final hasCustomAvatar = avatarPath != null && File(avatarPath).existsSync();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const ProfileScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: OrbitColors.buttonPrimary,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: OrbitColors.deepOlive.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: OrbitColors.background,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: hasCustomAvatar
                              ? Image.file(
                                  File(avatarPath),
                                  fit: BoxFit.cover,
                                  width: 22,
                                  height: 22,
                                )
                              : const Center(
                                  child: Text('🐾', style: TextStyle(fontSize: 10)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user?.displayName ?? 'Tôi',
                        style: const TextStyle(
                          color: OrbitColors.textLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Friends Hub Pill
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const FriendsScreen()),
              );
            },
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: OrbitColors.buttonPrimary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OrbitColors.deepOlive.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: OrbitColors.textLight,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    friendsCount > 0 ? "Bạn bè ($friendsCount)" : "Kết bạn",
                    style: const TextStyle(
                      color: OrbitColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Feed Button (Khong fake badge thong bao)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const FriendsFeedScreen()),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OrbitColors.buttonPrimary,
                border: Border.all(color: OrbitColors.deepOlive.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                color: OrbitColors.textLight,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CENTRAL AREA: ORBITS & CAMERA LENS
  // ==========================================
  Widget _buildCentralLensAndOrbits({required double availW, required double availH}) {
    final double maxDimension = math.min(availW, availH);

    // Kich thuoc dong cua ong kinh tron & ban kinh quy dao
    final double lensDiameter = (maxDimension * 0.44).clamp(160.0, 210.0);
    final double rInner = lensDiameter / 2 + 40;
    final double rOuter = lensDiameter / 2 + 82;

    // Danh sach ban be that
    final friends = FriendService.instance.friends;

    // Phan chia ban be vao cac quy dao (Moi vong 4-5 nguoi nhu he mat troi)
    final List<_SatelliteItem> innerSatellites = [];
    final List<_SatelliteItem> outerSatellites = [];

    if (friends.isEmpty) {
      // Chua co ban be: 1 ve tinh nut [+] them ban duy nhat
      innerSatellites.add(_SatelliteItem(
        id: 'add_friend',
        name: 'Thêm',
        initial: '+',
        isAddButton: true,
      ));
    } else {
      // Chia ban be: 4 nguoi dau vao vong trong
      for (int i = 0; i < friends.length && i < 4; i++) {
        final f = friends[i];
        final initial = f.displayName.isNotEmpty ? f.displayName.substring(0, 1).toUpperCase() : '?';
        innerSatellites.add(_SatelliteItem(
          id: f.uid,
          name: f.displayName,
          initial: initial,
        ));
      }

      // Neu con cho trong vong 1 va duoi 4 ban: them nut [+] vao vong 1
      if (friends.length < 4) {
        innerSatellites.add(_SatelliteItem(
          id: 'add_friend',
          name: 'Thêm',
          initial: '+',
          isAddButton: true,
        ));
      } else {
        // Tu ban be thu 5 tro di -> Dua vao vong ngoai (Outer orbit)
        for (int i = 4; i < friends.length && i < 8; i++) {
          final f = friends[i];
          final initial = f.displayName.isNotEmpty ? f.displayName.substring(0, 1).toUpperCase() : '?';
          outerSatellites.add(_SatelliteItem(
            id: f.uid,
            name: f.displayName,
            initial: initial,
          ));
        }
        // Nut [+] nam o vong ngoai
        outerSatellites.add(_SatelliteItem(
          id: 'add_friend',
          name: 'Thêm',
          initial: '+',
          isAddButton: true,
        ));
      }
    }

    final bool hasOuterOrbit = outerSatellites.isNotEmpty;
    final double totalContainerSize = hasOuterOrbit ? (rOuter * 2 + 70) : (rInner * 2 + 70);

    return Center(
      child: isLensExpanded
          ? _buildExpandedSquareViewfinder(availW, availH)
          : GestureDetector(
              onPanStart: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(details.globalPosition);
                // Tinh tam khu vuc quay
                final cx = availW / 2;
                final cy = availH / 2;
                final dx = local.dx - cx;
                final dy = local.dy - cy;
                final dist = math.sqrt(dx * dx + dy * dy);

                _isDragging = true;
                _activeDragRing = (dist > rInner + 20 && hasOuterOrbit) ? 2 : 1;
                _lastTouchAngle = math.atan2(local.dy - cy, local.dx - cx);
                _lastTouchTime = DateTime.now();
              },
              onPanUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final local = box.globalToLocal(details.globalPosition);
                final cx = availW / 2;
                final cy = availH / 2;

                final currentAngle = math.atan2(local.dy - cy, local.dx - cx);
                double delta = currentAngle - _lastTouchAngle;
                // Chuẩn hóa góc quay (-pi .. pi)
                if (delta > math.pi) delta -= 2 * math.pi;
                if (delta < -math.pi) delta += 2 * math.pi;

                final now = DateTime.now();
                final dt = (now.difference(_lastTouchTime).inMicroseconds) / 1000000.0;

                if (_activeDragRing == 1) {
                  _angleInner += delta;
                  if (dt > 0.005) {
                    _velocityInner = (delta / dt).clamp(-12.0, 12.0);
                  }
                } else {
                  _angleOuter += delta;
                  if (dt > 0.005) {
                    _velocityOuter = (delta / dt).clamp(-12.0, 12.0);
                  }
                }

                _lastTouchAngle = currentAngle;
                _lastTouchTime = now;
                setState(() {});
              },
              onPanEnd: (details) {
                _isDragging = false;
              },
              child: SizedBox(
                width: math.min(availW, totalContainerSize),
                height: math.min(availH, totalContainerSize),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer Orbit Ring (Neu co > 4 ban be)
                    if (hasOuterOrbit) ...[
                      CustomPaint(
                        size: Size(rOuter * 2, rOuter * 2),
                        painter: _DashedOrbitPainter(
                          color: OrbitColors.buttonPrimary.withValues(alpha: 0.28),
                          strokeWidth: 1.5,
                          dashCount: 40,
                        ),
                      ),
                      ..._buildSatellitesOnRing(
                        satellites: outerSatellites,
                        radius: rOuter,
                        baseAngle: _angleOuter,
                        centerSize: math.min(availW, totalContainerSize),
                      ),
                    ],

                    // Inner Orbit Ring
                    CustomPaint(
                      size: Size(rInner * 2, rInner * 2),
                      painter: _DashedOrbitPainter(
                        color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                        strokeWidth: 2.0,
                        dashCount: 32,
                      ),
                    ),
                    ..._buildSatellitesOnRing(
                      satellites: innerSatellites,
                      radius: rInner,
                      baseAngle: _angleInner,
                      centerSize: math.min(availW, totalContainerSize),
                    ),

                    // THE CIRCULAR CAMERA LENS AT CENTER
                    GestureDetector(
                      onTap: () {
                        // Bấm vào cam ở chính giữa thì mở rộng ra ô cam vuông to
                        setState(() => isLensExpanded = true);
                      },
                      onDoubleTap: () => changeCamera(),
                      onScaleUpdate: _onScaleUpdate,
                      onScaleStart: _onScaleStart,
                      child: Container(
                        width: lensDiameter,
                        height: lensDiameter,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OrbitColors.buttonPrimary,
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: OrbitColors.deepOlive.withValues(alpha: 0.25),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildCameraStreamView(),

                              // 3x3 Grid Overlay
                              if (showGrid)
                                CustomPaint(painter: _GridPainter()),

                              // Countdown Overlay
                              if (countdownValue > 0)
                                _buildCountdownOverlay(),

                              // Zoom pill
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: OrbitColors.deepOlive.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: OrbitColors.buttonPrimary, width: 0.8),
                                    ),
                                    child: Text(
                                      '${_currentScale.toStringAsFixed(1)}x • Chạm để phóng to',
                                      style: const TextStyle(
                                        color: OrbitColors.textLight,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Target Recipient Badge (Dưới ống kính)
                    Positioned(
                      bottom: (math.min(availH, totalContainerSize) - lensDiameter) / 4 - 10,
                      child: GestureDetector(
                        onTap: () {
                          if (friends.isEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => const FriendsScreen()),
                            );
                          } else {
                            setState(() => selectedRecipientName = null);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: OrbitColors.buttonPrimary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: OrbitColors.deepOlive.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: OrbitColors.textLight,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                friends.isEmpty
                                    ? 'Nhấn "+" trên quỹ đạo để thêm bạn bè'
                                    : (selectedRecipientName != null
                                        ? 'Gửi riêng: $selectedRecipientName ✕'
                                        : 'Gửi tới: Tất cả bạn bè (${friends.length}) ▾'),
                                style: const TextStyle(
                                  color: OrbitColors.textLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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

  // ==========================================
  // VIEW Ô CAM VUÔNG TO KHI ĐƯỢC MỞ RỘNG
  // ==========================================
  Widget _buildExpandedSquareViewfinder(double availW, double availH) {
    final double boxSize = (math.min(availW - 28, availH - 20)).clamp(220.0, 380.0);

    return Center(
      child: GestureDetector(
        onDoubleTap: () => changeCamera(),
        onScaleUpdate: _onScaleUpdate,
        onScaleStart: _onScaleStart,
        child: Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: OrbitColors.buttonPrimary, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCameraStreamView(),

                if (showGrid)
                  CustomPaint(painter: _GridPainter()),

                if (countdownValue > 0)
                  _buildCountdownOverlay(),

                // Nut thu nho ve kieu quy dao tron
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => isLensExpanded = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: OrbitColors.buttonPrimary, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.compress_rounded, color: OrbitColors.textLight, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Quỹ đạo tròn',
                            style: TextStyle(color: OrbitColors.textLight, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Hint
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${_currentScale.toStringAsFixed(1)}x • Chụm ngón tay để thu nhỏ',
                        style: const TextStyle(color: OrbitColors.textLight, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraStreamView() {
    if (controller.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      );
    } else {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: OrbitColors.buttonPrimary),
        ),
      );
    }
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Text(
          '$countdownValue',
          style: const TextStyle(
            color: OrbitColors.khakiGold,
            fontSize: 84,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black,
                blurRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TINH TOAN TOA DO VE TINH QUY DAO
  // ==========================================
  List<Widget> _buildSatellitesOnRing({
    required List<_SatelliteItem> satellites,
    required double radius,
    required double baseAngle,
    required double centerSize,
  }) {
    final List<Widget> widgets = [];
    final int count = satellites.length;
    if (count == 0) return widgets;

    final double step = (2 * math.pi) / count;

    for (int i = 0; i < count; i++) {
      final item = satellites[i];
      final angle = baseAngle + (i * step);

      // Tinh toa do tam cua ve tinh (x, y)
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);

      widgets.add(
        Transform.translate(
          offset: Offset(x, y),
          child: _buildSatelliteWidget(item),
        ),
      );
    }
    return widgets;
  }

  Widget _buildSatelliteWidget(_SatelliteItem item) {
    final bool isSelected = selectedRecipientName == item.name;

    return GestureDetector(
      onTap: () {
        if (item.isAddButton) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const FriendsScreen()),
          );
        } else {
          setState(() {
            selectedRecipientName = isSelected ? null : item.name;
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isAddButton ? OrbitColors.surfaceCard : OrbitColors.buttonPrimary,
              border: Border.all(
                color: isSelected
                    ? OrbitColors.terracotta
                    : (item.isAddButton ? OrbitColors.buttonPrimary : OrbitColors.background),
                width: isSelected ? 3.0 : 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                item.initial,
                style: TextStyle(
                  color: item.isAddButton ? OrbitColors.buttonPrimary : OrbitColors.textLight,
                  fontWeight: FontWeight.bold,
                  fontSize: item.isAddButton ? 20 : 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: isSelected ? OrbitColors.terracotta : OrbitColors.buttonPrimary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              item.name,
              style: const TextStyle(
                color: OrbitColors.textLight,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM CONTROLS (Chuan kich thuoc khong bi de)
  // ==========================================
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Utilities Bar (Flash, Timer, Grid, Flip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: OrbitColors.buttonPrimary,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: OrbitColors.deepOlive.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flash Button
                GestureDetector(
                  onTap: () async {
                    await controller.setFlashMode(flash ? FlashMode.off : FlashMode.torch);
                    setState(() => flash = !flash);
                  },
                  child: Row(
                    children: [
                      Icon(
                        flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        size: 15,
                        color: flash ? OrbitColors.khakiGold : OrbitColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        flash ? "Bật" : "Tắt",
                        style: const TextStyle(color: OrbitColors.textLight, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                _buildDivider(),

                // Timer Button
                GestureDetector(
                  onTap: _toggleTimer,
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        size: 15,
                        color: timerSeconds > 0 ? OrbitColors.khakiGold : OrbitColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timerSeconds == 0 ? "Hẹn giờ" : "${timerSeconds}s",
                        style: TextStyle(
                          color: timerSeconds > 0 ? OrbitColors.khakiGold : OrbitColors.textLight,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildDivider(),

                // Grid Button
                GestureDetector(
                  onTap: () => setState(() => showGrid = !showGrid),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_on_rounded,
                        size: 15,
                        color: showGrid ? OrbitColors.khakiGold : OrbitColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        showGrid ? "Lưới" : "Lưới",
                        style: TextStyle(
                          color: showGrid ? OrbitColors.khakiGold : OrbitColors.textLight,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                _buildDivider(),

                // Flip Camera Button
                GestureDetector(
                  onTap: changeCamera,
                  child: const Row(
                    children: [
                      Icon(Icons.flip_camera_ios_rounded, size: 15, color: OrbitColors.textLight),
                      SizedBox(width: 4),
                      Text("Đổi", style: TextStyle(color: OrbitColors.textLight, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Big Tactile Shutter Button (Hoan toan nam tren thanh dieu huong Android)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _capturePhoto,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OrbitColors.background,
                border: Border.all(
                  color: OrbitColors.buttonPrimary,
                  width: 4.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: OrbitColors.deepOlive,
                ),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: clicked ? 14 : 20,
                    height: clicked ? 14 : 20,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: OrbitColors.background,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Pull-up History Hint
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_up_rounded, color: OrbitColors.deepOlive, size: 18),
                  SizedBox(width: 4),
                  Text(
                    "Vuốt lên xem ảnh kỷ niệm",
                    style: TextStyle(
                      color: OrbitColors.deepOlive,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 13,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: OrbitColors.textLight.withValues(alpha: 0.3),
    );
  }
}

class _SatelliteItem {
  final String id;
  final String name;
  final String initial;
  final bool isAddButton;

  _SatelliteItem({
    required this.id,
    required this.name,
    required this.initial,
    this.isAddButton = false,
  });
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    final dx1 = size.width / 3;
    final dx2 = (size.width / 3) * 2;
    canvas.drawLine(Offset(dx1, 0), Offset(dx1, size.height), paint);
    canvas.drawLine(Offset(dx2, 0), Offset(dx2, size.height), paint);

    final dy1 = size.height / 3;
    final dy2 = (size.height / 3) * 2;
    canvas.drawLine(Offset(0, dy1), Offset(size.width, dy1), paint);
    canvas.drawLine(Offset(0, dy2), Offset(size.width, dy2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedOrbitPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedOrbitPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final double dashAngle = (2 * math.pi) / dashCount;
    const double drawFraction = 0.52;
    final double sweepAngle = dashAngle * drawFraction;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
