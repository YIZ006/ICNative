import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
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

    if (Firebase.apps.isNotEmpty) {
      startListening();
    }
  }

  /// Broadcast captured photo to all connected friends
  Future<bool> broadcastPhotoToFriends({
    required String localImagePath,
    required String caption,
  }) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return false;

    // If Firebase is not configured, we gracefully return false
    if (Firebase.apps.isEmpty) {
      debugPrint('Firebase not initialized. Running offline mode only.');
      return false;
    }

    try {
      final file = File(localImagePath);
      if (!file.existsSync()) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final postId = 'post_${myProfile.uid}_$now';

      // 1. Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child('$postId.png');

      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/png'),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // 2. Target audience = myself + all connected friends
      final friendUids = FriendService.instance.getFriendUids();
      final receiverIds = [myProfile.uid, ...friendUids];

      // 3. Save post record to Firestore
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        'id': postId,
        'senderId': myProfile.uid,
        'senderName': myProfile.displayName,
        'receiverIds': receiverIds,
        'imageUrl': downloadUrl,
        'caption': caption.trim(),
        'createdAt': now,
        'serverTimestamp': FieldValue.serverTimestamp(),
      });

      _processedPostIds.add(postId);
      debugPrint('🚀 Successfully broadcast photo to ${friendUids.length} friends!');
      return true;
    } catch (e) {
      debugPrint('Broadcast Error: $e');
      return false;
    }
  }

  /// Listen for new photos sent by friends in real-time
  void startListening() {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null || Firebase.apps.isEmpty) return;

    _postSubscription?.cancel();
    _postSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('receiverIds', arrayContains: myProfile.uid)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen(
      (snapshot) async {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data == null) continue;

            final postId = data['id'] as String? ?? change.doc.id;
            final senderId = data['senderId'] as String? ?? '';
            final senderName = data['senderName'] as String? ?? 'Bạn bè';
            final imageUrl = data['imageUrl'] as String? ?? '';

            // Don't re-download my own posts or already processed posts
            if (senderId == myProfile.uid || _processedPostIds.contains(postId)) {
              continue;
            }

            _processedPostIds.add(postId);
            _saveProcessedPostIds();

            if (imageUrl.isNotEmpty) {
              await _downloadAndApplyToWidget(postId, imageUrl, senderName);
            }
          }
        }
      },
      onError: (e) {
        debugPrint('Post sync listen error: $e');
      },
    );
  }

  /// Download friend's photo and immediately update Home Widget & History
  Future<void> _downloadAndApplyToWidget(String postId, String imageUrl, String senderName) async {
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

        // 3. Immediately update Android / iOS Home Widgets (Kiểu 10 Galaxy & Kiểu 3 Pebble)
        await HomeWidget.saveWidgetData<String>('widget_image_path', localFile.path);
        await HomeWidget.saveWidgetData<String>('widget_sender_name', senderName);
        await updateAllHomeWidgets();

        debugPrint('✨ Updated Home Widgets with friend photo from $senderName: ${localFile.path}');
      }
    } catch (e) {
      debugPrint('Error downloading friend photo: $e');
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
