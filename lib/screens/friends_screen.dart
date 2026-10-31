import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:icnative/settings/theme_colors.dart';
import '../services/auth_service.dart';
import '../services/friend_service.dart';
import 'qr_scanner_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final friendQrPayload = AuthService.instance.generateFriendQrPayload();
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
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Button: Scan Friend's QR Code
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OrbitColors.buttonPrimary,
                  foregroundColor: OrbitColors.textLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
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
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                label: const Text(
                  'QUÉT MÃ BẠN BÈ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
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
