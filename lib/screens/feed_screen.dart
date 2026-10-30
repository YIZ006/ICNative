import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:icnative/settings/global.dart';
import 'package:icnative/settings/theme_colors.dart';
import '../services/auth_service.dart';

class FriendsFeedScreen extends StatefulWidget {
  const FriendsFeedScreen({super.key});

  @override
  State<FriendsFeedScreen> createState() => _FriendsFeedScreenState();
}

class _FriendsFeedScreenState extends State<FriendsFeedScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    final myProfile = AuthService.instance.currentUser;

    if (Firebase.apps.isNotEmpty && myProfile != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('receiverIds', arrayContains: myProfile.uid)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get();

        _posts = snapshot.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        debugPrint('Error loading firestore feed: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return 'Vừa xong';
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  Future<void> _reactToPost(Map<String, dynamic> post, String emoji) async {
    final postId = post['id'] as String?;
    final myProfile = AuthService.instance.currentUser;
    if (postId == null || myProfile == null) return;

    if (Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(postId).update({
          'reactions.${myProfile.uid}': {
            'emoji': emoji,
            'userName': myProfile.displayName,
            'time': DateTime.now().millisecondsSinceEpoch,
          }
        });
        _loadFeed();
      } catch (e) {
        debugPrint('Error reacting to post: $e');
      }
    }
  }

  Future<void> _pinToHomeWidget(String? localPath, String? remoteUrl, String? senderName) async {
    if (localPath != null && File(localPath).existsSync()) {
      await HomeWidget.saveWidgetData<String>('widget_image_path', localPath);
      await HomeWidget.saveWidgetData<String>('widget_sender_name', senderName ?? 'Bạn bè');
      await HomeWidget.updateWidget(name: 'ICNativeWidgetProvider');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: OrbitColors.buttonPrimary),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã ghim ảnh của "${senderName ?? "bạn bè"}" lên Widget!')),
              ],
            ),
            backgroundColor: OrbitColors.deepOlive,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang hiển thị trên widget!'),
            backgroundColor: OrbitColors.deepOlive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrbitColors.background,
      appBar: AppBar(
        backgroundColor: OrbitColors.background,
        elevation: 0,
        title: const Text(
          'Bảng Tin Bạn Bè',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: OrbitColors.buttonPrimary),
            tooltip: 'Làm mới bảng tin',
            onPressed: _loadFeed,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: OrbitColors.buttonPrimary),
            )
          : _posts.isEmpty && images.isEmpty
              ? _buildEmptyState()
              : _buildFeedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: OrbitColors.surfaceCream,
                shape: BoxShape.circle,
                border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: OrbitColors.deepOlive.withValues(alpha: 0.08),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_chat_unread_outlined,
                size: 54,
                color: OrbitColors.buttonPrimary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chưa Có Ảnh Mới',
              style: TextStyle(
                color: OrbitColors.deepOlive,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Khi bạn hoặc bạn bè chụp ảnh và bấm "Gửi Widget", toàn bộ khoảnh khắc sẽ xuất hiện tại đây!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OrbitColors.deepOlive.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: OrbitColors.buttonPrimary,
                foregroundColor: OrbitColors.textLight,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text(
                'Chụp Ảnh Ngay',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList() {
    final hasOnlinePosts = _posts.isNotEmpty;
    final itemCount = hasOnlinePosts ? _posts.length : images.length;

    return RefreshIndicator(
      color: OrbitColors.buttonPrimary,
      backgroundColor: OrbitColors.background,
      onRefresh: _loadFeed,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          if (hasOnlinePosts) {
            return _buildOnlinePostCard(_posts[index]);
          } else {
            return _buildLocalPostCard(images[images.length - 1 - index]);
          }
        },
      ),
    );
  }

  Widget _buildOnlinePostCard(Map<String, dynamic> post) {
    final senderName = post['senderName'] as String? ?? 'Bạn bè';
    final imageUrl = post['imageUrl'] as String? ?? '';
    final caption = post['caption'] as String? ?? '';
    final createdAt = post['createdAt'] as int?;

    return Container(
      decoration: BoxDecoration(
        color: OrbitColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: OrbitColors.deepOlive.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: OrbitColors.buttonPrimary,
                  child: Text(
                    senderName.isNotEmpty ? senderName.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: OrbitColors.textLight, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          color: OrbitColors.deepOlive,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.widgets_outlined, color: OrbitColors.buttonPrimary),
                  tooltip: 'Ghim lên Home Widget',
                  onPressed: () => _pinToHomeWidget(null, imageUrl, senderName),
                ),
              ],
            ),
          ),

          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: OrbitColors.surfaceCream,
                        child: const Center(
                          child: CircularProgressIndicator(color: OrbitColors.buttonPrimary),
                        ),
                      );
                    },
                    errorBuilder: (ctx, err, stack) => Container(
                      color: OrbitColors.surfaceCream,
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                caption,
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildReactionButton('❤️', post),
                _buildReactionButton('🔥', post),
                _buildReactionButton('😂', post),
                _buildReactionButton('🥺', post),
                _buildReactionButton('🚀', post),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildLocalPostCard(String filePath) {
    final file = File(filePath);
    final exists = file.existsSync();

    return Container(
      decoration: BoxDecoration(
        color: OrbitColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: OrbitColors.deepOlive.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: OrbitColors.buttonPrimary,
                  child: Text('T', style: TextStyle(color: OrbitColors.textLight, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tôi (Kỷ niệm đã chụp)',
                        style: TextStyle(
                          color: OrbitColors.deepOlive,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        exists ? _formatFileTime(file) : 'Gần đây',
                        style: TextStyle(
                          color: OrbitColors.deepOlive.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.widgets_outlined, color: OrbitColors.buttonPrimary),
                  tooltip: 'Ghim lên Home Widget',
                  onPressed: () => _pinToHomeWidget(filePath, null, 'Tôi'),
                ),
              ],
            ),
          ),

          if (exists)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Image.file(
                    file,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          else
            Container(
              height: 200,
              color: OrbitColors.surfaceCream,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: OrbitColors.surfaceCream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: OrbitColors.buttonPrimary.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Đã đồng bộ Widget',
                    style: TextStyle(color: OrbitColors.buttonPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  String _formatFileTime(File file) {
    try {
      final stat = file.statSync();
      return _formatTime(stat.modified.millisecondsSinceEpoch);
    } catch (_) {
      return 'Vừa xong';
    }
  }

  Widget _buildReactionButton(String emoji, Map<String, dynamic> post) {
    final reactions = post['reactions'] as Map<String, dynamic>? ?? {};
    int count = 0;
    reactions.forEach((_, val) {
      if (val is Map && val['emoji'] == emoji) count++;
    });

    return InkWell(
      onTap: () => _reactToPost(post, emoji),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: count > 0 ? OrbitColors.surfaceCream : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: count > 0 ? OrbitColors.buttonPrimary.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  color: OrbitColors.deepOlive,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
