import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:icnative/services/locale_service.dart';
import 'package:icnative/services/sync_service.dart';
import 'package:icnative/settings/global.dart';
import 'package:icnative/settings/theme_colors.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onBackToCamera;

  const HistoryScreen({super.key, this.onBackToCamera});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: OrbitColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // 1. Tactile Quick-Pull & Drag Handle Bar (Độ nhạy cực cao để vuốt về Camera dễ dàng)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBackToCamera,
              onVerticalDragUpdate: (details) {
                // Chỉ cần vuốt xuống nhẹ 4px là lập tức trở về vòng tròn
                if (details.delta.dy > 4) {
                  widget.onBackToCamera?.call();
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: OrbitColors.deepOlive.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Top Bar of History with Back to Camera Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back to camera button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onBackToCamera,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: OrbitColors.buttonPrimary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: OrbitColors.deepOlive.withValues(alpha: 0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_upward_rounded, color: OrbitColors.textLight, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              tr('history_back_to_camera'),
                              style: const TextStyle(
                                color: OrbitColors.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    tr('history_title'),
                    style: const TextStyle(
                      color: OrbitColors.deepOlive,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Photo Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: OrbitColors.surfaceCream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${images.length} ${tr('history_photos_count')}',
                      style: const TextStyle(
                        color: OrbitColors.buttonPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pull down hint banner (Nhấn hoặc vuốt nhẹ)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBackToCamera,
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 4) {
                  widget.onBackToCamera?.call();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded,
                        size: 16, color: OrbitColors.deepOlive.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      tr('history_swipe_hint'),
                      style: TextStyle(
                        color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content: Empty State or Grid of Photos
            Expanded(
              child: images.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 64,
                            color: OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tr('history_empty_title'),
                            style: const TextStyle(
                              color: OrbitColors.deepOlive,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr('history_empty_subtitle'),
                            style: TextStyle(
                              color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: OrbitColors.buttonPrimary,
                              foregroundColor: OrbitColors.textLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: widget.onBackToCamera,
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: Text(tr('history_back_to_camera'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Nhận diện kéo xuống khi danh sách đang ở đỉnh: Lập tức quay về camera
                        if (notification is OverscrollNotification && notification.overscroll < -6) {
                          widget.onBackToCamera?.call();
                          return true;
                        }
                        if (notification is ScrollUpdateNotification) {
                          if (notification.metrics.pixels <= 0 &&
                              notification.scrollDelta != null &&
                              notification.scrollDelta! < -4) {
                            widget.onBackToCamera?.call();
                            return true;
                          }
                        }
                        return false;
                      },
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: images.length,
                        itemBuilder: (context, i) {
                          final reversedIndex = images.length - 1 - i;
                          final filePath = images[reversedIndex];
                          final file = File(filePath);
                          final isFriendPhoto = filePath.contains('friend_widget_');

                          return GestureDetector(
                            onTap: () => _openFullscreenViewer(filePath, reversedIndex),
                            child: Hero(
                              tag: 'history_img_$reversedIndex',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isFriendPhoto
                                        ? OrbitColors.terracotta
                                        : OrbitColors.buttonPrimary.withValues(alpha: 0.35),
                                    width: isFriendPhoto ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: OrbitColors.deepOlive.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(19),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (file.existsSync())
                                        Image.file(
                                          file,
                                          fit: BoxFit.cover,
                                        )
                                      else
                                        Container(
                                          color: OrbitColors.surfaceCream,
                                          child: const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                          ),
                                        ),

                                      // Sender Name Badge at Bottom of Card
                                      Positioned(
                                        bottom: 8,
                                        left: 8,
                                        right: 8,
                                        child: FutureBuilder<String>(
                                          future: SyncService.getPhotoSender(filePath),
                                          builder: (ctx, snap) {
                                            final senderName = snap.data ??
                                                (isFriendPhoto ? 'Bạn bè' : 'Tôi');
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: OrbitColors.deepOlive.withValues(alpha: 0.8),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isFriendPhoto
                                                      ? OrbitColors.terracotta
                                                      : OrbitColors.buttonPrimary,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isFriendPhoto
                                                        ? Icons.pets_rounded
                                                        : Icons.person_rounded,
                                                    size: 13,
                                                    color: OrbitColors.khakiGold,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      senderName,
                                                      style: const TextStyle(
                                                        color: OrbitColors.textLight,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreenViewer(String filePath, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      builder: (dialogCtx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          title: FutureBuilder<String>(
            future: SyncService.getPhotoSender(filePath),
            builder: (ctx, snap) {
              final name = snap.data ?? (filePath.contains('friend_widget_') ? 'Bạn bè' : 'Tôi');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: OrbitColors.deepOlive,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: OrbitColors.buttonPrimary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: OrbitColors.khakiGold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        color: OrbitColors.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          centerTitle: true,
          actions: [
            // Button: Pin to Home Widget
            IconButton(
              icon: const Icon(Icons.widgets_rounded, color: OrbitColors.khakiGold),
              tooltip: 'Ghim lên màn hình chính',
              onPressed: () async {
                final senderName = await SyncService.getPhotoSender(filePath);
                await HomeWidget.saveWidgetData<String>('widget_image_path', filePath);
                await HomeWidget.saveWidgetData<String>('widget_sender_name', senderName);
                await SyncService.updateAllHomeWidgets();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: OrbitColors.buttonPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Đã ghim ảnh của "$senderName" lên Widget!'),
                          ),
                        ],
                      ),
                      backgroundColor: OrbitColors.deepOlive,
                    ),
                  );
                }
              },
            ),

            // Button: Delete photo
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent.withValues(alpha: 0.9)),
              tooltip: 'Xóa ảnh',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: dialogCtx,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: OrbitColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Xóa ảnh này?',
                        style: TextStyle(color: OrbitColors.deepOlive, fontSize: 16, fontWeight: FontWeight.bold)),
                    content: const Text(
                      'Ảnh sẽ bị xóa hoàn toàn khỏi máy và Widget màn hình chính sẽ được cập nhật.',
                      style: TextStyle(color: OrbitColors.deepOlive, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy', style: TextStyle(color: OrbitColors.deepOlive)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    final f = File(filePath);
                    if (f.existsSync()) f.deleteSync();
                  } catch (_) {}

                  setState(() {
                    images.remove(filePath);
                  });

                  String nextImagePath = '';
                  String nextSenderName = '';
                  if (images.isNotEmpty) {
                    nextImagePath = images.last;
                    nextSenderName = await SyncService.getPhotoSender(nextImagePath);
                  }

                  await HomeWidget.saveWidgetData<String>('widget_image_path', nextImagePath);
                  await HomeWidget.saveWidgetData<String>('widget_sender_name', nextSenderName);
                  await SyncService.updateAllHomeWidgets();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(images.isNotEmpty
                            ? 'Đã xóa ảnh! Widget đã cập nhật sang ảnh tiếp theo.'
                            : 'Đã xóa ảnh! Widget đã làm trống.'),
                        backgroundColor: OrbitColors.deepOlive,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }

                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                }
              },
            ),
          ],
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 3.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: File(filePath).existsSync()
                  ? Image.file(
                      File(filePath),
                      fit: BoxFit.contain,
                    )
                  : const Icon(Icons.broken_image, size: 80, color: Colors.white38),
            ),
          ),
        ),
      ),
    );
  }
}
