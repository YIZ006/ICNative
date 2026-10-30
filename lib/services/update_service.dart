import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  static const String currentVersion = '1.4.0';
  static const String repoOwner = 'YIZ006';
  static const String repoName = 'ICNative';
  static const MethodChannel _channel = MethodChannel('com.abom.utas.utas/app_updater');

  /// Kiểm tra phiên bản mới nhất từ GitHub Releases (0 VNĐ & Cực nhanh)
  Future<GitHubReleaseInfo?> checkForUpdate() async {
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

        for (final asset in assets) {
          final assetName = (asset['name'] as String? ?? '').toLowerCase();
          if (assetName.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            apkSize = asset['size'] as int? ?? 0;
            break;
          }
        }

        // Nếu không có file APK đính kèm trong release asset, fallback lấy url release
        if (apkUrl == null || apkUrl.isEmpty) {
          debugPrint('GitHub Release $tagName does not contain an .apk asset yet.');
          return null;
        }

        // So sánh phiên bản
        if (_isNewerVersion(tagName, currentVersion)) {
          return GitHubReleaseInfo(
            tagName: tagName,
            title: title,
            notes: notes,
            apkDownloadUrl: apkUrl,
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
