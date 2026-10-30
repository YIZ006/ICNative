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
      addedAt: map['addedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class FriendService {
  static final FriendService instance = FriendService._internal();
  FriendService._internal();

  static const _prefFriendsKey = 'iconnative_friends_list';
  final List<Friend> _friends = [];
  List<Friend> get friends => List.unmodifiable(_friends);

  final ValueNotifier<int> friendsCountNotifier = ValueNotifier<int>(0);

  /// Load cached friends on app startup
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

    // Sync with Firestore if available
    syncFriendsFromFirestore();
  }

  /// Sync friend list from Firestore
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
          final data = doc.data();
          _friends.add(Friend.fromMap(data));
        }
        friendsCountNotifier.value = _friends.length;
        _saveToCache();
      }
    } catch (e) {
      debugPrint('Firestore friend sync: $e');
    }
  }

  /// Add friend from scanned QR code data
  Future<bool> addFriendFromQr(String friendUid, String friendName) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null) return false;
    if (friendUid == myProfile.uid) {
      debugPrint('Cannot add yourself as a friend');
      return false;
    }

    // Check if already friends
    if (_friends.any((f) => f.uid == friendUid)) {
      return true; // Already connected
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newFriend = Friend(
      uid: friendUid,
      displayName: friendName,
      addedAt: now,
    );

    _friends.add(newFriend);
    friendsCountNotifier.value = _friends.length;
    await _saveToCache();

    // Mutual friend link in Firestore if Firebase is active
    if (Firebase.apps.isNotEmpty) {
      try {
        final firestore = FirebaseFirestore.instance;

        // 1. Add friend to my list
        await firestore
            .collection('users')
            .doc(myProfile.uid)
            .collection('friends')
            .doc(friendUid)
            .set(newFriend.toMap(), SetOptions(merge: true));

        // 2. Add myself to friend's list (Mutual pairing)
        await firestore
            .collection('users')
            .doc(friendUid)
            .collection('friends')
            .doc(myProfile.uid)
            .set({
          'uid': myProfile.uid,
          'displayName': myProfile.displayName,
          'addedAt': now,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Firestore mutual friend add: $e');
      }
    }

    return true;
  }

  /// Remove a friend
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
}
