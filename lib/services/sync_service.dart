import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:icnative/settings/global.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'friend_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  StreamSubscription<QuerySnapshot>? _postSubscription;
  final Set<String> _processedPostIds = {};
  static const _prefProcessedPostsKey = 'iconnative_processed_posts';

  /// Thông báo ảnh mới nhận từ bạn bè để HomeScreen hiển thị banner / toast tức thì
  final ValueNotifier<Map<String, dynamic>?> latestReceivedPhotoNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Bản đồ lưu ảnh mới nhất của từng người bạn (friendUid -> localFilePath)
  static final Map<String, String> friendLatestPhotos = {};
  static final ValueNotifier<int> friendPhotosChangeNotifier = ValueNotifier<int>(0);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefProcessedPostsKey) ?? [];
    _processedPostIds.addAll(list);

    if (Platform.isIOS) {
      try {
        await HomeWidget.setAppGroupId('group.com.abom.utas.utas');
      } catch (e) {
        debugPrint('Error setting iOS App Group ID: $e');
      }
    }

    if (AuthService.isCloudConfigured) {
      startListening();
    }
  }

  /// Nén ảnh về kích thước chuẩn sắc nét cho Widget (cạnh max 640px, JPEG q=75)
  /// và chuyển thành chuỗi Base64 nhẹ nhàng (~40KB - 70KB) để gửi qua Firestore (0 VNĐ, không cần Storage)
  static Future<String?> _compressImageToBase64(String localImagePath) async {
    try {
      return await compute((String path) {
        final file = File(path);
        if (!file.existsSync()) return null;
        final bytes = file.readAsBytesSync();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) return null;

        img.Image processed = decoded;
        final maxDim = max(decoded.width, decoded.height);
        if (maxDim > 640) {
          if (decoded.width >= decoded.height) {
            processed = img.copyResize(decoded, width: 640, interpolation: img.Interpolation.linear);
          } else {
            processed = img.copyResize(decoded, height: 640, interpolation: img.Interpolation.linear);
          }
        }

        // Mã hóa JPEG quality 75 cho chất lượng ảnh rất nét nhưng dung lượng siêu nhẹ
        final jpgBytes = img.encodeJpg(processed, quality: 75);
        return base64Encode(jpgBytes);
      }, localImagePath);
    } catch (e) {
      debugPrint('Error compressing image to Base64: $e');
      return null;
    }
  }

  /// Broadcast captured photo to all connected friends via Firestore (100% Free 0 VNĐ)
  Future<bool> broadcastPhotoToFriends({
    required String localImagePath,
    required String caption,
  }) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return false;

    // If Firebase is not configured, we gracefully return false
    if (!AuthService.isCloudConfigured) {
      debugPrint('Firebase not initialized. Running offline mode only.');
      return false;
    }

    try {
      final file = File(localImagePath);
      if (!file.existsSync()) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final postId = 'post_${myProfile.uid}_$now';

      // 1. Nén ảnh sang Base64 (~50KB) để lưu trực tiếp vào Firestore document (không cần Storage)
      final base64Image = await _compressImageToBase64(localImagePath);
      if (base64Image == null || base64Image.isEmpty) {
        debugPrint('Failed to compress image for broadcast.');
        return false;
      }

      // 2. Target audience = myself + all connected friends
      final friendUids = FriendService.instance.getFriendUids();
      final receiverIds = [myProfile.uid, ...friendUids];

      // 3. Save post record directly to Firestore (Spark Free 0 VNĐ)
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'id': postId,
        'senderId': myProfile.uid,
        'senderName': myProfile.displayName,
        'receiverIds': receiverIds,
        'imageBase64': base64Image,
        'caption': caption.trim(),
        'createdAt': now,
        'expireAt': now + (7 * 24 * 60 * 60 * 1000), // 7 days TTL
        'serverTimestamp': FieldValue.serverTimestamp(),
      });

      _processedPostIds.add(postId);
      _saveProcessedPostIds();
      debugPrint('🚀 Successfully broadcast photo to ${friendUids.length} friends via Firestore!');
      return true;
    } catch (e) {
      debugPrint('Broadcast Error: $e');
      return false;
    }
  }

  /// Listen for new photos sent by friends in real-time
  void startListening() {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null || !AuthService.isCloudConfigured) return;

    _postSubscription?.cancel();
    _postSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('receiverIds', arrayContains: myProfile.uid)
        .snapshots()
        .listen(
      (snapshot) async {
        final docs = snapshot.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data()['createdAt'] as num?)?.toInt() ?? 0;
            final bTime = (b.data()['createdAt'] as num?)?.toInt() ?? 0;
            return bTime.compareTo(aTime);
          });

        for (var doc in docs) {
          final data = doc.data();
          final postId = data['id'] as String? ?? doc.id;
          final senderId = data['senderId'] as String? ?? '';
          final senderName = data['senderName'] as String? ?? 'Bạn bè';
          final imageBase64 = data['imageBase64'] as String? ?? '';
          final imageUrl = data['imageUrl'] as String? ?? '';

          // Don't re-download my own posts or already processed posts
          if (senderId == myProfile.uid || _processedPostIds.contains(postId)) {
            continue;
          }

          if (imageBase64.isNotEmpty) {
            final ok = await _saveBase64AndApplyToWidget(postId, imageBase64, senderId, senderName);
            if (ok) {
              _processedPostIds.add(postId);
              _saveProcessedPostIds();
            }
          } else if (imageUrl.isNotEmpty) {
            final ok = await _downloadAndApplyToWidget(postId, imageUrl, senderId, senderName);
            if (ok) {
              _processedPostIds.add(postId);
              _saveProcessedPostIds();
            }
          }
        }
      },
      onError: (e) {
        debugPrint('Post sync listen error: $e');
      },
    );
  }

  /// Decode friend's Base64 photo and immediately update Home Widget & History
  Future<bool> _saveBase64AndApplyToWidget(
      String postId, String base64Data, String senderId, String senderName) async {
    try {
      final bytes = base64Decode(base64Data);
      final directory = await getApplicationDocumentsDirectory();
      final localFile = File('${directory.path}/friend_widget_$postId.jpg');
      await localFile.writeAsBytes(bytes);

      // 1. Add to History
      if (!images.contains(localFile.path)) {
        images.add(localFile.path);
      }

      // 2. Save sender metadata
      await savePhotoMetadata(localFile.path, senderName);

      // 3. Cache latest photo for this friend
      if (senderId.isNotEmpty) {
        friendLatestPhotos[senderId] = localFile.path;
        friendPhotosChangeNotifier.value++;
      }

      // 4. Immediately update Android / iOS Home Widgets
      await HomeWidget.saveWidgetData<String>('widget_image_path', localFile.path);
      await HomeWidget.saveWidgetData<String>('widget_sender_name', senderName);
      await updateAllHomeWidgets();

      // 5. Broadcast to HomeScreen toast
      latestReceivedPhotoNotifier.value = {
        'senderId': senderId,
        'senderName': senderName,
        'imagePath': localFile.path,
        'receivedAt': DateTime.now().millisecondsSinceEpoch,
      };

      debugPrint('✨ Updated Home Widgets with friend Base64 photo from $senderName: ${localFile.path}');
      return true;
    } catch (e) {
      debugPrint('Error saving friend Base64 photo: $e');
      return false;
    }
  }

  /// Download friend's photo and immediately update Home Widget & History
  Future<bool> _downloadAndApplyToWidget(
      String postId, String imageUrl, String senderId, String senderName) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final localFile = File('${directory.path}/friend_widget_$postId.png');
        await localFile.writeAsBytes(response.bodyBytes);

        // 1. Add to History
        if (!images.contains(localFile.path)) {
          images.add(localFile.path);
        }

        // 2. Save sender metadata
        await savePhotoMetadata(localFile.path, senderName);

        // 3. Cache latest photo for this friend
        if (senderId.isNotEmpty) {
          friendLatestPhotos[senderId] = localFile.path;
          friendPhotosChangeNotifier.value++;
        }

        // 4. Immediately update Android / iOS Home Widgets
        await HomeWidget.saveWidgetData<String>('widget_image_path', localFile.path);
        await HomeWidget.saveWidgetData<String>('widget_sender_name', senderName);
        await updateAllHomeWidgets();

        // 5. Broadcast to HomeScreen toast
        latestReceivedPhotoNotifier.value = {
          'senderId': senderId,
          'senderName': senderName,
          'imagePath': localFile.path,
          'receivedAt': DateTime.now().millisecondsSinceEpoch,
        };

        debugPrint('✨ Updated Home Widgets with friend photo from $senderName: ${localFile.path}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error downloading friend photo: $e');
      return false;
    }
  }

  static Future<void> updateAllHomeWidgets() async {
    try {
      await HomeWidget.updateWidget(
        name: 'ICNativeWidgetProvider',
        iOSName: 'OrbitWidget',
      );
      await HomeWidget.updateWidget(
        name: 'ICNativePebbleWidgetProvider',
        iOSName: 'OrbitWidget',
      );
    } catch (e) {
      debugPrint('Error updating home widgets: $e');
    }
  }

  static Future<void> savePhotoMetadata(String filePath, String senderName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sender_$filePath', senderName);
    } catch (_) {}
  }

  static Future<String> getPhotoSender(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('sender_$filePath');
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    if (filePath.contains('friend_widget_')) return 'Bạn bè';
    return 'Bạn';
  }

  Future<void> _saveProcessedPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefProcessedPostsKey, _processedPostIds.toList());
  }

  void dispose() {
    _postSubscription?.cancel();
  }
}
