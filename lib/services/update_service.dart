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

enum DownloadStatus { idle, downloading, paused, completed, failed }

class UpdateDownloadProgress {
  final DownloadStatus status;
  final double progress; // 0.0 - 1.0
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final String? savedFilePath;
  final String? errorMessage;
  final GitHubReleaseInfo? releaseInfo;

  const UpdateDownloadProgress({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.savedFilePath,
    this.errorMessage,
    this.releaseInfo,
  });

  UpdateDownloadProgress copyWith({
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    double? speedBytesPerSec,
    String? savedFilePath,
    String? errorMessage,
    GitHubReleaseInfo? releaseInfo,
  }) {
    return UpdateDownloadProgress(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      savedFilePath: savedFilePath ?? this.savedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      releaseInfo: releaseInfo ?? this.releaseInfo,
    );
  }
}

class UpdateService {
  static final UpdateService instance = UpdateService._internal();
  UpdateService._internal();

  /// Phân định bản build hiện tại (Clean Release vs Demo Showcase)
  static const bool isDemoBuild = bool.fromEnvironment('DEFAULT_DEMO_MODE', defaultValue: false);

  static String _currentVersion = '1.5.0';
  static String get currentVersion => _currentVersion;
  static const String repoOwner = 'YIZ006';
  static const String repoName = 'ICNative';
  static const MethodChannel _channel = MethodChannel('com.abom.utas.utas/app_updater');

  /// Thông báo bản cập nhật mới đang chờ (để hiển thị banner trên HomeScreen / ProfileScreen)
  final ValueNotifier<GitHubReleaseInfo?> pendingUpdateNotifier =
      ValueNotifier<GitHubReleaseInfo?>(null);

  /// Tiến trình tải bản cập nhật ngầm theo thời gian thực
  final ValueNotifier<UpdateDownloadProgress> downloadProgressNotifier =
      ValueNotifier<UpdateDownloadProgress>(const UpdateDownloadProgress());

  int? _activeSystemDownloadId;
  Timer? _systemPollTimer;
  DateTime? _lastSpeedCalcTime;
  int _lastDownloadedBytes = 0;
  bool _isDartDownloading = false;
  http.Client? _activeHttpClient;

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
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        // Không thông báo cập nhật nếu release đang là bản nháp (draft)
        if (data['draft'] == true) {
          debugPrint('Bỏ qua: Release đang ở chế độ draft.');
          return null;
        }

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
        final matched = matchReleaseAsset(
          assets: assets,
          isDemo: isDemoBuild,
          isIos: Platform.isIOS,
          htmlUrl: htmlUrl,
        );
        final targetDownloadUrl = matched.targetDownloadUrl;
        final ipaUrl = matched.ipaUrl;
        final targetSize = matched.targetSize;

