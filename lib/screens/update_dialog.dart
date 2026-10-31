import 'dart:io';
import 'package:flutter/material.dart';
import 'package:icnative/services/update_service.dart';
import 'package:icnative/settings/theme_colors.dart';

class UpdateDialog extends StatefulWidget {
  final GitHubReleaseInfo releaseInfo;

  const UpdateDialog({super.key, required this.releaseInfo});

  static Future<void> show(BuildContext context, GitHubReleaseInfo releaseInfo) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(releaseInfo: releaseInfo),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String progressText = '';
  String? errorMessage;

  Future<void> _startUpdate() async {
    // Trên iOS, chuyển hướng trực tiếp sang Safari thay vì tải gói APK nội bộ
    if (Platform.isIOS) {
      await UpdateService.instance.openReleasePage(widget.releaseInfo.releasePageUrl);
      if (mounted) Navigator.pop(context);
      return;
    }

    // Nếu link không phải apk hoặc kích thước không hợp lệ, mở trang release trên trình duyệt
    if (widget.releaseInfo.apkSizeBytes <= 0 || !widget.releaseInfo.apkDownloadUrl.toLowerCase().contains('.apk')) {
      await UpdateService.instance.openReleasePage(widget.releaseInfo.releasePageUrl);
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
      progressText = 'Đang kết nối GitHub...';
      errorMessage = null;
    });

    final success = await UpdateService.instance.downloadAndInstallApk(
      downloadUrl: widget.releaseInfo.apkDownloadUrl,
      onProgress: (progress, downloaded, total) {
        if (!mounted) return;
        setState(() {
          downloadProgress = progress;
          final downloadedMb = (downloaded / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
          progressText = '$downloadedMb MB / $totalMb MB (${(progress * 100).toInt()}%)';
        });
      },
    );

    if (success) {
      await UpdateService.instance.markUpdateInstalled(widget.releaseInfo.tagName);
    } else if (mounted) {
      setState(() {
        isDownloading = false;
        errorMessage = 'Không thể tải xuống hoặc mở cài đặt. Vui lòng thử lại sau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;

    return Dialog(
      backgroundColor: OrbitColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: OrbitColors.buttonPrimary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Header
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: OrbitColors.buttonPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    isIOS ? Icons.apple_rounded : Icons.rocket_launch_rounded,
                    color: OrbitColors.textLight,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'Có Phiên Bản Mới!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OrbitColors.deepOlive,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Tag & Size Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OrbitColors.deepOlive.withValues(alpha: 0.2)),
                ),
                child: Text(
                  widget.releaseInfo.formattedSize.isNotEmpty
                      ? '${widget.releaseInfo.tagName} • ${widget.releaseInfo.formattedSize}'
                      : widget.releaseInfo.tagName,
                  style: const TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Release title / notes
            if (widget.releaseInfo.title.isNotEmpty) ...[
              Text(
                widget.releaseInfo.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (widget.releaseInfo.notes.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCard.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.releaseInfo.notes,
                    style: TextStyle(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Thông báo phương thức cập nhật dành cho thiết bị iOS
            if (isIOS) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: OrbitColors.buttonPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: OrbitColors.buttonPrimary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trên thiết bị iOS (iPhone), vui lòng mở trang GitHub Releases để cập nhật gói cài đặt .IPA mới nhất.',
                        style: TextStyle(
                          color: OrbitColors.deepOlive.withValues(alpha: 0.85),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Progress or Error (Chủ yếu Android)
            if (isDownloading) ...[
              LinearProgressIndicator(
                value: downloadProgress > 0 ? downloadProgress : null,
                backgroundColor: OrbitColors.surfaceCard,
                color: OrbitColors.terracotta,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                progressText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (errorMessage != null) ...[
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            if (!isDownloading) ...[
              if (isIOS) ...[
                // CÁC NÚT DÀNH CHO NỀN TẢNG IOS
                ElevatedButton.icon(
                  onPressed: () {
                    UpdateService.instance.openReleasePage(widget.releaseInfo.releasePageUrl);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrbitColors.buttonPrimary,
                    foregroundColor: OrbitColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                  label: const Text(
                    '🌐 Mở Trang Tải GitHub Releases',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.releaseInfo.ipaDownloadUrl != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      UpdateService.instance.openReleasePage(widget.releaseInfo.ipaDownloadUrl);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrbitColors.deepOlive,
                      side: const BorderSide(color: OrbitColors.buttonPrimary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      '📥 Tải Tệp .IPA (${widget.releaseInfo.formattedSize})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ] else ...[
                // CÁC NÚT DÀNH CHO NỀN TẢNG ANDROID
                ElevatedButton.icon(
                  onPressed: _startUpdate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrbitColors.buttonPrimary,
                    foregroundColor: OrbitColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 20),
                  label: const Text(
                    '⚡ Tải & Cập Nhật Tức Thì',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    UpdateService.instance.openReleasePage(widget.releaseInfo.releasePageUrl);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OrbitColors.deepOlive,
                    side: const BorderSide(color: OrbitColors.buttonPrimary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text(
                    '🌐 Mở Trang Tải GitHub Releases',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await UpdateService.instance.dismissUpdate(widget.releaseInfo.tagName);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(
                  'Để sau',
                  style: TextStyle(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Đang chuẩn bị gói cài đặt hệ thống...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
