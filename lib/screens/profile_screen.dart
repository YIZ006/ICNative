import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:icnative/settings/global.dart';
import 'package:icnative/settings/theme_colors.dart';
import '../services/auth_service.dart';
import '../services/locale_service.dart';
import '../services/update_service.dart';
import 'qr_scanner_screen.dart';
import 'widget_guide_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: AuthService.instance.currentUserNotifier,
      builder: (context, user, _) {
        final isCloudActive = Firebase.apps.isNotEmpty;
        final avatarPath = user?.avatarPath;
        final hasCustomAvatar = avatarPath != null && File(avatarPath).existsSync();

        return Scaffold(
          backgroundColor: OrbitColors.background,
          appBar: AppBar(
            backgroundColor: OrbitColors.background,
            elevation: 0,
            title: const Text(
              'Cài Đặt Tài Khoản',
              style: TextStyle(
                color: OrbitColors.deepOlive,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: OrbitColors.deepOlive),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // User Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: OrbitColors.surfaceCard,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: OrbitColors.buttonPrimary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.1),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar with Change Avatar badge
                      GestureDetector(
                        onTap: _showChangeAvatarModal,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: OrbitColors.buttonPrimary,
                                border: Border.all(color: OrbitColors.background, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: OrbitColors.deepOlive.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: hasCustomAvatar
                                    ? Image.file(
                                        File(avatarPath),
                                        fit: BoxFit.cover,
                                        width: 84,
                                        height: 84,
                                      )
                                    : const Center(
                                        child: Text('🐾', style: TextStyle(fontSize: 40)),
                                      ),
                              ),
                            ),

                            // Camera edit badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: OrbitColors.buttonPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showChangeAvatarModal,
                        child: const Text(
                          'Đổi ảnh đại diện',
                          style: TextStyle(
                            color: OrbitColors.buttonPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Display Name with edit icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user?.displayName ?? 'Chưa đặt tên',
                              style: const TextStyle(
                                color: OrbitColors.deepOlive,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: OrbitColors.buttonPrimary),
                            tooltip: 'Đổi tên hiển thị',
                            onPressed: _showEditNameDialog,
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // User ID with copy button
                      InkWell(
                        onTap: () {
                          if (user != null) {
                            Clipboard.setData(ClipboardData(text: user.uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép User ID vào bộ nhớ tạm!'),
                                duration: Duration(seconds: 2),
                                backgroundColor: OrbitColors.deepOlive,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ID: ${user?.uid ?? "---"}',
                                style: TextStyle(
                                  color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Cloud Sync Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCloudActive
                              ? const Color(0xFF55A33C).withValues(alpha: 0.15)
                              : OrbitColors.terracotta.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCloudActive
                                ? const Color(0xFF55A33C)
                                : OrbitColors.terracotta,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCloudActive ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                              size: 16,
                              color: isCloudActive ? const Color(0xFF388E3C) : OrbitColors.terracotta,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCloudActive ? 'Cloud Sync Đang Hoạt Động (0 VNĐ)' : 'Chế độ Cục bộ (Offline)',
                              style: TextStyle(
                                color: isCloudActive ? const Color(0xFF388E3C) : OrbitColors.terracotta,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // GitHub Releases & Update Card
                _buildActionCard(
                  icon: Icons.system_update_alt_rounded,
                  iconColor: OrbitColors.buttonPrimary,
                  title: 'Phiên Bản & Bản Cập Nhật',
                  subtitle: 'Phiên bản hiện tại: Orbit v${UpdateService.currentVersion}. Mở trực tiếp trang phát hành GitHub để tải APK/IPA mới.',
                  buttonText: 'Mở GitHub Releases 🌐',
                  onTap: () async {
                    await UpdateService.instance.openReleasePage();
                  },
                ),

                const SizedBox(height: 16),

                // Card: Hướng Dẫn & Ghim Nhanh Widget Màn Hình
                _buildActionCard(
                  icon: Icons.widgets_rounded,
                  iconColor: OrbitColors.buttonPrimary,
                  title: tr('wg_title'),
                  subtitle: tr('wg_subtitle'),
                  buttonText: 'Xem & Ghim Nhanh 1-Chạm 📌',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const WidgetGuideScreen()),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Card: Đổi Ngôn Ngữ Nhanh 1-Chạm (Bilingual VI / EN)
                ValueListenableBuilder<AppLanguage>(
                  valueListenable: LocaleService.instance.currentLanguage,
                  builder: (context, lang, _) {
                    final isVi = lang == AppLanguage.vi;
                    return _buildActionCard(
                      icon: Icons.translate_rounded,
                      iconColor: OrbitColors.deepOlive,
                      title: tr('language_setting'),
                      subtitle: isVi
                          ? 'Ngôn ngữ hiện tại: Tiếng Việt 🇻🇳. Tự động nhận diện theo máy.'
                          : 'Current Language: English 🇬🇧. Auto-detected from system.',
                      buttonText: isVi ? 'Chuyển sang English 🇬🇧' : 'Đổi sang Tiếng Việt 🇻🇳',
                      onTap: () async {
                        await LocaleService.instance.toggleLanguage();
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Card: Chế độ Trải Nghiệm Mẫu (30 Bạn Bè)
                ValueListenableBuilder<bool>(
                  valueListenable: isDemoModeNotifier,
                  builder: (context, isDemo, _) {
                    return _buildActionCard(
                      icon: isDemo ? Icons.groups_rounded : Icons.person_outline_rounded,
                      iconColor: isDemo ? OrbitColors.terracotta : OrbitColors.deepOlive,
                      title: tr('demo_mode_title'),
                      subtitle: tr('demo_mode_subtitle'),
                      buttonText: isDemo ? 'Đang Bật (Chạm để Tắt Demo)' : 'Đang Tắt (Chạm để Bật Demo 30 Bạn)',
                      onTap: () {
                        isDemoModeNotifier.value = !isDemo;
                      },
                    );
                  },
                ),

                const SizedBox(height: 22),

                // Section: Backup & Login with QR
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SAO LƯU & ĐĂNG NHẬP LẠI',
                    style: TextStyle(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Action Card 1: View Backup QR
                _buildActionCard(
                  icon: Icons.qr_code_2_rounded,
                  iconColor: OrbitColors.buttonPrimary,
                  title: 'Mã Khôi Phục Tài Khoản',
                  subtitle: 'Hiển thị mã QR bí mật để đăng nhập lại trên thiết bị khác hoặc khi đổi máy.',
                  buttonText: 'Xem Mã Đăng Nhập',
                  onTap: _showBackupQrModal,
                ),

                const SizedBox(height: 12),

                // Action Card 2: Restore from Backup QR
                _buildActionCard(
                  icon: Icons.login_rounded,
                  iconColor: OrbitColors.buttonPrimary,
                  title: 'Đăng Nhập Bằng Mã QR',
                  subtitle: 'Quét mã khôi phục từ máy cũ để lấy lại tài khoản và danh sách bạn bè.',
                  buttonText: 'Quét Mã Đăng Nhập',
                  onTap: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const QRScannerScreen(
                          mode: ScannerMode.backupLogin,
                        ),
                      ),
                    );
                    if (result == true && mounted) {
                      setState(() {});
                    }
                  },
                ),

                const SizedBox(height: 22),

                // Help info note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OrbitColors.surfaceCream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: OrbitColors.buttonPrimary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tài khoản của bạn hoàn toàn ẩn danh, không cần email hay số điện thoại. Chỉ cần lưu lại "Mã Khôi Phục Tài Khoản" là bạn có thể đăng nhập lại bất cứ lúc nào.',
                          style: TextStyle(
                            color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showChangeAvatarModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: OrbitColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33283618),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Chọn Ảnh Đại Diện Mới',
                style: TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OrbitColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: OrbitColors.buttonPrimary),
                ),
                title: const Text('Chọn từ Thư viện ảnh', style: TextStyle(color: OrbitColors.deepOlive, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tải ảnh từ bộ sưu tập trên máy', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 600,
                    maxHeight: 600,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    await AuthService.instance.updateAvatar(picked.path);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: OrbitColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: OrbitColors.buttonPrimary),
                ),
                title: const Text('Chụp ảnh mới', style: TextStyle(color: OrbitColors.deepOlive, fontWeight: FontWeight.bold)),
                subtitle: const Text('Mở camera chụp ảnh chân dung ngay', style: TextStyle(fontSize: 11, color: Colors.grey)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 600,
                    maxHeight: 600,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    await AuthService.instance.updateAvatar(picked.path);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrbitColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: OrbitColors.deepOlive.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: OrbitColors.deepOlive.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: OrbitColors.buttonPrimary,
                side: const BorderSide(color: OrbitColors.buttonPrimary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    final user = AuthService.instance.currentUser;
    final controller = TextEditingController(text: user?.displayName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OrbitColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Đổi Tên Hiển Thị',
            style: TextStyle(color: OrbitColors.deepOlive, fontSize: 17, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: OrbitColors.deepOlive, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Nhập tên mới...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: OrbitColors.buttonPrimary)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: OrbitColors.deepOlive, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: OrbitColors.deepOlive)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OrbitColors.buttonPrimary,
              foregroundColor: OrbitColors.textLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await AuthService.instance.updateDisplayName(newName);
                if (mounted) setState(() {});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBackupQrModal() {
    final user = AuthService.instance.currentUser;
    final backupPayload = AuthService.instance.generateBackupQrPayload();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: OrbitColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33283618),
              blurRadius: 25,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: OrbitColors.deepOlive.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: OrbitColors.buttonPrimary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Mã Khôi Phục Tài Khoản',
                  style: TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quét mã này trên máy mới để đăng nhập lại tài khoản "${user?.displayName}". Hãy bảo mật mã này!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: OrbitColors.surfaceCream,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.35)),
              ),
              child: QrImageView(
                data: backupPayload.isNotEmpty ? backupPayload : 'error',
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.transparent,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: OrbitColors.deepOlive,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: OrbitColors.deepOlive,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'UID: ${user?.uid ?? ""}',
              style: TextStyle(
                color: OrbitColors.deepOlive.withValues(alpha: 0.5),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrbitColors.buttonPrimary,
                  foregroundColor: OrbitColors.textLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu & Đóng', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
