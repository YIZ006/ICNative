import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'sync_service.dart';

class Friend {
  final String uid;
  final String displayName;
  final int addedAt;
  final String? avatarBase64;

  Friend({
    required this.uid,
    required this.displayName,
    required this.addedAt,
    this.avatarBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'addedAt': addedAt,
      if (avatarBase64 != null && avatarBase64!.isNotEmpty)
        'avatarBase64': avatarBase64,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Bạn bè',
      addedAt: (map['addedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      avatarBase64: map['avatarBase64'] as String?,
    );
  }
}

class FriendRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String status; // 'pending', 'accepted', 'declined'
  final int createdAt;
  final String? fromAvatarBase64;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    required this.createdAt,
    this.fromAvatarBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'status': status,
      'createdAt': createdAt,
      if (fromAvatarBase64 != null && fromAvatarBase64!.isNotEmpty)
        'fromAvatarBase64': fromAvatarBase64,
    };
  }

  factory FriendRequest.fromMap(Map<String, dynamic> map, [String? docId]) {
    return FriendRequest(
      id: docId ?? (map['id'] as String? ?? ''),
      fromUid: map['fromUid'] as String? ?? '',
      fromName: map['fromName'] as String? ?? 'Bạn bè',
      toUid: map['toUid'] as String? ?? '',
      toName: map['toName'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      fromAvatarBase64: map['fromAvatarBase64'] as String?,
    );
  }
}

enum FriendAddResult {
  requestSent,
  alreadyFriends,
  acceptedImmediately,
  selfError,
  networkError,
}

class FriendService {
  static final FriendService instance = FriendService._internal();
  FriendService._internal();

  static const _prefFriendsKey = 'iconnative_friends_list';
  final List<Friend> _friends = [];
  List<Friend> get friends => List.unmodifiable(_friends);

  final ValueNotifier<int> friendsCountNotifier = ValueNotifier<int>(0);

  /// Thông báo mỗi khi danh sách bạn bè hoặc avatar của bạn bè có thay đổi mới
  final ValueNotifier<int> friendsUpdatedNotifier = ValueNotifier<int>(0);

  /// Danh sách lời mời kết bạn đang chờ người dùng phản hồi
  final ValueNotifier<List<FriendRequest>> pendingRequestsNotifier =
      ValueNotifier<List<FriendRequest>>([]);

  /// Thông báo banner khi lời mời kết bạn được người kia chấp nhận
  final ValueNotifier<String?> newFriendAcceptedToastNotifier =
      ValueNotifier<String?>(null);

  StreamSubscription<QuerySnapshot>? _incomingRequestsSub;
  StreamSubscription<QuerySnapshot>? _outgoingRequestsSub;
  StreamSubscription<QuerySnapshot>? _friendsRealtimeSub;

