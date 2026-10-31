import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:icnative/screens/feed_screen.dart';
import 'package:icnative/screens/friends_screen.dart';
import 'package:icnative/screens/history.dart';
import 'package:icnative/screens/preview.dart';
import 'package:icnative/screens/profile_screen.dart';
import 'package:icnative/screens/update_dialog.dart';
import 'package:icnative/screens/widget_guide_screen.dart';
import 'package:icnative/services/auth_service.dart';
import 'package:icnative/services/demo_data_service.dart';
import 'package:icnative/services/friend_service.dart';
import 'package:icnative/services/locale_service.dart';
import 'package:icnative/services/update_service.dart';
import 'package:icnative/settings/global.dart';
import 'package:icnative/settings/sizes.dart';
import 'package:icnative/settings/theme_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  CameraController? controller;
  bool _isCameraInitializing = false;
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

  // Ultra-smooth Viewfinder Morph Engine (Tron -> Vuong -> Tron)
  late AnimationController _morphController;
  late Animation<double> _morphAnimation;

  // Chế độ Trải Nghiệm Mẫu (Demo Showcase Mode)
  bool get _isDemoMode => isDemoModeNotifier.value;
  void _onDemoModeChanged() {
    if (!mounted) return;
    if (_isDemoMode) {
      _startDemoReactions();
    } else {
      _demoReactionTimer?.cancel();
      _friendReactions.clear();
    }
    setState(() {});
  }

  void _startDemoReactions() {
    _demoReactionTimer?.cancel();
    _demoReactionTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !_isDemoMode) {
        timer.cancel();
        return;
      }
      final demoFriends = DemoDataService.instance.demoFriends;
      if (demoFriends.isEmpty) return;
      final randomFriend = demoFriends[math.Random().nextInt(demoFriends.length)];
      final emojis = ['❤️', '🔥', '✨', '😍', '👏'];
      final randomEmoji = emojis[math.Random().nextInt(emojis.length)];
      _triggerReaction(randomFriend.uid, randomEmoji);
    });
  }

  // 2. Physics & Multi-orbit Rotation Engine (Thiết kế tinh gọn, thoáng đãng, dễ nhìn)
  late Ticker _orbitTicker;
  Duration _lastTickTime = Duration.zero;

  double _angleInner = 0.0;
  double _angleOuter = 0.0;

  // Base ambient rotation speeds (rad/sec)
  static const double _baseSpeedInner = 0.12;  // Cùng chiều kim đồng hồ
  static const double _baseSpeedOuter = -0.09; // Ngược chiều kim đồng hồ

  double _velocityInner = _baseSpeedInner;
  double _velocityOuter = _baseSpeedOuter;

  // Touch gesture interaction tracking
  bool _isDragging = false;
  int _activeDragRing = 1; // 1 = inner, 2 = outer
  double _lastTouchAngle = 0.0;
  DateTime _lastTouchTime = DateTime.now();

  // 3. 2D Elastic Universe Panning & Spring-Back Engine
  // Cho phép vuốt sang trái/phải/lên/xuống/chéo để nhìn sang vùng bên cạnh, thả tay tự đàn hồi về giữa
  Offset _universePanOffset = Offset.zero;
  late AnimationController _springController;
  Animation<Offset>? _springAnimation;

  // Cached zoom range and smooth orbit notifier
  double _maxZoomLevel = 5.0;
  double _dragStartY = 0.0;
  double _startScrollOffset = 0.0;
  final ValueNotifier<double> _orbitNotifier = ValueNotifier<double>(0.0);

  // Floating Reaction Tracking (Friend UID -> List of active reaction items)
  final Map<String, List<_FloatingReactionItem>> _friendReactions = {};
  Timer? _demoReactionTimer;

  void _triggerReaction(String friendId, String emoji) {
    if (!mounted) return;
    setState(() {
      final list = _friendReactions.putIfAbsent(friendId, () => []);
      list.add(_FloatingReactionItem(
        id: '${DateTime.now().microsecondsSinceEpoch}_${list.length}',
        emoji: emoji,
      ));
    });
  }

  void _removeReaction(String friendId, String reactionId) {
    if (!mounted) return;
    setState(() {
      _friendReactions[friendId]?.removeWhere((r) => r.id == reactionId);
      if (_friendReactions[friendId]?.isEmpty ?? false) {
        _friendReactions.remove(friendId);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    isDemoModeNotifier.addListener(_onDemoModeChanged);

    // Khoi tao Camera an toan (Non-blocking, zero wait, khong bao gio gay trang man hinh)
    _initCameraSafe();

    // Khoi tao Elastic Spring Controller cho hieu ung dan hoi vu tru
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _springController.addListener(() {
      if (_springAnimation != null) {
        _universePanOffset = _springAnimation!.value;
        _orbitNotifier.value = _angleInner;
      }
    });

    // Khoi tao Morph Controller cho hieu ung thu phong cuc muot giua tron va vuong
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOutCubic,
    );
    _morphController.addListener(() {
      _orbitNotifier.value = _angleInner;
      setState(() {});
    });

    // Khoi tao Physics Ticker cho he quy dao quay theo quan tinh
    _orbitTicker = createTicker(_onOrbitTick)..start();

    // Tự động kiểm tra bản cập nhật mới trên GitHub sau khi khởi động app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
    });

    if (_isDemoMode) {
      _startDemoReactions();
    }
  }

  Future<void> _checkAutoUpdate() async {
    try {
      await Future.delayed(const Duration(milliseconds: 2500));
      if (!mounted) return;
      final release = await UpdateService.instance.checkForUpdate(isManual: false);
      if (release != null && mounted) {
        UpdateDialog.show(context, release);
      }
    } catch (e) {
      debugPrint('Auto update check error: $e');
    }
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
      // Giam toc theo quan tinh sang trong (Luxurious damping factor 1.15)
      if (_velocityInner.abs() > _baseSpeedInner.abs()) {
        _velocityInner *= math.exp(-1.15 * dt);
        if (_velocityInner.abs() < _baseSpeedInner.abs()) {
          _velocityInner = _baseSpeedInner;
        }
      } else {
        _velocityInner = _baseSpeedInner;
      }

      if (_velocityOuter.abs() > _baseSpeedOuter.abs()) {
        _velocityOuter *= math.exp(-1.15 * dt);
        if (_velocityOuter.abs() < _baseSpeedOuter.abs()) {
          _velocityOuter = _baseSpeedOuter;
        }
      } else {
        _velocityOuter = _baseSpeedOuter;
      }

      _angleInner += _velocityInner * dt;
      _angleOuter += _velocityOuter * dt;

      // Chi cap nhat notifier cho orbit stack, khong rebuild ca HomeScreen tai 120Hz
      _orbitNotifier.value = _angleInner;
    }
  }

  Future<void> _initCameraSafe() async {
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;

    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras().timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => <CameraDescription>[],
        );
      } catch (e) {
        debugPrint('Camera discovery timeout or error: $e');
      }
    }

    if (cameras.isNotEmpty && mounted) {
      final cam = cameras.firstWhere(
        (c) => frontCamera
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras[0],
      );

      final newController = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      try {
        await newController.initialize();
        if (!mounted) {
          await newController.dispose();
          return;
        }
        try {
          await newController.setFocusMode(FocusMode.auto);
          await newController.setExposureMode(ExposureMode.auto);
          _maxZoomLevel = await newController.getMaxZoomLevel();
        } catch (_) {}
        setState(() {
          controller = newController;
        });
      } catch (e) {
        debugPrint("Camera initialize error: $e");
      }
    }
    _isCameraInitializing = false;
  }

  @override
  void dispose() {
    isDemoModeNotifier.removeListener(_onDemoModeChanged);
    _demoReactionTimer?.cancel();
    _orbitTicker.dispose();
    _springController.dispose();
    _morphController.dispose();
    _orbitNotifier.dispose();
    controller?.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void _openExpandedLens() {
    setState(() => isLensExpanded = true);
    _morphController.forward();
  }

  void _closeExpandedLens() {
    _morphController.reverse().then((_) {
      if (mounted) {
        setState(() {
          isLensExpanded = false;
          _currentScale = 1.0;
          controller?.setZoomLevel(1.0);
        });
      }
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (controller == null || !controller!.value.isInitialized) return;

    if (details.pointerCount >= 2) {
      final double targetScale = (_baseScale * details.scale).clamp(1.0, _maxZoomLevel);

      // Chế độ thu nhỏ về quỹ đạo tròn (Hiệu ứng thu phóng cực mượt):
      if (isLensExpanded && _currentScale <= 1.05 && details.scale < 0.86) {
        _closeExpandedLens();
        return;
      }

      // Zoom camera thong thuong
      if ((targetScale - _currentScale).abs() > 0.01) {
        _currentScale = targetScale;
        controller?.setZoomLevel(_currentScale);
        setState(() {});
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || controller == null || !controller!.value.isInitialized) return;

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
      final value = await controller!.takePicture();
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

  void changeCamera() async {
    if (cameras.length < 2) return;
    frontCamera = !frontCamera;
    await controller?.dispose();
    controller = null;
    setState(() {});
    _initCameraSafe();
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
                    // SCREEN 1: Camera Page with strict viewport constraint & smooth interactive pull-up
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: (details) {
                        if (isLensExpanded) return;
                        _dragStartY = details.globalPosition.dy;
                        _startScrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
                      },
                      onVerticalDragUpdate: (details) {
                        // KHI DANG MO RONG LENS: TUYET DOI KHONG VUOT TRANG ANH
                        if (isLensExpanded || !scrollController.hasClients) return;
                        final delta = _dragStartY - details.globalPosition.dy;
                        if (delta > 0) {
                          final maxScroll = scrollController.position.maxScrollExtent;
                          final target = (_startScrollOffset + delta).clamp(0.0, maxScroll);
                          scrollController.jumpTo(target);
                        }
                      },
                      onVerticalDragEnd: (details) {
                        if (isLensExpanded || !scrollController.hasClients) return;
                        final velocity = details.primaryVelocity ?? 0.0;
                        final maxScroll = scrollController.position.maxScrollExtent;
                        if (velocity < -250 || scrollController.offset > maxScroll * 0.28) {
                          scrollController.animateTo(
                            maxScroll,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          scrollController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
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

                    // SCREEN 2: History Screen (Pull down to return to camera)
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: (details) {
                        _dragStartY = details.globalPosition.dy;
                        _startScrollOffset = scrollController.hasClients ? scrollController.offset : 0.0;
                      },
                      onVerticalDragUpdate: (details) {
                        if (!scrollController.hasClients) return;
                        final delta = _dragStartY - details.globalPosition.dy;
                        final maxScroll = scrollController.position.maxScrollExtent;
                        final target = (_startScrollOffset + delta).clamp(0.0, maxScroll);
                        scrollController.jumpTo(target);
                      },
                      onVerticalDragEnd: (details) {
                        if (!scrollController.hasClients) return;
                        final velocity = details.primaryVelocity ?? 0.0;
                        final maxScroll = scrollController.position.maxScrollExtent;
                        // Độ nhạy cao: Chỉ cần vuốt xuống nhẹ (velocity > 100) hoặc cuộn lên trên 10%
                        if (velocity > 100 || scrollController.offset < maxScroll * 0.90) {
                          scrollController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          scrollController.animateTo(
                            maxScroll,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
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
    final friendsCount = _isDemoMode
        ? DemoDataService.instance.demoFriends.length
        : FriendService.instance.friends.length;

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
                    friendsCount > 0 ? "${tr('friends_title')} ($friendsCount)" : tr('add_friend'),
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

          // 2.5 Quick Widget Setup Guide Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const WidgetGuideScreen()),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OrbitColors.surfaceCream,
                border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.widgets_rounded,
                color: OrbitColors.buttonPrimary,
                size: 18,
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
  // CENTRAL AREA: ORBITS & MORPHING CAMERA LENS
  // ==========================================
  Widget _buildCentralLensAndOrbits({required double availW, required double availH}) {
    final double maxDimension = math.min(availW, availH);

    // Kích thước ống kính tròn & Bán kính quỹ đạo thoáng đãng, dễ nhìn
    final double lensDiameter = (maxDimension * 0.42).clamp(150.0, 195.0);
    final double lensRadius = lensDiameter / 2;
    final double boxSize = (math.min(availW - 28, availH - 20)).clamp(220.0, 380.0);

    // Khoảng cách quỹ đạo thông thoáng, rộng rãi, không bao giờ dày đặc
    final double rInner = lensRadius + 44.0;
    final double rOuter = rInner + 46.0;

    // Tính toán giá trị biến hình cực mượt từ Tròn sang Vuông
    final double morphT = _morphAnimation.value;
    final double currentSize = ui.lerpDouble(lensDiameter, boxSize, morphT)!;
    final double currentRadius = ui.lerpDouble(lensRadius, 28.0, morphT)!;
    final double orbitOpacity = (1.0 - morphT * 1.5).clamp(0.0, 1.0);
    final double expandedControlsOpacity = ((morphT - 0.40) / 0.60).clamp(0.0, 1.0);
    final double badgeOpacity = (1.0 - morphT * 2.0).clamp(0.0, 1.0);

    // Danh sách bạn bè tương ứng theo chế độ
    final List<Friend> friends = _isDemoMode
        ? DemoDataService.instance.demoFriends.map((d) => d.toFriend()).toList()
        : FriendService.instance.friends;

    // Phân bổ tối đa 4-5 người mỗi vòng để giao diện luôn tinh gọn, thanh thoát
    final List<_SatelliteItem> innerSatellites = [];
    final List<_SatelliteItem> outerSatellites = [];

    if (_isDemoMode) {
      // BẢN TRẢI NGHIỆM (DEMO SHOWCASE): Hiển thị bạn bè mẫu phân tầng rõ nét
      final demoFriends = DemoDataService.instance.demoFriends;

      // Tầng 1 (Cận tâm - 3 bạn thân nhất tương tác 24h-48h): Viền vàng hào quang phát sáng
      for (final f in demoFriends.where((d) => d.tier == 1)) {
        innerSatellites.add(_SatelliteItem(
          id: f.uid,
          name: f.displayName,
          initial: f.initial,
          hasGlow: true,
          color: f.avatarColor,
        ));
      }
      innerSatellites.add(_SatelliteItem(
        id: 'add_friend',
        name: 'Thêm',
        initial: '+',
        isAddButton: true,
      ));

      // Tầng 2 & 3 (Tầm trung & Xa): Vòng ngoài
      for (final f in demoFriends.where((d) => d.tier > 1)) {
        outerSatellites.add(_SatelliteItem(
          id: f.uid,
          name: f.displayName,
          initial: f.initial,
          hasGlow: false,
          color: f.avatarColor,
        ));
      }
    } else {
      // BẢN CHUẨN SẠCH (CLEAN RELEASE): Chỉ hiển thị bạn bè thật của người dùng
      final realFriends = friends;

      if (realFriends.isEmpty) {
        // Chưa có bạn bè: Duy nhất 1 nút [+] Thêm bạn ở vòng trong, tuyệt đối không tạo bạn giả
        innerSatellites.add(_SatelliteItem(
          id: 'add_friend',
          name: 'Thêm',
          initial: '+',
          isAddButton: true,
        ));
      } else if (realFriends.length <= 4) {
        // 1-4 bạn: Tất cả nằm trên 1 vòng quỹ đạo duy nhất cùng nút [+]
        for (final f in realFriends) {
          final initial = f.displayName.isNotEmpty ? f.displayName.substring(0, 1).toUpperCase() : '?';
          innerSatellites.add(_SatelliteItem(
            id: f.uid,
            name: f.displayName,
            initial: initial,
          ));
        }
        innerSatellites.add(_SatelliteItem(
          id: 'add_friend',
          name: 'Thêm',
          initial: '+',
          isAddButton: true,
        ));
      } else {
        // Nhiều hơn 4 bạn: 4 bạn đầu vòng trong, các bạn tiếp theo ở vòng ngoài
        for (int i = 0; i < 4; i++) {
          final f = realFriends[i];
          final initial = f.displayName.isNotEmpty ? f.displayName.substring(0, 1).toUpperCase() : '?';
          innerSatellites.add(_SatelliteItem(
            id: f.uid,
            name: f.displayName,
            initial: initial,
          ));
        }
        for (int i = 4; i < math.min(realFriends.length, 8); i++) {
          final f = realFriends[i];
          final initial = f.displayName.isNotEmpty ? f.displayName.substring(0, 1).toUpperCase() : '?';
          outerSatellites.add(_SatelliteItem(
            id: f.uid,
            name: f.displayName,
            initial: initial,
          ));
        }
        outerSatellites.add(_SatelliteItem(
          id: 'add_friend',
          name: 'Thêm',
          initial: '+',
          isAddButton: true,
        ));
      }
    }

    final bool hasOuterOrbit = outerSatellites.isNotEmpty;
    final double totalContainerSize = hasOuterOrbit
        ? (rOuter * 2 + 60.0).clamp(260.0, availW)
        : (rInner * 2 + 60.0).clamp(260.0, availW);

    return Center(
      child: GestureDetector(
        onScaleStart: (details) {
          if (isLensExpanded || morphT > 0.05) return;
          if (_springController.isAnimating) {
            _springController.stop();
          }

          if (details.pointerCount >= 2) {
            // Đặt gốc tỷ lệ thu phóng cho cử chỉ 2 ngón tay
            _baseScale = _currentScale;
          } else {
            // Chạm 1 ngón: Xác định tầng quỹ đạo gần nhất và chuẩn bị xoay / pan đàn hồi
            final RenderBox box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.focalPoint);
            final cx = availW / 2;
            final cy = availH / 2;
            final dx = local.dx - cx;
            final dy = local.dy - cy;
            final dist = math.sqrt(dx * dx + dy * dy);

            _isDragging = true;
            final d1 = (dist - rInner).abs();
            final d2 = hasOuterOrbit ? (dist - rOuter).abs() : double.infinity;
            _activeDragRing = d2 < d1 ? 2 : 1;

            _lastTouchAngle = math.atan2(dy, dx);
            _lastTouchTime = DateTime.now();
          }
        },
        onScaleUpdate: (details) {
          if (isLensExpanded || morphT > 0.05) return;

          if (details.pointerCount >= 2) {
            // CỬ CHỈ 2 NGÓN TAY: Thu phóng Camera ống kính cực mượt (Pinch to Zoom)
            if (controller != null && controller!.value.isInitialized) {
              final double targetScale = (_baseScale * details.scale).clamp(1.0, _maxZoomLevel);
              if ((targetScale - _currentScale).abs() > 0.01) {
                _currentScale = targetScale;
                controller?.setZoomLevel(_currentScale);
                setState(() {});
              }
            }
          } else {
            // CỬ CHỈ 1 NGÓN TAY: 2D Elastic Universe Panning + Xoay vòng quỹ đạo
            final RenderBox box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.focalPoint);
            final cx = availW / 2;
            final cy = availH / 2;

            // 2D Elastic Universe Panning
            final double currentDist = _universePanOffset.distance;
            final double resistance = 1.0 / (1.0 + currentDist / 220.0);
            _universePanOffset += details.focalPointDelta * (0.82 * resistance);

            // Xoay vòng quỹ đạo theo ngón tay
            final currentAngle = math.atan2(local.dy - cy, local.dx - cx);
            double delta = currentAngle - _lastTouchAngle;
            if (delta > math.pi) delta -= 2 * math.pi;
            if (delta < -math.pi) delta += 2 * math.pi;

            final now = DateTime.now();
            final dt = (now.difference(_lastTouchTime).inMicroseconds) / 1000000.0;

            if (_activeDragRing == 1) {
              _angleInner += delta;
              if (dt > 0.003) {
                final instantV = (delta / dt).clamp(-16.0, 16.0);
                _velocityInner = _velocityInner * 0.3 + instantV * 0.7;
              }
            } else {
              _angleOuter += delta;
              if (dt > 0.003) {
                final instantV = (delta / dt).clamp(-16.0, 16.0);
                _velocityOuter = _velocityOuter * 0.3 + instantV * 0.7;
              }
            }

            _lastTouchAngle = currentAngle;
            _lastTouchTime = now;
            _orbitNotifier.value = _angleInner;
          }
        },
        onScaleEnd: (details) {
          if (isLensExpanded || morphT > 0.05) return;
          _isDragging = false;
          // Thả tay ra: Đàn hồi lò xo bật trở về vị trí trung tâm (0, 0)!
          if (_universePanOffset != Offset.zero) {
            _springAnimation = Tween<Offset>(
              begin: _universePanOffset,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _springController,
              curve: Curves.elasticOut,
            ));
            _springController.forward(from: 0.0);
          }
        },
        child: SizedBox(
          width: math.min(availW, totalContainerSize),
          height: math.min(availH, totalContainerSize),
          child: ValueListenableBuilder<double>(
            valueListenable: _orbitNotifier,
            builder: (context, _, __) {
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // LỚP 1: CÁC QUỸ ĐẠO VÀ VỆ TINH BẠN BÈ (Elastic pan + Fade out theo morphT)
                  if (orbitOpacity > 0.01)
                    Opacity(
                      opacity: orbitOpacity,
                      child: Transform.translate(
                        offset: _universePanOffset,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Outer Orbit Ring (Nếu có > 4 bạn bè)
                            if (hasOuterOrbit) ...[
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: Size(rOuter * 2, rOuter * 2),
                                  painter: _DashedOrbitPainter(
                                    color: OrbitColors.buttonPrimary.withValues(alpha: 0.22),
                                    strokeWidth: 1.5,
                                    dashCount: 38,
                                  ),
                                ),
                              ),
                              ..._buildSatellitesOnRing(
                                satellites: outerSatellites,
                                radius: rOuter,
                                baseAngle: _angleOuter,
                                centerSize: math.min(availW, totalContainerSize),
                              ),
                            ],

                            // Inner Orbit Ring (Quỹ đạo chính)
                            RepaintBoundary(
                              child: CustomPaint(
                                size: Size(rInner * 2, rInner * 2),
                                painter: _DashedOrbitPainter(
                                  color: OrbitColors.buttonPrimary.withValues(alpha: 0.32),
                                  strokeWidth: 1.8,
                                  dashCount: 32,
                                ),
                              ),
                            ),
                            ..._buildSatellitesOnRing(
                              satellites: innerSatellites,
                              radius: rInner,
                              baseAngle: _angleInner,
                              centerSize: math.min(availW, totalContainerSize),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // LỚP 2: KHUNG CAMERA BIẾN HÌNH CỰC MƯỢT (TRÒN -> VUÔNG -> TRÒN - RepaintBoundary)
                  Transform.translate(
                    offset: morphT > 0.01 ? Offset.zero : _universePanOffset,
                    child: RepaintBoundary(
                      child: GestureDetector(
                        onTap: () {
                          if (!isLensExpanded) {
                            _openExpandedLens();
                          }
                        },
                        onDoubleTap: () => changeCamera(),
                        onScaleUpdate: _onScaleUpdate,
                        onScaleStart: _onScaleStart,
                      child: Container(
                        width: currentSize,
                        height: currentSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(currentRadius),
                          border: Border.all(
                            color: OrbitColors.buttonPrimary,
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: OrbitColors.deepOlive.withValues(alpha: ui.lerpDouble(0.25, 0.35, morphT)!),
                              blurRadius: ui.lerpDouble(22.0, 28.0, morphT)!,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular((currentRadius - 2.5).clamp(0.0, currentRadius)),
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

                              // Zoom pill tối giản khi ở chế độ tròn
                              if (morphT < 0.25 && _currentScale > 1.05)
                                Positioned(
                                  bottom: 8,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: OrbitColors.buttonPrimary, width: 0.8),
                                      ),
                                      child: Text(
                                        '${_currentScale.toStringAsFixed(1)}x',
                                        style: const TextStyle(
                                          color: OrbitColors.textLight,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                              // Các điều khiển khi phóng to thành ô vuông (Fade-in mượt mà theo morphT)
                              if (expandedControlsOpacity > 0.01)
                                Opacity(
                                  opacity: expandedControlsOpacity,
                                  child: Stack(
                                    children: [
                                      // Nút thu nhỏ về quỹ đạo tròn
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: GestureDetector(
                                          onTap: _closeExpandedLens,
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: OrbitColors.buttonPrimary, width: 1.2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.25),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.fullscreen_exit_rounded, color: OrbitColors.textLight, size: 20),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Floating Zoom Pill (Chạm để chuyển 1x -> 2x)
                                      Positioned(
                                        bottom: 12,
                                        left: 0,
                                        right: 0,
                                        child: Center(
                                          child: GestureDetector(
                                            onTap: () {
                                              final next = _currentScale >= 1.8 ? 1.0 : 2.0;
                                              _currentScale = next;
                                              controller?.setZoomLevel(_currentScale);
                                              setState(() {});
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: OrbitColors.buttonPrimary, width: 1.0),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '${_currentScale.toStringAsFixed(1)}x',
                                                style: const TextStyle(
                                                  color: OrbitColors.textLight,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
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
                    ),
                  ),
                ),

                  // LỚP 3: TARGET RECIPIENT BADGE
                  if (badgeOpacity > 0.01)
                    Positioned(
                      bottom: (math.min(availH, totalContainerSize) - lensDiameter) / 4 - 10,
                      child: Opacity(
                        opacity: badgeOpacity,
                        child: Transform.translate(
                          offset: _universePanOffset,
                          child: _buildRecipientBadge(friends: friends),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientBadge({required List<Friend> friends}) {
    return GestureDetector(
      onTap: () {
        if (selectedRecipientName != null) {
          setState(() => selectedRecipientName = null);
        } else if (friends.isEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const FriendsScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selectedRecipientName != null ? OrbitColors.terracotta : OrbitColors.textLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              selectedRecipientName != null
                  ? 'Gửi tới: $selectedRecipientName ✕'
                  : (_isDemoMode
                      ? 'Bạn bè thân thiết (${friends.length})'
                      : (friends.isEmpty
                          ? 'Nhấn "+" trên quỹ đạo để thêm bạn bè'
                          : 'Tất cả bạn bè (${friends.length})')),
              style: const TextStyle(
                color: OrbitColors.textLight,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraStreamView() {
    if (controller != null && controller!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller!.value.previewSize!.height,
          height: controller!.value.previewSize!.width,
          child: CameraPreview(controller!),
        ),
      );
    } else {
      return Container(
        color: OrbitColors.surfaceCream,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: OrbitColors.buttonPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr('camera_initializing'),
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
    final reactions = _friendReactions[item.id] ?? [];
    const double avatarSize = 44.0;

    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Biểu tượng cảm xúc bay lên khi chạm đúp thả tim
          if (reactions.isNotEmpty)
            ...reactions.map((r) => Positioned(
                  top: -12,
                  child: _FloatingReactionBubble(
                    key: ValueKey(r.id),
                    emoji: r.emoji,
                    onComplete: () => _removeReaction(item.id, r.id),
                  ),
                )),

          // Avatar tròn tinh gọn, thoáng đãng - Tuyệt đối không nhãn chữ thừa làm dày đặc giao diện
          GestureDetector(
            onDoubleTap: () {
              if (!item.isAddButton) {
                _triggerReaction(item.id, '❤️');
              }
            },
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isAddButton
                    ? OrbitColors.surfaceCard
                    : (item.color ?? OrbitColors.buttonPrimary),
                border: Border.all(
                  color: isSelected
                      ? OrbitColors.terracotta
                      : (item.isAddButton
                          ? OrbitColors.buttonPrimary
                          : (item.hasGlow ? const Color(0xFFFFD54F) : OrbitColors.khakiGold.withValues(alpha: 0.85))),
                  width: isSelected ? 3.2 : (item.hasGlow ? 2.6 : 2.0),
                ),
                boxShadow: [
                  if (item.hasGlow)
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
                      blurRadius: 14,
                      spreadRadius: 2.0,
                    ),
                  BoxShadow(
                    color: isSelected
                        ? OrbitColors.terracotta.withValues(alpha: 0.55)
                        : OrbitColors.deepOlive.withValues(alpha: 0.20),
                    blurRadius: isSelected ? 14 : 6,
                    spreadRadius: isSelected ? 2.0 : 0.5,
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
                    fontSize: item.isAddButton ? 22.0 : 16.0,
                  ),
                ),
              ),
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
                // Flash Button (Icon only)
                GestureDetector(
                  onTap: () async {
                    if (controller != null && controller!.value.isInitialized) {
                      await controller!.setFlashMode(flash ? FlashMode.off : FlashMode.torch);
                      setState(() => flash = !flash);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Icon(
                      flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      size: 18,
                      color: flash ? OrbitColors.khakiGold : OrbitColors.textLight,
                    ),
                  ),
                ),

                _buildDivider(),

                // Timer Button (Icon with active dot)
                GestureDetector(
                  onTap: _toggleTimer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          size: 18,
                          color: timerSeconds > 0 ? OrbitColors.khakiGold : OrbitColors.textLight,
                        ),
                        if (timerSeconds > 0)
                          Positioned(
                            top: -2,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: OrbitColors.terracotta,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                _buildDivider(),

                // Grid Button (Icon only)
                GestureDetector(
                  onTap: () => setState(() => showGrid = !showGrid),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Icon(
                      Icons.grid_on_rounded,
                      size: 18,
                      color: showGrid ? OrbitColors.khakiGold : OrbitColors.textLight,
                    ),
                  ),
                ),

                _buildDivider(),

                // Flip Camera Button (Icon only)
                GestureDetector(
                  onTap: changeCamera,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: const Icon(
                      Icons.flip_camera_ios_rounded,
                      size: 18,
                      color: OrbitColors.textLight,
                    ),
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

          // Pull-up History Indicator (Tối giản, icon chevron mềm mại, không chữ thừa)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: OrbitColors.deepOlive,
                size: 22,
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
  final bool hasGlow;
  final Color? color;

  _SatelliteItem({
    required this.id,
    required this.name,
    required this.initial,
    this.isAddButton = false,
    this.hasGlow = false,
    this.color,
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

class _FloatingReactionItem {
  final String id;
  final String emoji;

  _FloatingReactionItem({required this.id, required this.emoji});
}

class _FloatingReactionBubble extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;

  const _FloatingReactionBubble({
    super.key,
    required this.emoji,
    required this.onComplete,
  });

  @override
  State<_FloatingReactionBubble> createState() => _FloatingReactionBubbleState();
}

class _FloatingReactionBubbleState extends State<_FloatingReactionBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;
        final dy = -8.0 - (56.0 * t); // Bay len tren dau tu -8px den -64px
        final dx = math.sin(t * math.pi * 3) * 6.0; // Uon luon nhe sang hai ben
        final opacity = (t < 0.2 ? (t / 0.2) : (1.0 - (t - 0.2) / 0.8)).clamp(0.0, 1.0);
        final scale = 0.6 + (0.6 * math.sin(t * math.pi));

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                decoration: BoxDecoration(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OrbitColors.buttonPrimary, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

