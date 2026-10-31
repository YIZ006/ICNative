import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GitHubReleaseInfo {
  final String tagName;
  final String title;
  final String notes;
  final String apkDownloadUrl;
  final int apkSizeBytes;
  final String publishedAt;

  GitHubReleaseInfo({
    required this.tagName,
    required this.title,
    required this.notes,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  static String _currentVersion = '1.4.0';
  static String get currentVersion => _currentVersion;
  static const String repoOwner = 'YIZ006';
  static const String repoName = 'ICNative';
  static const MethodChannel _channel = MethodChannel('com.abom.utas.utas/app_updater');

  /// Lấy phiên bản thực tế đã cài đặt trên thiết bị từ Android PackageManager
  Future<String> getInstalledVersion() async {
    try {
      final String? ver = await _channel.invokeMethod<String>('getAppVersion');
      if (ver != null && ver.isNotEmpty) {
        _currentVersion = ver;
      }
    } catch (_) {}
    return _currentVersion;
  }

  /// Lưu trạng thái người dùng bấm "Để sau" để không làm phiền trong 24 giờ
  Future<void> dismissUpdate(String tagName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dismissed_update_tag', tagName);
      await prefs.setInt('dismissed_update_time', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Đánh dấu phiên bản đã được người dùng tải/cập nhật
  Future<void> markUpdateInstalled(String tagName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('installed_update_tag', tagName);
    } catch (_) {}
  }

  /// Kiểm tra phiên bản mới nhất từ GitHub Releases (chỉ thực hiện khi người dùng bấm thủ công)
  Future<GitHubReleaseInfo?> checkForUpdate({bool isManual = false}) async {
    // Tuyệt đối KHÔNG tự động kiểm tra ngầm hoặc hiển thị popup tự động làm phiền người dùng
    if (!isManual) {
      return null;
    }

    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(url, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'ICNative-Mobile-App',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tagName = (data['tag_name'] as String? ?? '').trim();
        final title = (data['name'] as String? ?? tagName).trim();
        final notes = (data['body'] as String? ?? '').trim();
        final publishedAt = (data['published_at'] as String? ?? '').trim();

        final assets = (data['assets'] as List<dynamic>? ?? []);
        String? apkUrl;
        int apkSize = 0;

        // Ưu tiên tệp clean-release.apk nếu có
        for (final asset in assets) {
          final assetName = (asset['name'] as String? ?? '').toLowerCase();
          if (assetName.contains('clean-release') && assetName.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            apkSize = asset['size'] as int? ?? 0;
            break;
          }
        }
        if (apkUrl == null) {
          for (final asset in assets) {
            final assetName = (asset['name'] as String? ?? '').toLowerCase();
            if (assetName.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String?;
              apkSize = asset['size'] as int? ?? 0;
              break;
            }
          }
        }

        final currentVer = await getInstalledVersion();
        // So sánh phiên bản
        if (_isNewerVersion(tagName, currentVer)) {
          return GitHubReleaseInfo(
            tagName: tagName,
            title: title,
            notes: notes,
            apkDownloadUrl: apkUrl ?? 'https://github.com/$repoOwner/$repoName/releases/latest',
            apkSizeBytes: apkSize,
            publishedAt: publishedAt,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking GitHub updates: $e');
    }
    return null;
  }

  /// Mở trình duyệt web trực tiếp đến trang GitHub Releases để người dùng tải nhanh, minh bạch
  Future<bool> openReleasePage([String? url]) async {
    final targetUrl = url ?? 'https://github.com/$repoOwner/$repoName/releases/latest';
    try {
      final bool? result = await _channel.invokeMethod<bool>('openUrl', {
        'url': targetUrl,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('PlatformException during openUrl: ${e.message}');
      return false;
    }
  }

  /// Tải tệp APK từ GitHub với thanh tiến trình trực tiếp và kích hoạt cài đặt tức thì
  Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    required void Function(double progress, int downloadedBytes, int totalBytes) onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'ICNative-Mobile-App';

      final response = await client.send(request);
      if (response.statusCode != 200 && response.statusCode != 302) {
        debugPrint('Download error: status code ${response.statusCode}');
        return false;
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/ICNative_Update.apk');

      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }

      final sink = targetFile.openWrite();
      int downloadedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, downloadedBytes, totalBytes);
        } else {
          onProgress(0.5, downloadedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      debugPrint('APK downloaded to: ${targetFile.path} (${targetFile.lengthSync()} bytes)');

      // Kích hoạt Native Android Package Installer qua MethodChannel
      return await installDownloadedApk(targetFile.path);
    } catch (e) {
      debugPrint('Download & install error: $e');
      return false;
    }
  }

  /// Gọi Android Package Installer hệ thống bằng MethodChannel (Zero dependency)
  Future<bool> installDownloadedApk(String filePath) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('PlatformException during installApk: ${e.message}');
      return false;
    }
  }

  /// So sánh hai chuỗi version (ví dụ: v1.4.0 vs 1.3.0)
  bool _isNewerVersion(String remoteTag, String currentVer) {
    try {
      final cleanRemote = remoteTag.replaceAll(RegExp(r'[^0-9.]'), '');
      final cleanCurrent = currentVer.replaceAll(RegExp(r'[^0-9.]'), '');

      // Nếu 2 chuỗi version bằng nhau tuyệt đối (ví dụ: 1.4.0 == 1.4.0) -> Tuyệt đối KHÔNG phải bản mới
      if (cleanRemote == cleanCurrent) {
        return false;
      }

      final rParts = cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
