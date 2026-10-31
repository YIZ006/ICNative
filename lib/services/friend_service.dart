import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class Friend {
  final String uid;
  final String displayName;
  final int addedAt;

  Friend({
    required this.uid,
    required this.displayName,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'addedAt': addedAt,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Bạn bè',
      addedAt: (map['addedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
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

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    required this.createdAt,
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

    if (Firebase.apps.isNotEmpty) {
      startRealtimeSync();
    }
  }

  /// Khởi động các luồng lắng nghe thời gian thực (Real-time Firestore Listeners)
  void startRealtimeSync() {
    final myUid = AuthService.instance.currentUser?.uid;
    if (myUid == null || Firebase.apps.isEmpty) return;

    // 1. Lắng nghe danh sách bạn bè 2 chiều (Khi đối phương chấp nhận, bạn bè tự động xuất hiện trên vòng tròn)
    _friendsRealtimeSub?.cancel();
    _friendsRealtimeSub = FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('friends')
        .snapshots()
        .listen(
      (snapshot) async {
        final List<Friend> updated = [];
        for (var doc in snapshot.docs) {
          updated.add(Friend.fromMap(doc.data()));
        }
        _friends.clear();
        _friends.addAll(updated);
        friendsCountNotifier.value = _friends.length;
        await _saveToCache();
        debugPrint('🪐 Realtime friends updated: ${_friends.length} friends on orbit');
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

  /// Gửi lời mời kết bạn hoặc tự động kết nối nếu đối phương đã gửi trước đó
  Future<FriendAddResult> sendFriendRequestOrConnect({
    required String friendUid,
    required String friendName,
  }) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return FriendAddResult.networkError;
    if (friendUid == myProfile.uid) return FriendAddResult.selfError;

    // 1. Kiểm tra nếu đã là bạn bè từ trước
    if (_friends.any((f) => f.uid == friendUid)) {
      return FriendAddResult.alreadyFriends;
    }

    if (Firebase.apps.isEmpty) {
      // Offline fallback: Thêm trực tiếp vào danh sách cục bộ
      final now = DateTime.now().millisecondsSinceEpoch;
      _friends.add(Friend(uid: friendUid, displayName: friendName, addedAt: now));
      friendsCountNotifier.value = _friends.length;
      await _saveToCache();
      return FriendAddResult.acceptedImmediately;
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // 2. Kiểm tra xem người kia đã từng gửi lời mời cho mình chưa
      final reverseDoc = await firestore
          .collection('friend_requests')
          .doc('${friendUid}_${myProfile.uid}')
          .get();

      if (reverseDoc.exists) {
        final data = reverseDoc.data()!;
        if (data['status'] == 'pending') {
          // Người kia đã gửi lời mời -> Chấp nhận ngay lập tức! Cả hai trở thành bạn bè!
          final request = FriendRequest.fromMap(data, reverseDoc.id);
          await acceptFriendRequest(request);
          return FriendAddResult.acceptedImmediately;
        }
      }

      // 3. Gửi lời mời kết bạn mới đến người kia
      final requestId = '${myProfile.uid}_$friendUid';
      final requestData = {
        'id': requestId,
        'fromUid': myProfile.uid,
        'fromName': myProfile.displayName,
        'toUid': friendUid,
        'toName': friendName,
        'status': 'pending',
        'createdAt': now,
      };

      await firestore
          .collection('friend_requests')
          .doc(requestId)
          .set(requestData, SetOptions(merge: true));

      debugPrint('🚀 Sent friend request to $friendName ($friendUid)');
      return FriendAddResult.requestSent;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return FriendAddResult.networkError;
    }
  }

  /// Chấp nhận lời mời kết bạn (Kết nối 2 chiều trên vòng tròn quỹ đạo của cả 2)
  Future<bool> acceptFriendRequest(FriendRequest req) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Cập nhật trạng thái lời mời thành 'accepted'
      await firestore.collection('friend_requests').doc(req.id).update({
        'status': 'accepted',
        'acceptedAt': now,
      });

      // 2. Thêm người gửi vào danh sách bạn bè của tôi (Firestore)
      final friendObj = Friend(
        uid: req.fromUid,
        displayName: req.fromName,
        addedAt: now,
      );
      await firestore
          .collection('users')
          .doc(myProfile.uid)
          .collection('friends')
          .doc(req.fromUid)
          .set(friendObj.toMap(), SetOptions(merge: true));

      // 3. Thêm tôi vào danh sách bạn bè của người gửi (Firestore)
      await firestore
          .collection('users')
          .doc(req.fromUid)
          .collection('friends')
          .doc(myProfile.uid)
          .set({
        'uid': myProfile.uid,
        'displayName': myProfile.displayName,
        'addedAt': now,
      }, SetOptions(merge: true));

      // 4. Cập nhật local state
      if (!_friends.any((f) => f.uid == req.fromUid)) {
        _friends.add(friendObj);
        friendsCountNotifier.value = _friends.length;
        await _saveToCache();
      }

      debugPrint('🤝 Mutual friend connection established with ${req.fromName}!');
      return true;
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      return false;
    }
  }

  /// Từ chối lời mời kết bạn
  Future<void> declineFriendRequest(FriendRequest req) async {
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(req.id)
          .update({
        'status': 'declined',
      });
    } catch (e) {
      debugPrint('Error declining friend request: $e');
    }
  }

  /// Đồng bộ thủ công danh sách bạn bè từ Firestore
  Future<void> syncFriendsFromFirestore() async {
    final myUid = AuthService.instance.currentUser?.uid;
    if (myUid == null || Firebase.apps.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .collection('friends')
          .get();

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

  /// Xóa bạn bè
  Future<void> removeFriend(String friendUid) async {
    _friends.removeWhere((f) => f.uid == friendUid);
    friendsCountNotifier.value = _friends.length;
    await _saveToCache();

    final myUid = AuthService.instance.currentUser?.uid;
    if (myUid != null && Firebase.apps.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(myUid)
            .collection('friends')
            .doc(friendUid)
            .delete();
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
