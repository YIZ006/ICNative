import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import './screens/home.dart';
import './services/auth_service.dart';
import './services/custom_sticker_service.dart';
import './services/friend_service.dart';
import './services/invite_service.dart';
import './services/locale_service.dart';
import './services/secret_photo_service.dart';
import './services/soulmate_service.dart';
import './services/sync_service.dart';
import './settings/global.dart';
import './settings/sizes.dart';
import './settings/theme_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khởi tạo dịch vụ ngôn ngữ siêu nhanh (~2ms, đọc cache)
  await LocaleService.instance.init();

  // 2. MỞ GIAO DIỆN NGAY LẬP TỨC TRONG FRAME ĐẦU TIÊN (ZERO BLOCKING!)
  // Không bao giờ bắt người dùng đợi camera hay network mới hiện màn hình
  runApp(const MyApp());

  // 3. Khởi động song song camera và các dịch vụ nền (Non-blocking background warmup)
  unawaited(_warmupBackgroundServices());
}

Future<void> _warmupBackgroundServices() async {
  // A. Thăm dò camera có timeout an toàn (Tối đa 1000ms, không bao giờ treo)
  await _initCamerasFast();

  // B. Khởi tạo Firebase nếu có cấu hình (Resilient offline-first)
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase successfully initialized!');
  } catch (e) {
    debugPrint('Running in 100% Offline Mode: $e');
  }

  // C. Khởi tạo Auth trước để đảm bảo có danh tính người dùng và UID hợp lệ
  await AuthService.instance.init();

  // D. Khởi tạo Friend, Soulmate, SecretPhoto & SyncService
  await Future.wait([
    FriendService.instance.init(),
    SoulmateService.instance.init(),
    SecretPhotoService.instance.init(),
  ]);

  // D2. Khởi tạo InviteService để bắt Deep Link kết bạn (tự động nhận link khi mở app)
  try {
    await InviteService.instance.init();
  } catch (e) {
    debugPrint('InviteService warmup error: $e');
  }

  // E. Khởi tạo Widget Sync Service và kích hoạt lắng nghe ảnh bạn bè
  try {
    await SyncService.instance.init();
  } catch (e) {
    debugPrint('SyncService warmup error: $e');
  }

  // F. Tải ảnh lịch sử
  await _loadSavedImages();

  // G. Khởi tạo kho meme & sticker engine đầy đủ
  try {
    await CustomStickerService.instance.initialize();
  } catch (e) {
    debugPrint('CustomStickerService warmup error: $e');
  }
}

Future<void> _initCamerasFast() async {
  try {
    if (cameras.isEmpty) {
      final camList = await availableCameras().timeout(
        const Duration(milliseconds: 2000),
        onTimeout: () => <CameraDescription>[],
      );
      if (camList.isNotEmpty) {
        cameras = camList;
      }
    }
  } catch (e) {
    debugPrint('Camera fast init error: $e');
  }
}

Future<void> _loadSavedImages() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync();
    images.clear();
    for (var file in files) {
      if (file is File && (file.path.endsWith('.png') || file.path.endsWith('.jpg'))) {
        if (file.path.contains('widget_image_') || file.path.contains('friend_widget_')) {
          images.add(file.path);
        }
      }
    }
  } catch (e) {
    debugPrint('Error loading saved images: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LocaleService.instance.currentLanguage,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'Orbit',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: OrbitColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: OrbitColors.buttonPrimary,
              primary: OrbitColors.buttonPrimary,
              secondary: OrbitColors.surfaceCream,
              surface: OrbitColors.background,
            ),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
