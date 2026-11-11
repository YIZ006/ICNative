import 'package:flutter/material.dart';
import 'package:icnative/services/update_service.dart';
import 'package:icnative/settings/theme_colors.dart';

class UpdateScreen extends StatelessWidget {
  final GitHubReleaseInfo releaseInfo;

  const UpdateScreen({super.key, required this.releaseInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitColors.background,
      appBar: AppBar(
        backgroundColor: OrbitColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: OrbitColors.deepOlive, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'CẬP NHẬT ỨNG DỤNG',
          style: TextStyle(
            color: OrbitColors.deepOlive,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Thẻ thông tin phiên bản
              _buildVersionCard(context),

              const SizedBox(height: 16),

              // 2. Thẻ ghi chú phát hành (What's New)
              _buildReleaseNotesCard(),

              const SizedBox(height: 18),

              // 3. Khu vực điều khiển tải ngầm & cài đặt
              _buildDownloadControlCard(context),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionCard(BuildContext context) {
    const isDemo = UpdateService.isDemoBuild;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: OrbitColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: OrbitColors.deepOlive.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // App Logo with orbital rings
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDDA15E), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFBC6C25).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/app_logo_orbit.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.public_rounded,
                  color: OrbitColors.buttonPrimary,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Release Title & Version comparison
          Text(
            releaseInfo.title.isNotEmpty ? releaseInfo.title : 'Orbit ${releaseInfo.tagName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OrbitColors.deepOlive,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),

          // Version badge comparison row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Hiện tại: v${UpdateService.currentVersion}',
                  style: TextStyle(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 14, color: OrbitColors.buttonPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OrbitColors.buttonPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Mới: ${releaseInfo.tagName}',
                  style: const TextStyle(
                    color: OrbitColors.textLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Dual-Release badge & File size
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: isDemo ? const Color(0xFFFFE082) : const Color(0xFFC8E6C9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  isDemo ? '⭐ Bản Demo Showcase' : '✨ Bản Chuẩn Sạch (Clean)',
                  style: TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (releaseInfo.formattedSize.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '•  ${releaseInfo.formattedSize}',
                  style: TextStyle(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.65),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseNotesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OrbitColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: OrbitColors.buttonPrimary),
              SizedBox(width: 8),
              Text(
                'CÓ GÌ MỚI TRONG BẢN NÀY?',
                style: TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: OrbitColors.surfaceCream,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              child: Text(
                releaseInfo.notes.isNotEmpty
                    ? releaseInfo.notes
                    : 'Bản cập nhật tối ưu hóa hiệu năng, cải thiện độ mượt và bổ sung tính năng mới cho Orbit Widget.',
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadControlCard(BuildContext context) {
    return ValueListenableBuilder<UpdateDownloadProgress>(
      valueListenable: UpdateService.instance.downloadProgressNotifier,
      builder: (context, progress, _) {
        final isDownloading = progress.status == DownloadStatus.downloading;
        final isCompleted = progress.status == DownloadStatus.completed;
        final isFailed = progress.status == DownloadStatus.failed;
        final isPaused = progress.status == DownloadStatus.paused;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: OrbitColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.shade600
                  : OrbitColors.buttonPrimary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: OrbitColors.deepOlive.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Trạng thái: ĐANG TẢI hoặc ĐÃ TẢI XONG
              if (isDownloading || isPaused) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPaused ? '⏸️ Tạm dừng tải' : '📥 Đang tải ngầm trong nền...',
                      style: const TextStyle(
                        color: OrbitColors.deepOlive,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${(progress.progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: OrbitColors.buttonPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.progress > 0 ? progress.progress : null,
                    backgroundColor: OrbitColors.surfaceCream,
                    color: OrbitColors.buttonPrimary,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDownloadedProgress(progress),
                      style: TextStyle(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (progress.speedBytesPerSec > 0)
                      Text(
                        _formatSpeed(progress.speedBytesPerSec),
                        style: const TextStyle(
                          color: OrbitColors.buttonPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrbitColors.buttonPrimary,
                          foregroundColor: OrbitColors.textLight,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          // Cho phép người dùng quay lại app trong khi quá trình tải vẫn tiếp tục ngầm
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📥 Đang tiếp tục tải bản cập nhật trong nền. Bạn có thể thoải mái sử dụng app!'),
                              backgroundColor: OrbitColors.buttonPrimary,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text(
                          'Về App (Tải ngầm)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => UpdateService.instance.cancelDownload(),
                        child: const Text('Hủy tải', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ] else if (isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã tải xong bản cập nhật! 🎉',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Bấm nút bên dưới để mở trình cài đặt APK ngay.',
                              style: TextStyle(color: Colors.black54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 3,
                  ),
                  onPressed: () => UpdateService.instance.installCurrentApk(),
                  icon: const Icon(Icons.system_update_rounded, size: 20),
                  label: const Text(
                    '🚀 CÀI ĐẶT NGAY',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ] else if (isFailed) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          progress.errorMessage ?? 'Không thể tải tệp. Vui lòng thử lại!',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: OrbitColors.buttonPrimary,
                          foregroundColor: OrbitColors.textLight,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => UpdateService.instance.startBackgroundDownload(releaseInfo),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OrbitColors.deepOlive,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => UpdateService.instance.openReleasePage(releaseInfo.releasePageUrl),
                        child: const Text('Tải từ GitHub', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // TRẠNG THÁI IDLE: Nút Bắt đầu tải ngầm
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OrbitColors.surfaceCream,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.offline_bolt_rounded, size: 20, color: OrbitColors.buttonPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cập nhật ngầm: Khi bấm tải, hệ thống Android sẽ tải tệp trong nền. Bạn có thể ra ngoài app hoặc làm việc khác mà tiến trình tải vẫn duy trì hoàn toàn bình thường!',
                          style: TextStyle(
                            color: OrbitColors.deepOlive.withValues(alpha: 0.85),
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrbitColors.buttonPrimary,
                    foregroundColor: OrbitColors.textLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 3,
                  ),
                  onPressed: () {
                    UpdateService.instance.startBackgroundDownload(releaseInfo);
                  },
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text(
                    '🚀 BẮT ĐẦU TẢI VỀ NGẦM',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => UpdateService.instance.openReleasePage(releaseInfo.releasePageUrl),
                  child: Text(
                    'Mở liên kết tải trực tiếp trên GitHub',
                    style: TextStyle(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.65),
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDownloadedProgress(UpdateDownloadProgress p) {
    final downMb = (p.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (p.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    if (p.totalBytes > 0) {
      return '$downMb MB / $totalMb MB';
    }
    return '$downMb MB';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    final mbps = bytesPerSec / (1024 * 1024);
    if (mbps >= 1.0) {
      return '${mbps.toStringAsFixed(1)} MB/s';
    }
    final kbps = bytesPerSec / 1024;
    return '${kbps.toStringAsFixed(0)} KB/s';
  }
}
