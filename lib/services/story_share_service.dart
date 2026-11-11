import 'package:flutter/services.dart';

/// Kết quả khi mở Instagram Story.
enum InstagramShareResult {
  /// Mở thẳng trình soạn Story của Instagram.
  story,

  /// Mở Instagram, Instagram tự hỏi Story / Feed / Reels / Tin nhắn.
  instagram,

  /// Máy chưa cài Instagram -> đã mở bảng chia sẻ hệ thống.
  chooser,
}

/// Cầu nối Native (Android MediaCodec + MediaStore + Intent) cho tính năng xuất Story.
/// 100% Offline, không dùng thư viện ngoài hay Cloud API.
class StoryShareService {
  static const MethodChannel _channel = MethodChannel('com.abom.utas.utas/story_share');

  static const String mimeVideo = 'video/mp4';
  static const String mimeImage = 'image/png';

  // ---------- Mã hoá video MP4 từ các khung hình ----------
  static Future<void> startVideo({
    required String path,
    required int width,
    required int height,
    required int fps,
  }) =>
      _channel.invokeMethod('startVideo', {
        'path': path,
        'width': width,
        'height': height,
        'fps': fps,
      });

  static Future<void> addFrame(Uint8List rgba, int width, int height) => _channel.invokeMethod('addFrame', {
        'bytes': rgba,
        'width': width,
        'height': height,
      });

  static Future<String?> finishVideo() => _channel.invokeMethod<String>('finishVideo');

  static Future<void> cancelVideo() async {
    try {
      await _channel.invokeMethod('cancelVideo');
    } catch (_) {}
  }

  // ---------- Lưu & Chia sẻ ----------
  static Future<bool> saveToGallery(String path, String mime) async {
    final ok = await _channel.invokeMethod<bool>('saveToGallery', {'path': path, 'mime': mime});
    return ok ?? false;
  }

  static Future<bool> isInstagramInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isInstagramInstalled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<InstagramShareResult> shareToInstagramStory(String path, String mime) async {
    final res = await _channel.invokeMethod<String>('shareToInstagramStory', {'path': path, 'mime': mime});
    switch (res) {
      case 'story':
        return InstagramShareResult.story;
      case 'instagram':
        return InstagramShareResult.instagram;
      default:
        return InstagramShareResult.chooser;
    }
  }

  static Future<void> shareGeneric(String path, String mime) =>
      _channel.invokeMethod('shareGeneric', {'path': path, 'mime': mime});
}