  /// Khởi tạo và đồng bộ bạn bè từ cache & Firestore
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefFriendsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
        _friends.clear();
        for (var item in list) {
          _friends.add(Friend.fromMap(item as Map<String, dynamic>));
        }
        friendsCountNotifier.value = _friends.length;
      } catch (e) {
        debugPrint('Error loading cached friends: $e');
      }
    }

    if (AuthService.isCloudConfigured) {
      startRealtimeSync();
      unawaited(syncAllFriendsAvatars());
    }
  }

  /// Khởi động các luồng lắng nghe thời gian thực (Real-time Firestore Listeners)
  void startRealtimeSync() {
    final myUid = AuthService.instance.currentUser?.uid;
    if (myUid == null || !AuthService.isCloudConfigured) return;

    // 1. Lắng nghe danh sách bạn bè 2 chiều (Khi đối phương chấp nhận hoặc kết nối qua QR, bạn bè tự động xuất hiện trên vòng tròn)
    _friendsRealtimeSub?.cancel();
    _friendsRealtimeSub = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .snapshots()
        .listen(
      (snapshot) async {
        // Tránh lỗi xóa nhầm bạn bè khi cache cục bộ vừa mở chưa kịp load từ cloud
        if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty && _friends.isNotEmpty) {
          debugPrint('Skipping empty cache snapshot for friends');
          return;
        }

        final List<Friend> updated = [];
        for (var doc in snapshot.docs) {
          final incoming = Friend.fromMap(doc.data());
          final existing = _friends.firstWhere(
            (x) => x.uid == incoming.uid,
            orElse: () => incoming,
          );
          final b64 = (incoming.avatarBase64 != null && incoming.avatarBase64!.isNotEmpty)
              ? incoming.avatarBase64
              : existing.avatarBase64;
          updated.add(Friend(
            uid: incoming.uid,
            displayName: incoming.displayName,
            addedAt: incoming.addedAt,
            avatarBase64: b64,
          ));
        }
        _friends.clear();
        _friends.addAll(updated);
        friendsCountNotifier.value = _friends.length;
        friendsUpdatedNotifier.value++;
        await _saveToCache();
        debugPrint('🪐 Realtime friends updated: ${_friends.length} friends on orbit');
        unawaited(syncAllFriendsAvatars());
      },
      onError: (e) {
        debugPrint('Realtime friends sync error: $e');
      },
    );

    // 2. Lắng nghe lời mời kết bạn gửi ĐẾN tài khoản hiện tại
    _incomingRequestsSub?.cancel();
    _incomingRequestsSub = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUid', isEqualTo: myUid)
        .snapshots()
        .listen(
      (snapshot) {
        final List<FriendRequest> pending = [];
        for (var doc in snapshot.docs) {
          final req = FriendRequest.fromMap(doc.data(), doc.id);
          if (req.status == 'pending') {
            pending.add(req);
          }
        }
        pendingRequestsNotifier.value = pending;
        debugPrint('💌 Pending incoming friend requests: ${pending.length}');
      },
      onError: (e) {
        debugPrint('Friend requests listen error: $e');
      },
    );

    // 3. Lắng nghe lời mời kết bạn DO TÔI GỬI ĐI xem đối phương đã chấp nhận chưa
    _outgoingRequestsSub?.cancel();
    _outgoingRequestsSub = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUid', isEqualTo: myUid)
        .snapshots()
        .listen(
      (snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            final data = change.doc.data();
            if (data != null && data['status'] == 'accepted') {
              final toName = data['toName'] as String? ?? 'Bạn bè';
              newFriendAcceptedToastNotifier.value = toName;
              debugPrint('🎉 $toName accepted your friend request!');
            }
          }
        }
      },
      onError: (e) {
        debugPrint('Outgoing request sync error: $e');
      },
    );
  }

  /// Gửi lời mời kết bạn hoặc tự động kết nối nếu đối phương đã gửi trước đó / fallback offline
  Future<FriendAddResult> sendFriendRequestOrConnect({
    required String friendUid,
    required String friendName,
  }) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return FriendAddResult.networkError;
    if (friendUid.trim().isEmpty) return FriendAddResult.networkError;
    if (friendUid == myProfile.uid) return FriendAddResult.selfError;

    // 1. Kiểm tra nếu đã là bạn bè từ trước
    if (_friends.any((f) => f.uid == friendUid)) {
      return FriendAddResult.alreadyFriends;
    }

    // Helper: Kết nối bạn bè trực tiếp vào bộ nhớ cục bộ (Offline-First 0 VNĐ)
    Future<FriendAddResult> connectDirectlyOffline() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!_friends.any((f) => f.uid == friendUid)) {
        _friends.add(Friend(uid: friendUid, displayName: friendName, addedAt: now));
        friendsCountNotifier.value = _friends.length;
        await _saveToCache();
      }
      return FriendAddResult.acceptedImmediately;
    }

    // Nếu chưa cấu hình Firebase thực thụ -> Kết nối tức thì 100% Offline
    if (!AuthService.isCloudConfigured) {
      return await connectDirectlyOffline();
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Lấy trước avatarBase64 của bạn bè nếu họ đã lưu trên Firestore
    String? friendAvatarBase64;
    try {
      final friendDoc = await firestore.collection('users').doc(friendUid).get().timeout(const Duration(seconds: 3));
      if (friendDoc.exists && friendDoc.data() != null) {
        friendAvatarBase64 = friendDoc.data()!['avatarBase64'] as String?;
      }
    } catch (_) {}

    try {
      // 2. Kết nối trực tiếp 2 chiều trên Cloud Firestore (WriteBatch)
      // Khi A quét mã QR của B, lập tức cả 2 trở thành bạn bè trên vòng tròn Orbit của nhau
      final batch = firestore.batch();

      // Thêm B vào danh sách bạn bè của A
      final friendPayloadA = <String, dynamic>{
        'uid': friendUid,
        'displayName': friendName,
        'addedAt': now,
      };
      if (friendAvatarBase64 != null && friendAvatarBase64.isNotEmpty) {
        friendPayloadA['avatarBase64'] = friendAvatarBase64;
      }
      batch.set(
        firestore.collection('users').doc(myProfile.uid).collection('friends').doc(friendUid),
        friendPayloadA,
        SetOptions(merge: true),
      );

      // Thêm A vào danh sách bạn bè của B
      final friendPayloadB = <String, dynamic>{
        'uid': myProfile.uid,
        'displayName': myProfile.displayName,
        'addedAt': now,
      };
      if (myProfile.avatarBase64 != null && myProfile.avatarBase64!.isNotEmpty) {
        friendPayloadB['avatarBase64'] = myProfile.avatarBase64;
      }
      batch.set(
        firestore.collection('users').doc(friendUid).collection('friends').doc(myProfile.uid),
        friendPayloadB,
        SetOptions(merge: true),
      );

      await batch.commit().timeout(const Duration(seconds: 4));

      // Cập nhật trạng thái cục bộ để UI phản hồi tức thì
      final friendObj = Friend(
        uid: friendUid,
        displayName: friendName,
        addedAt: now,
        avatarBase64: friendAvatarBase64,
      );
      if (!_friends.any((f) => f.uid == friendUid)) {
        _friends.add(friendObj);
        friendsCountNotifier.value = _friends.length;
        await _saveToCache();
      }

      debugPrint('🤝 Mutual 2-way friend connection established directly with $friendName ($friendUid)!');
      return FriendAddResult.acceptedImmediately;
    } catch (e) {
      debugPrint('Firestore mutual friend request error: $e. Gracefully falling back to local connection.');
      // Resilient Fallback: Quét mã QR trực tiếp là hành động có chủ đích ở cự ly gần -> luôn kết nối thành công!
      return await connectDirectlyOffline();
    }
  }

  /// Lấy avatar Base64 của bạn bè từ Firestore nếu chưa có trong cache cục bộ
  Future<void> fetchAndCacheFriendAvatar(String friendUid) async {
    if (!AuthService.isCloudConfigured) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(friendUid).get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final b64 = doc.data()!['avatarBase64'] as String?;
        final cloudName = doc.data()!['displayName'] as String?;
        final idx = _friends.indexWhere((f) => f.uid == friendUid);
        if (idx != -1) {
          bool updated = false;
          String curName = _friends[idx].displayName;
          String? curB64 = _friends[idx].avatarBase64;
          if (cloudName != null && cloudName.trim().isNotEmpty && cloudName != curName) {
            curName = cloudName.trim();
            updated = true;
          }
          if (b64 != null && b64.isNotEmpty && b64 != curB64) {
            curB64 = b64;
            updated = true;
          }
          if (updated) {
            _friends[idx] = Friend(
              uid: _friends[idx].uid,
              displayName: curName,
              addedAt: _friends[idx].addedAt,
              avatarBase64: curB64,
            );
            await _saveToCache();
            friendsUpdatedNotifier.value++;
            friendsCountNotifier.value = _friends.length;
          }
        }
      }
    } catch (_) {}
  }

  /// Đồng bộ tự động toàn bộ avatar của tất cả bạn bè từ collection `users`
  Future<void> syncAllFriendsAvatars() async {
    if (!AuthService.isCloudConfigured || _friends.isEmpty) return;
    final myUid = AuthService.instance.currentUser?.uid;
    bool changed = false;
    for (int i = 0; i < _friends.length; i++) {
      final f = _friends[i];
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(f.uid).get().timeout(const Duration(seconds: 3));
        if (doc.exists && doc.data() != null) {
          final b64 = doc.data()!['avatarBase64'] as String?;
          final cloudName = doc.data()!['displayName'] as String?;
          if ((b64 != null && b64.isNotEmpty && b64 != f.avatarBase64) ||
              (cloudName != null && cloudName.trim().isNotEmpty && cloudName != f.displayName)) {
            _friends[i] = Friend(
              uid: f.uid,
              displayName: (cloudName != null && cloudName.trim().isNotEmpty) ? cloudName.trim() : f.displayName,
              addedAt: f.addedAt,
              avatarBase64: b64 ?? f.avatarBase64,
            );
            changed = true;
            if (myUid != null && b64 != null) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(myUid)
                  .collection('friends')
                  .doc(f.uid)
                  .set({'avatarBase64': b64, 'displayName': _friends[i].displayName}, SetOptions(merge: true))
                  .catchError((_) {});
            }
          }
        }
      } catch (_) {}
    }
    if (changed) {
      await _saveToCache();
      friendsUpdatedNotifier.value++;
    }
  }

  /// Phát sóng avatar mới của bản thân tới tất cả bạn bè trong danh bạ
  Future<void> broadcastMyNewAvatarToAllFriends() async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null || !AuthService.isCloudConfigured || _friends.isEmpty) return;
    final b64 = myProfile.avatarBase64;
    if (b64 == null || b64.isEmpty) return;

    for (final f in _friends) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(f.uid)
            .collection('friends')
            .doc(myProfile.uid)
            .set({
          'avatarBase64': b64,
          'displayName': myProfile.displayName,
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
  }

  /// Chấp nhận lời mời kết bạn (Kết nối 2 chiều trên vòng tròn quỹ đạo của cả 2)
  Future<bool> acceptFriendRequest(FriendRequest req) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Luôn cập nhật local state trước để UI phản hồi tức thì
    final friendObj = Friend(
      uid: req.fromUid,
      displayName: req.fromName,
      addedAt: now,
      avatarBase64: req.fromAvatarBase64,
    );
    if (!_friends.any((f) => f.uid == req.fromUid)) {
      _friends.add(friendObj);
      friendsCountNotifier.value = _friends.length;
      await _saveToCache();
    }

    if (!AuthService.isCloudConfigured) return true;

    final firestore = FirebaseFirestore.instance;

    try {
      // 2. Cập nhật trạng thái lời mời thành 'accepted'
      await firestore.collection('friend_requests').doc(req.id).update({
        'status': 'accepted',
        'acceptedAt': now,
      }).timeout(const Duration(seconds: 3));

      // 3. Thêm người gửi vào danh sách bạn bè của tôi (Firestore)
      await firestore
          .collection('users')
          .doc(myProfile.uid)
          .collection('friends')
          .doc(req.fromUid)
          .set(friendObj.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));

      // 4. Thêm tôi vào danh sách bạn bè của người gửi (Firestore)
      final myFriendPayload = <String, dynamic>{
        'uid': myProfile.uid,
        'displayName': myProfile.displayName,
        'addedAt': now,
      };
      if (myProfile.avatarBase64 != null && myProfile.avatarBase64!.isNotEmpty) {
        myFriendPayload['avatarBase64'] = myProfile.avatarBase64;
      }
      await firestore
          .collection('users')
          .doc(req.fromUid)
          .collection('friends')
          .doc(myProfile.uid)
          .set(myFriendPayload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 3));

      debugPrint('🤝 Mutual friend connection established with ${req.fromName}!');
      return true;
    } catch (e) {
      debugPrint('Error syncing accept friend request to Firestore: $e');
      return true; // Vẫn thành công ở cấp độ cục bộ
    }
  }

  /// Từ chối lời mời kết bạn
  Future<void> declineFriendRequest(FriendRequest req) async {
    final current = List<FriendRequest>.from(pendingRequestsNotifier.value);
    current.removeWhere((r) => r.id == req.id);
    pendingRequestsNotifier.value = current;

    if (!AuthService.isCloudConfigured) return;

    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(req.id)
          .update({
        'status': 'declined',
      }).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Error declining friend request: $e');
    }
  }

  /// Đồng bộ thủ công danh sách bạn bè từ Firestore
  Future<void> syncFriendsFromFirestore() async {
    final myUid = AuthService.instance.currentUser?.uid;
    if (myUid == null || !AuthService.isCloudConfigured) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isNotEmpty) {
        _friends.clear();
        for (var doc in snapshot.docs) {
          _friends.add(Friend.fromMap(doc.data()));
        }
        friendsCountNotifier.value = _friends.length;
        await _saveToCache();
      }
    } catch (e) {
      debugPrint('Firestore friend sync: $e');
    }
  }

  /// Xóa bạn bè (xóa 2 chiều trên Cloud Firestore)
  Future<void> removeFriend(String friendUid) async {
    _friends.removeWhere((f) => f.uid == friendUid);
    friendsCountNotifier.value = _friends.length;
    await _saveToCache();
    SyncService.removeFriendPhoto(friendUid);

    final myUid = AuthService.instance.currentUser?.uid;
    if (myUid != null && AuthService.isCloudConfigured) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        batch.delete(FirebaseFirestore.instance.collection('users').doc(myUid).collection('friends').doc(friendUid));
        batch.delete(FirebaseFirestore.instance.collection('users').doc(friendUid).collection('friends').doc(myUid));
        await batch.commit().timeout(const Duration(seconds: 3));
        debugPrint('🗑️ Removed mutual friend connection with $friendUid');
      } catch (e) {
        debugPrint('Error removing friend: $e');
      }
    }
  }

  List<String> getFriendUids() {
    return _friends.map((f) => f.uid).toList();
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_friends.map((f) => f.toMap()).toList());
    await prefs.setString(_prefFriendsKey, jsonStr);
  }

  void dispose() {
    _incomingRequestsSub?.cancel();
    _outgoingRequestsSub?.cancel();
    _friendsRealtimeSub?.cancel();
  }
}
