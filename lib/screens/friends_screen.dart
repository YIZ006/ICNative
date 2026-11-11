import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:icnative/settings/theme_colors.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import '../services/invite_service.dart';
import '../services/secret_photo_service.dart';
import 'qr_scanner_screen.dart';
import 'scratch_photo_screen.dart';
import 'soulmate_screen.dart';
import 'story_templates_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    FriendService.instance.friendsCountNotifier.addListener(_onFriendsUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(InviteService.instance.checkClipboardForInvite(silent: true));
    });
  }

  @override
  void dispose() {
    FriendService.instance.friendsCountNotifier.removeListener(_onFriendsUpdated);
    super.dispose();
  }

  void _onFriendsUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _showPasteInviteLinkDialog() async {
    String initialText = '';
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clip?.text?.trim() ?? '';
      final parsed = InviteService.parseInviteInput(text);
      if (parsed != null && parsed.uid != AuthService.instance.currentUser?.uid) {
        initialText = text;
      }
    } catch (_) {}

    if (!mounted) return;
    final textController = TextEditingController(text: initialText);

    await showDialog(
      context: context,
      builder: (dCtx) {
        return AlertDialog(
          backgroundColor: OrbitColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.add_link_rounded, color: OrbitColors.buttonPrimary, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kết Bạn Bằng Link / UID',
                  style: TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dán đường link kết bạn bạn bè gửi cho bạn (hoặc mã UID của họ) để kết nối thẳng vào vòng tròn Orbit:',
                style: TextStyle(
                  color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                autofocus: initialText.isEmpty,
                style: const TextStyle(color: OrbitColors.deepOlive, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://ncnative-bcf6d.web.app/invite?uid=...',
                  hintStyle: TextStyle(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: OrbitColors.surfaceCream,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: OrbitColors.buttonPrimary.withValues(alpha: 0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: OrbitColors.buttonPrimary.withValues(alpha: 0.4)),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Dán từ bộ nhớ tạm',
                    icon: const Icon(Icons.content_paste_rounded, color: OrbitColors.buttonPrimary, size: 20),
                    onPressed: () async {
                      final clip = await Clipboard.getData(Clipboard.kTextPlain);
                      if (clip?.text != null) {
                        textController.text = clip!.text!.trim();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Hủy', style: TextStyle(color: OrbitColors.deepOlive)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: OrbitColors.buttonPrimary,
                foregroundColor: OrbitColors.textLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () async {
                final input = textController.text.trim();
                final payload = InviteService.parseInviteInput(input);
                if (payload == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Link hoặc mã UID không hợp lệ. Vui lòng kiểm tra lại!'),
                      backgroundColor: OrbitColors.terracotta,
                    ),
                  );
                  return;
                }
                Navigator.pop(dCtx);
                await InviteService.instance.connectFromPayload(payload, notifyGlobal: true);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Kết Bạn Ngay', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final friendQrPayload = AuthService.instance.generateFriendQrPayload();
    final myInviteLink = InviteService.instance.generateInviteLink();
    final friends = FriendService.instance.friends;

    return Scaffold(
      backgroundColor: OrbitColors.background,
      appBar: AppBar(
        backgroundColor: OrbitColors.background,
        elevation: 0,
        title: const Text(
          'Bạn Bè & Kết Nối',
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
            // Card: My Friend QR Code (Bưu thiếp bưu chính cổ điển mộc mạc)
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
                  const Text(
                    'MÃ KẾT BẠN CỦA TÔI',
                    style: TextStyle(
                      color: OrbitColors.deepOlive,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đưa mã này để bạn bè quét và kết nối widget!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // QR Image on subtle cream box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: OrbitColors.surfaceCream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: QrImageView(
                      data: friendQrPayload.isNotEmpty ? friendQrPayload : 'error',
                      version: QrVersions.auto,
                      size: 180.0,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: OrbitColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          user?.displayName ?? 'Tôi',
                          style: const TextStyle(
                            color: OrbitColors.textLight,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(UID: ${user?.uid ?? ""})',
                        style: TextStyle(
                          color: OrbitColors.deepOlive.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(color: OrbitColors.buttonPrimary.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 14),

                  // Phần Kết Bạn Qua Link (Nối trực tiếp với tài khoản hiện tại)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link_rounded, size: 16, color: OrbitColors.buttonPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'LINK KẾT BẠN CỦA TÔI (BẤM VÀO LÀ KẾT BẠN)',
                        style: TextStyle(
                          color: OrbitColors.deepOlive.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await InviteService.instance.copyInviteLinkToClipboard();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã sao chép link kết bạn! Gửi cho bạn bè bấm vào là kết bạn ngay.'),
                            backgroundColor: OrbitColors.buttonPrimary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: OrbitColors.surfaceCream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              myInviteLink,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: OrbitColors.deepOlive,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: OrbitColors.buttonPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: OrbitColors.buttonPrimary,
                            foregroundColor: OrbitColors.textLight,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final shared = await InviteService.instance.shareInviteLink();
                            if (!shared && mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Đã sao chép link kết bạn vào bộ nhớ tạm!'),
                                  backgroundColor: OrbitColors.buttonPrimary,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text(
                            'GỬI LINK KẾT BẠN',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OrbitColors.deepOlive,
                            side: const BorderSide(color: OrbitColors.buttonPrimary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: OrbitColors.surfaceCream,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await InviteService.instance.copyInviteLinkToClipboard();
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Đã sao chép link kết bạn!'),
                                  backgroundColor: OrbitColors.buttonPrimary,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.content_copy_rounded, size: 16),
                          label: const Text(
                            'Sao chép',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Hàng nút hành động: Quét Mã Bạn Bè & Dán Link Kết Bạn
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OrbitColors.buttonPrimary,
                        foregroundColor: OrbitColors.textLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 3,
                        shadowColor: OrbitColors.deepOlive.withValues(alpha: 0.3),
                      ),
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const QRScannerScreen(
                              mode: ScannerMode.addFriend,
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text(
                        'QUÉT MÃ QR',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OrbitColors.deepOlive,
                        backgroundColor: OrbitColors.surfaceCard,
                        side: const BorderSide(color: OrbitColors.buttonPrimary, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onPressed: _showPasteInviteLinkDialog,
                      icon: const Icon(Icons.add_link_rounded, size: 22, color: OrbitColors.buttonPrimary),
                      label: const Text(
                        'DÁN LINK BẠN BÈ',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // VIRAL GROWTH SECTION: 3 TÍNH NĂNG KÉO BẠN TỪ LOCKET
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrbitColors.deepOlive,
                      side: const BorderSide(color: Color(0xFF00B4D8), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFF00B4D8).withValues(alpha: 0.08),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StoryTemplatesScreen()),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF0077B6), size: 18),
                    label: const Text(
                      '10 Story Mẫu',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrbitColors.deepOlive,
                      side: const BorderSide(color: Color(0xFFFF3366), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFFFF3366).withValues(alpha: 0.08),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SoulmateScreen()),
                      );
                    },
                    icon: const Icon(Icons.favorite, color: Color(0xFFFF3366), size: 18),
                    label: const Text(
                      'Cận tâm #1',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OrbitColors.deepOlive,
                      side: const BorderSide(color: Color(0xFF7209B7), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: const Color(0xFF7209B7).withValues(alpha: 0.08),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScratchPhotoScreen(
                            secretPhoto: SecretPhoto(
                              id: 'demo_secret_${DateTime.now().millisecondsSinceEpoch}',
                              senderUid: user?.uid ?? 'me',
                              senderName: user?.displayName ?? 'Tôi',
                              imagePath: '',
                              teaserMessage: 'Tao vừa gửi cho mày 1 tấm ảnh bí mật trên Orbit 🤫',
                              createdAt: DateTime.now().millisecondsSinceEpoch,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.touch_app, color: Color(0xFF7209B7), size: 18),
                    label: const Text(
                      'Cào ảnh 🤫',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),

            // SECTION: LỜI MỜI KẾT BẠN ĐANG CHỜ (REAL-TIME FRIEND REQUESTS)
            ValueListenableBuilder<List<FriendRequest>>(
              valueListenable: FriendService.instance.pendingRequestsNotifier,
              builder: (context, pendingList, _) {
                if (pendingList.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '💌 Lời Mời Kết Bạn Đang Chờ',
                          style: TextStyle(
                            color: OrbitColors.deepOlive,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingList.length}',
                            style: const TextStyle(
                              color: OrbitColors.deepOlive,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingList.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final req = pendingList[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: OrbitColors.surfaceCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFFFD54F),
                                child: Text(
                                  req.fromName.isNotEmpty
                                      ? req.fromName.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: OrbitColors.deepOlive,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.fromName,
                                      style: const TextStyle(
                                        color: OrbitColors.deepOlive,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Muốn kết bạn trên Orbit',
                                      style: TextStyle(
                                        color: OrbitColors.deepOlive.withValues(alpha: 0.65),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: OrbitColors.buttonPrimary,
                                  foregroundColor: OrbitColors.textLight,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final success = await FriendService.instance.acceptFriendRequest(req);
                                  if (success && mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('🎉 Đã kết bạn với ${req.fromName}! Cả 2 đã ở trên vòng tròn của nhau.'),
                                        backgroundColor: OrbitColors.deepOlive,
                                      ),
                                    );
                                    setState(() {});
                                  }
                                },
                                child: const Text('Chấp nhận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.close, size: 18, color: OrbitColors.deepOlive.withValues(alpha: 0.5)),
                                onPressed: () async {
                                  await FriendService.instance.declineFriendRequest(req);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // Section Header: Connected Friends
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bạn Bè Đang Kết Nối (${friends.length})',
                  style: const TextStyle(
                    color: OrbitColors.deepOlive,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (friends.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      await FriendService.instance.syncFriendsFromFirestore();
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.refresh, size: 16, color: OrbitColors.buttonPrimary),
                    label: const Text(
                      'Đồng bộ',
                      style: TextStyle(color: OrbitColors.buttonPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Friends List or Empty state
            if (friends.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: OrbitColors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 48,
                      color: OrbitColors.buttonPrimary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Chưa có bạn bè nào',
                      style: TextStyle(
                        color: OrbitColors.deepOlive,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hãy quét mã QR của nhau để bắt đầu chia sẻ khoảnh khắc lên Widget!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: friends.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final friend = friends[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: OrbitColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: OrbitColors.deepOlive.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: OrbitColors.buttonPrimary,
                          child: Text(
                            friend.displayName.isNotEmpty
                                ? friend.displayName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: OrbitColors.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.displayName,
                                style: const TextStyle(
                                  color: OrbitColors.deepOlive,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'UID: ${friend.uid}',
                                style: TextStyle(
                                  color: OrbitColors.deepOlive.withValues(alpha: 0.5),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: OrbitColors.terracotta.withValues(alpha: 0.8),
                            size: 20,
                          ),
                          tooltip: 'Hủy kết bạn',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                backgroundColor: OrbitColors.background,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Hủy kết bạn?', style: TextStyle(color: OrbitColors.deepOlive, fontSize: 16, fontWeight: FontWeight.bold)),
                                content: Text(
                                  'Bạn có chắc muốn hủy kết nối với "${friend.displayName}" không? Cả hai sẽ ngừng chia sẻ ảnh widget.',
                                  style: TextStyle(color: OrbitColors.deepOlive.withValues(alpha: 0.8), fontSize: 13),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Hủy', style: TextStyle(color: OrbitColors.deepOlive)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Xóa', style: TextStyle(color: OrbitColors.terracotta, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await FriendService.instance.removeFriend(friend.uid);
                              if (mounted) setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
