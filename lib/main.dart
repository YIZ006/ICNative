import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import './screens/home.dart';
import './services/auth_service.dart';
import './services/custom_sticker_service.dart';
import './services/friend_service.dart';
import './services/sync_service.dart';
import './settings/global.dart';
import './settings/sizes.dart';
import './settings/theme_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera initialization error: $e');
  }

  // 2. Initialize Firebase (Offline-first resilient: will not crash if google-services.json is not configured)
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase successfully initialized!');
  } catch (e) {
    debugPrint('Running in 100% Offline Mode (Firebase unconfigured or offline): $e');
  }

  // 3. Initialize Random Anonymous Identity
  await AuthService.instance.init();

  // 4. Initialize Cached Friends
  await FriendService.instance.init();

  // 5. Initialize Realtime Sync & Widget updates
  await SyncService.instance.init();

  // 6. Preload past photos into history
  await _loadSavedImages();

  // 7. Initialize Custom Sticker Engine & Meme Library
  await CustomStickerService.instance.initialize();

  runApp(const MyApp());
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
    return MaterialApp(
      title: 'ICNative',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: OrbitColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: OrbitColors.buttonPrimary,
          primary: OrbitColors.buttonPrimary,
          surface: OrbitColors.background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: OrbitColors.background,
          elevation: 0,
          iconTheme: IconThemeData(color: OrbitColors.deepOlive),
          titleTextStyle: TextStyle(
            color: OrbitColors.deepOlive,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
