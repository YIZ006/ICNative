import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class GitHubReleaseInfo {
  final String tagName;
  final String title;
  final String notes;
  final String apkDownloadUrl;
  final int apkSizeBytes;
  final String publishedAt;
  final String? ipaDownloadUrl;
  final String releasePageUrl;
  final bool isIos;

  GitHubReleaseInfo({
    required this.tagName,
    required this.title,
    required this.notes,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
    this.ipaDownloadUrl,
    String? releasePageUrl,
    this.isIos = false,
  }) : releasePageUrl = releasePageUrl ??
            'https://github.com/${UpdateService.repoOwner}/${UpdateService.repoName}/releases/tag/$tagName';

  String get formattedSize {
    if (apkSizeBytes <= 0) return isIos ? 'Bản Cập Nhật iOS' : '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  /// Phân định bản build hiện tại (Clean Release vs Demo Showcase)
  static const bool isDemoBuild = bool.fromEnvironment('DEFAULT_DEMO_MODE', defaultValue: false);

  static String _currentVersion = '1.4.1';
  static String get currentVersion => _currentVersion;
  static const String repoOwner = 'YIZ006';
  static const String repoName = 'ICNative';
  static const MethodChannel _channel = MethodChannel('com.abom.utas.utas/app_updater');

  /// Lấy phiên bản thực tế đã cài đặt trên thiết bị từ Android PackageManager hoặc iOS Bundle
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

  /// Kiểm tra phiên bản mới nhất từ GitHub Releases (Hỗ trợ tự động khi mở app và bấm thủ công)
  Future<GitHubReleaseInfo?> checkForUpdate({bool isManual = false}) async {
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

        // Nếu kiểm tra tự động khi mở app: Chỉ hoãn nếu người dùng đã bấm "Để sau" cho chính phiên bản này trong 24h
        if (!isManual) {
          final prefs = await SharedPreferences.getInstance();
          final dismissedTag = prefs.getString('dismissed_update_tag');
          final dismissedTime = prefs.getInt('dismissed_update_time') ?? 0;
          final elapsed = DateTime.now().millisecondsSinceEpoch - dismissedTime;
          if (dismissedTag == tagName && elapsed < 24 * 60 * 60 * 1000) {
            return null;
          }
        }

        final assets = (data['assets'] as List<dynamic>? ?? []);
        final htmlUrl = (data['html_url'] as String? ??
                'https://github.com/$repoOwner/$repoName/releases/tag/$tagName')
            .trim();
        String? targetDownloadUrl;
        String? ipaUrl;
        int targetSize = 0;

        if (Platform.isIOS) {
          // iOS asset matching: tìm kiếm tệp cài đặt .ipa
          for (final asset in assets) {
            final assetName = (asset['name'] as String? ?? '').toLowerCase();
            if (assetName.endsWith('.ipa')) {
              ipaUrl = asset['browser_download_url'] as String?;
              targetDownloadUrl = ipaUrl;
              targetSize = asset['size'] as int? ?? 0;
              break;
            }
          }
          // Fallback về URL trang release trên GitHub nếu chưa tìm thấy link ipa trực tiếp
          targetDownloadUrl ??= htmlUrl;
        } else {
          // QUY TẮC CHỐNG TẢI NHẦM BẢN (ANTI-MISMATCH ASSET MATCHING CHO ANDROID)
          if (!isDemoBuild) {
            // 1. Bản Chuẩn (Clean Release): Tuyệt đối KHÔNG BAO GIỜ tải bản demo
            for (final asset in assets) {
              final assetName = (asset['name'] as String? ?? '').toLowerCase();
              if (assetName.contains('clean-release') && assetName.endsWith('.apk')) {
                targetDownloadUrl = asset['browser_download_url'] as String?;
                targetSize = asset['size'] as int? ?? 0;
                break;
              }
            }
            if (targetDownloadUrl == null) {
              for (final asset in assets) {
                final assetName = (asset['name'] as String? ?? '').toLowerCase();
                if (assetName.endsWith('.apk') && !assetName.contains('demo')) {
                  targetDownloadUrl = asset['browser_download_url'] as String?;
                  targetSize = asset['size'] as int? ?? 0;
                  break;
                }
              }
            }
          } else {
            // 2. Bản Trải Nghiệm (Demo Showcase): Ưu tiên tải bản demo
            for (final asset in assets) {
              final assetName = (asset['name'] as String? ?? '').toLowerCase();
              if (assetName.contains('demo-showcase') && assetName.endsWith('.apk')) {
                targetDownloadUrl = asset['browser_download_url'] as String?;
                targetSize = asset['size'] as int? ?? 0;
                break;
              }
            }
            if (targetDownloadUrl == null) {
              for (final asset in assets) {
                final assetName = (asset['name'] as String? ?? '').toLowerCase();
                if (assetName.contains('demo') && assetName.endsWith('.apk')) {
                  targetDownloadUrl = asset['browser_download_url'] as String?;
                  targetSize = asset['size'] as int? ?? 0;
                  break;
                }
              }
            }
            if (targetDownloadUrl == null) {
              // Fallback nếu GitHub chưa có demo build
              for (final asset in assets) {
                final assetName = (asset['name'] as String? ?? '').toLowerCase();
                if (assetName.endsWith('.apk')) {
                  targetDownloadUrl = asset['browser_download_url'] as String?;
                  targetSize = asset['size'] as int? ?? 0;
                  break;
                }
              }
            }
          }
        }

        final currentVer = await getInstalledVersion();
        // So sánh phiên bản chuẩn semantic version
        if (_isNewerVersion(tagName, currentVer)) {
          return GitHubReleaseInfo(
            tagName: tagName,
            title: title,
            notes: notes,
            apkDownloadUrl: targetDownloadUrl ?? htmlUrl,
            apkSizeBytes: targetSize,
            publishedAt: publishedAt,
            ipaDownloadUrl: ipaUrl,
            releasePageUrl: htmlUrl,
            isIos: Platform.isIOS,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking GitHub updates: $e');
    }
    return null;
  }

  /// Mở trình duyệt web trực tiếp đến trang GitHub Releases hoặc link tải (Hỗ trợ Safari trên iOS và Chrome/mặc định trên Android)
  Future<bool> openReleasePage([String? url]) async {
    final targetUrl = url ?? 'https://github.com/$repoOwner/$repoName/releases/latest';

    // 1. Thử mở bằng package url_launcher chuẩn hoá đa nền tảng
    try {
      final uri = Uri.parse(targetUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('url_launcher attempt error: $e');
    }

    // 2. Dự phòng bằng Native MethodChannel nếu url_launcher chưa sẵn sàng
    try {
      final bool? result = await _channel.invokeMethod<bool>('openUrl', {
        'url': targetUrl,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('PlatformException during openUrl: ${e.message}');
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Tải tệp cài đặt với thanh tiến trình trực tiếp (Android) hoặc mở Safari (iOS)
  Future<bool> downloadAndInstallApk({
    required String downloadUrl,
    required void Function(double progress, int downloadedBytes, int totalBytes) onProgress,
  }) async {
    // Trên iOS, Apple không cho phép tự cài APK/IPA nội bộ; chuyển tiếp trực tiếp sang trình duyệt Safari
    if (Platform.isIOS) {
      return await openReleasePage(downloadUrl);
    }

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
    if (Platform.isIOS) return false;
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

  /// So sánh hai chuỗi version (ví dụ: v1.4.1 vs 1.4.0)
  bool _isNewerVersion(String remoteTag, String currentVer) {
    try {
      // Tách bỏ build number (+5) và build suffix (-beta) trước khi so sánh
      final semVerRemote = remoteTag.split('+').first.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
      final semVerCurrent = currentVer.split('+').first.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');

      // Nếu 2 chuỗi version bằng nhau tuyệt đối -> Không phải bản mới
      if (semVerRemote == semVerCurrent) {
        return false;
      }

      final rParts = semVerRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = semVerCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = math.max(rParts.length, cParts.length);
      for (int i = 0; i < maxLen; i++) {
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