        // CHẶN BÁO CẬP NHẬT SỚM KHI CHƯA HOÀN TẤT ĐÓNG GÓI TRÊN GITHUB:
        // Nếu file cài đặt chưa upload xong (size <= 0 hoặc url null) thì không làm phiền người dùng
        if (!Platform.isIOS) {
          if (targetDownloadUrl == null || targetSize <= 0) {
            debugPrint('Bỏ qua: Bản build Android chưa tải xong lên GitHub Release.');
            return null;
          }
        } else {
          // Trên iOS: Nếu kiểm tra tự động mà chưa có file .ipa thì cũng chưa vội báo
          if (!isManual && (ipaUrl == null || targetSize <= 0)) {
            debugPrint('Bỏ qua: Bản build iOS IPA chưa tải xong lên GitHub Release.');
            return null;
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

  /// Kích hoạt cập nhật trực tiếp qua TrollStore URL scheme trên iOS (1-Chạm không cần chứng chỉ)
  Future<bool> installViaTrollStore(String ipaUrl) async {
    final encodedUrl = Uri.encodeComponent(ipaUrl);
    final trollStoreSchemes = [
      'apple-magnifier://install?url=$encodedUrl',
      'trollstore://install?url=$encodedUrl',
    ];

    for (final scheme in trollStoreSchemes) {
      try {
        final uri = Uri.parse(scheme);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('TrollStore launch error ($scheme): $e');
      }
    }
    return false;
  }

  /// Khởi chạy tải bản cập nhật ngầm (Android DownloadManager hoặc Resilient HTTP stream)
  Future<void> startBackgroundDownload(GitHubReleaseInfo release) async {
    if (Platform.isIOS) {
      await openReleasePage(release.releasePageUrl);
      return;
    }

    // Nếu đang tải bản này rồi thì không bắt đầu lại
    if (downloadProgressNotifier.value.status == DownloadStatus.downloading &&
        downloadProgressNotifier.value.releaseInfo?.tagName == release.tagName) {
      return;
    }

    downloadProgressNotifier.value = UpdateDownloadProgress(
      status: DownloadStatus.downloading,
      progress: 0.0,
      downloadedBytes: 0,
      totalBytes: release.apkSizeBytes > 0 ? release.apkSizeBytes : 0,
      releaseInfo: release,
    );

    // 1. Thử dùng Native Android DownloadManager (chạy 100% ngầm của hệ điều hành, không ngắt khi thoát app)
    try {
      final fileName = 'Orbit_${release.tagName}_${DateTime.now().millisecondsSinceEpoch}.apk';
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod('startDownload', {
        'url': release.apkDownloadUrl,
        'title': 'Orbit ${release.tagName}',
        'fileName': fileName,
      });

      if (res != null && res['downloadId'] != null) {
        final downloadId = (res['downloadId'] as num).toInt();
        final filePath = res['filePath'] as String? ?? '';
        _activeSystemDownloadId = downloadId;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('orbit_system_download_id', downloadId);
        await prefs.setString('orbit_system_download_path', filePath);
        await prefs.setString('orbit_system_download_tag', release.tagName);

        _startSystemPollTimer(downloadId, filePath, release);
        return;
      }
    } catch (e) {
      debugPrint('Native DownloadManager not available, falling back to Dart stream: $e');
    }

    // 2. Fallback: Dùng Pure-Dart Resilient Downloader có hỗ trợ resume Range Header
    await _startDartResilientDownload(release);
  }

  void _startSystemPollTimer(int downloadId, String filePath, GitHubReleaseInfo release) {
    _systemPollTimer?.cancel();
    _lastSpeedCalcTime = DateTime.now();
    _lastDownloadedBytes = 0;

    _systemPollTimer = Timer.periodic(const Duration(milliseconds: 750), (timer) async {
      try {
        final Map<dynamic, dynamic>? statusMap = await _channel.invokeMethod('checkDownloadStatus', {
          'downloadId': downloadId,
        });

        if (statusMap == null) return;
        final status = statusMap['status'] as String? ?? 'unknown';
        final downloaded = (statusMap['bytesDownloaded'] as num? ?? 0).toInt();
        final total = (statusMap['bytesTotal'] as num? ?? release.apkSizeBytes).toInt();

        // Tính toán tốc độ tải theo thời gian thực
        final now = DateTime.now();
        double speed = 0.0;
        if (_lastSpeedCalcTime != null) {
          final elapsedMs = now.difference(_lastSpeedCalcTime!).inMilliseconds;
          if (elapsedMs > 500) {
            final diffBytes = downloaded - _lastDownloadedBytes;
            if (diffBytes > 0) {
              speed = (diffBytes / (elapsedMs / 1000.0));
            }
            _lastSpeedCalcTime = now;
            _lastDownloadedBytes = downloaded;
          }
        }

        final progress = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0.0;

        if (status == 'successful') {
          timer.cancel();
          _systemPollTimer = null;
          downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
            status: DownloadStatus.completed,
            progress: 1.0,
            downloadedBytes: total > 0 ? total : downloaded,
            totalBytes: total > 0 ? total : downloaded,
            speedBytesPerSec: 0,
            savedFilePath: filePath,
          );
          await markUpdateInstalled(release.tagName);
          await installDownloadedApk(filePath);
        } else if (status == 'failed') {
          timer.cancel();
          _systemPollTimer = null;
          debugPrint('System download failed, trying Dart fallback...');
          await _startDartResilientDownload(release);
        } else if (status == 'paused') {
          downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
            status: DownloadStatus.paused,
            progress: progress,
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSec: 0,
          );
        } else {
          downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
            status: DownloadStatus.downloading,
            progress: progress,
            downloadedBytes: downloaded,
            totalBytes: total,
            speedBytesPerSec: speed,
            savedFilePath: filePath,
          );
        }
      } catch (e) {
        debugPrint('Poll system download error: $e');
      }
    });
  }

  Future<void> _startDartResilientDownload(GitHubReleaseInfo release) async {
    if (_isDartDownloading) return;
    _isDartDownloading = true;

    try {
      final tempDir = await getTemporaryDirectory();
      final partFile = File('${tempDir.path}/Orbit_${release.tagName}.apk.part');
      final finalFile = File('${tempDir.path}/Orbit_${release.tagName}.apk');

      int existingBytes = 0;
      if (partFile.existsSync()) {
        existingBytes = partFile.lengthSync();
      }

      final client = http.Client();
      _activeHttpClient = client;

      final request = http.Request('GET', Uri.parse(release.apkDownloadUrl));
      request.headers['User-Agent'] = 'Orbit-Mobile-App';
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }

      final response = await client.send(request);
      final isPartial = response.statusCode == 206;
      final isOk = response.statusCode == 200;

      if (!isOk && !isPartial) {
        downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Lỗi máy chủ (${response.statusCode})',
        );
        _isDartDownloading = false;
        return;
      }

      final sink = partFile.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
      int downloadedBytes = isPartial ? existingBytes : 0;
      final totalBytes = isPartial
          ? existingBytes + (response.contentLength ?? 0)
          : (response.contentLength ?? release.apkSizeBytes);

      DateTime lastTime = DateTime.now();
      int lastBytes = downloadedBytes;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final now = DateTime.now();
        double speed = 0.0;
        final elapsedMs = now.difference(lastTime).inMilliseconds;
        if (elapsedMs > 500) {
          speed = ((downloadedBytes - lastBytes) / (elapsedMs / 1000.0));
          lastTime = now;
          lastBytes = downloadedBytes;
        }

        final progress = totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
          status: DownloadStatus.downloading,
          progress: progress,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          speedBytesPerSec: speed,
        );
      }

      await sink.flush();
      await sink.close();
      client.close();
      _activeHttpClient = null;

      if (partFile.existsSync()) {
        if (finalFile.existsSync()) finalFile.deleteSync();
        await partFile.rename(finalFile.path);
      }

      downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedBytes: totalBytes,
        totalBytes: totalBytes,
        speedBytesPerSec: 0,
        savedFilePath: finalFile.path,
      );

      await markUpdateInstalled(release.tagName);
      await installDownloadedApk(finalFile.path);
    } catch (e) {
      debugPrint('Dart download error: $e');
      downloadProgressNotifier.value = downloadProgressNotifier.value.copyWith(
        status: DownloadStatus.failed,
        errorMessage: 'Lỗi kết nối mạng: $e',
      );
    } finally {
      _isDartDownloading = false;
    }
  }

  /// Hủy bỏ tải về hiện tại
  Future<void> cancelDownload() async {
    _systemPollTimer?.cancel();
    _systemPollTimer = null;

    if (_activeSystemDownloadId != null) {
      try {
        await _channel.invokeMethod('cancelDownload', {
          'downloadId': _activeSystemDownloadId,
        });
      } catch (_) {}
      _activeSystemDownloadId = null;
    }

    _activeHttpClient?.close();
    _activeHttpClient = null;
    _isDartDownloading = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('orbit_system_download_id');
    await prefs.remove('orbit_system_download_path');
    await prefs.remove('orbit_system_download_tag');

    downloadProgressNotifier.value = const UpdateDownloadProgress(status: DownloadStatus.idle);
  }

  /// Khôi phục kiểm tra trạng thái tải ngầm khi mở lại ứng dụng
  Future<void> checkExistingDownloadOnStart() async {
    if (Platform.isIOS) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloadId = prefs.getInt('orbit_system_download_id');
      final filePath = prefs.getString('orbit_system_download_path');
      final tag = prefs.getString('orbit_system_download_tag');

      if (downloadId != null && filePath != null) {
        final Map<dynamic, dynamic>? statusMap = await _channel.invokeMethod('checkDownloadStatus', {
          'downloadId': downloadId,
        });
        if (statusMap != null) {
          final status = statusMap['status'] as String? ?? '';
          if (status == 'successful') {
            downloadProgressNotifier.value = UpdateDownloadProgress(
              status: DownloadStatus.completed,
              progress: 1.0,
              savedFilePath: filePath,
            );
          } else if (status == 'running' || status == 'pending' || status == 'paused') {
            _activeSystemDownloadId = downloadId;
            final downloaded = (statusMap['bytesDownloaded'] as num? ?? 0).toInt();
            final total = (statusMap['bytesTotal'] as num? ?? 0).toInt();
            final progress = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0.0;
            downloadProgressNotifier.value = UpdateDownloadProgress(
              status: status == 'paused' ? DownloadStatus.paused : DownloadStatus.downloading,
              progress: progress,
              downloadedBytes: downloaded,
              totalBytes: total,
              savedFilePath: filePath,
            );
            _startSystemPollTimer(downloadId, filePath, GitHubReleaseInfo(
              tagName: tag ?? '',
              title: 'Orbit $tag',
              notes: '',
              apkDownloadUrl: '',
              apkSizeBytes: total,
              publishedAt: '',
              releasePageUrl: '',
            ));
          }
        }
      }
    } catch (_) {}
  }

  /// Cài đặt lại tệp APK đã tải xong
  Future<bool> installCurrentApk() async {
    final path = downloadProgressNotifier.value.savedFilePath;
    if (path != null && File(path).existsSync()) {
      return await installDownloadedApk(path);
    }
    return false;
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

      final fileSize = targetFile.lengthSync();
      debugPrint('APK downloaded to: ${targetFile.path} ($fileSize bytes)');
      if (fileSize < 1024 * 1024) {
        debugPrint('Download error: file size too small ($fileSize bytes)');
        return false;
      }

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

  /// Bộ so khớp tệp cài đặt Release theo chuẩn Dual-Release và Anti-Mismatch
  @visibleForTesting
  static ({String? targetDownloadUrl, String? ipaUrl, int targetSize}) matchReleaseAsset({
    required List<dynamic> assets,
    required bool isDemo,
    required bool isIos,
    required String htmlUrl,
  }) {
    String? targetDownloadUrl;
    String? ipaUrl;
    int targetSize = 0;

    if (isIos) {
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
      targetDownloadUrl ??= htmlUrl;
    } else {
      // QUY TẮC CHỐNG TẢI NHẦM BẢN (ANTI-MISMATCH ASSET MATCHING CHO ANDROID)
      if (!isDemo) {
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

    return (
      targetDownloadUrl: targetDownloadUrl,
      ipaUrl: ipaUrl,
      targetSize: targetSize,
    );
  }

  /// So sánh hai chuỗi version (ví dụ: v1.4.1 vs 1.4.0)
  @visibleForTesting
  static bool isNewerVersion(String remoteTag, String currentVer) {
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

  bool _isNewerVersion(String remoteTag, String currentVer) => isNewerVersion(remoteTag, currentVer);
}
