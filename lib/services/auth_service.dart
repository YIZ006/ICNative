import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String secretToken;
  final int createdAt;
  final String? avatarPath;
  final String? avatarBase64;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.secretToken,
    required this.createdAt,
    this.avatarPath,
    this.avatarBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'secretToken': secretToken,
      'createdAt': createdAt,
      'avatarPath': avatarPath,
      'avatarBase64': avatarBase64,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Bạn Vui Vẻ',
      secretToken: map['secretToken'] as String? ?? '',
      createdAt: map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      avatarPath: map['avatarPath'] as String?,
      avatarBase64: map['avatarBase64'] as String?,
    );
  }
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  // Notifier để UI phản ứng tức thì khi đổi tên hoặc avatar
  final ValueNotifier<UserProfile?> currentUserNotifier = ValueNotifier<UserProfile?>(null);

  /// Kiểm tra xem Firebase đã được cấu hình thật sự (có backend cloud) hay chưa
  static bool get isCloudConfigured {
    if (Firebase.apps.isEmpty) return false;
    try {
      final opts = Firebase.app().options;
      final pid = opts.projectId.toLowerCase();
      final key = opts.apiKey.toLowerCase();
      if (pid.isEmpty || pid.contains('offline') || pid.contains('dummy')) return false;
      if (key.isEmpty || key.contains('dummy') || key.contains('replace')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _prefUidKey = 'iconnative_uid';
  static const _prefNameKey = 'iconnative_name';
  static const _prefSecretKey = 'iconnative_secret';
  static const _prefCreatedKey = 'iconnative_created';
  static const _prefAvatarKey = 'iconnative_avatar';
  static const _prefAvatarBase64Key = 'iconnative_avatar_b64';

  static const List<String> _cuteNames = [
    'Capybara Vui Vẻ',
    'Mèo Cam Lém Lỉnh',
    'Cún Shiba Ngoan',
    'Gấu Trúc Dễ Thương',
    'Cáo Nhỏ Thông Minh',
    'Thỏ Trắng Nhanh Nhẹn',
    'Mèo Béo Đáng Yêu',
    'Capybara Chill Chill',
    'Hổ Con Dũng Cảm',
    'Chim Cánh Cụt Cute',
  ];

  /// Nén và chuyển ảnh sang Base64 chuẩn JPEG 160x160 (chỉ ~8KB, 0 VNĐ trên Firestore)
  static Future<String?> encodeAvatarToBase64(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      final resized = img.copyResize(decoded, width: 160, height: 160);
      final jpgBytes = img.encodeJpg(resized, quality: 78);
      return base64Encode(jpgBytes);
    } catch (e) {
      debugPrint('Encode avatar Base64 error: $e');
      return null;
    }
  }

  /// Initialize or load persistent user identity
  Future<UserProfile> init() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_prefUidKey);

    if (uid != null && uid.isNotEmpty) {
      final savedAvatar = prefs.getString(_prefAvatarKey);
      String? savedAvatarB64 = prefs.getString(_prefAvatarBase64Key);

      // Nếu có ảnh trên máy mà chưa có Base64 thì sinh ngay và lưu cache
      if ((savedAvatarB64 == null || savedAvatarB64.isEmpty) &&
          savedAvatar != null &&
          File(savedAvatar).existsSync()) {
        savedAvatarB64 = await encodeAvatarToBase64(savedAvatar);
        if (savedAvatarB64 != null) {
          await prefs.setString(_prefAvatarBase64Key, savedAvatarB64);
        }
      }

      _currentUser = UserProfile(
        uid: uid,
        displayName: prefs.getString(_prefNameKey) ?? 'Bạn Vui Vẻ',
        secretToken: prefs.getString(_prefSecretKey) ?? '',
        createdAt: prefs.getInt(_prefCreatedKey) ?? DateTime.now().millisecondsSinceEpoch,
        avatarPath: (savedAvatar != null && File(savedAvatar).existsSync()) ? savedAvatar : null,
        avatarBase64: savedAvatarB64,
      );
    } else {
      _currentUser = await _createNewIdentity(prefs);
    }

    currentUserNotifier.value = _currentUser;
    _syncToFirestore();
    return _currentUser!;
  }

  Future<UserProfile> _createNewIdentity(SharedPreferences prefs) async {
    const uuid = Uuid();
    final uid = 'u_${uuid.v4().substring(0, 8)}';
    final secret = 'sec_${uuid.v4().replaceAll('-', '')}';
    final randSuffix = Random().nextInt(900) + 100;
    final randomName = '${_cuteNames[Random().nextInt(_cuteNames.length)]} #$randSuffix';
    final createdAt = DateTime.now().millisecondsSinceEpoch;

    final profile = UserProfile(
      uid: uid,
      displayName: randomName,
      secretToken: secret,
      createdAt: createdAt,
    );

    await prefs.setString(_prefUidKey, uid);
    await prefs.setString(_prefNameKey, randomName);
    await prefs.setString(_prefSecretKey, secret);
    await prefs.setInt(_prefCreatedKey, createdAt);

    return profile;
  }

  /// Update display name
  Future<void> updateDisplayName(String newName) async {
    if (_currentUser == null || newName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefNameKey, newName.trim());

    _currentUser = UserProfile(
      uid: _currentUser!.uid,
      displayName: newName.trim(),
      secretToken: _currentUser!.secretToken,
      createdAt: _currentUser!.createdAt,
      avatarPath: _currentUser!.avatarPath,
      avatarBase64: _currentUser!.avatarBase64,
    );

    currentUserNotifier.value = _currentUser;
    _syncToFirestore();
  }

  /// Update Avatar (Luu anh dai dien moi vao bo nho may va cap nhat state)
  Future<void> updateAvatar(String newImagePath) async {
    if (_currentUser == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final targetPath = '${dir.path}/avatar_${_currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}.png';

      final savedFile = await File(newImagePath).copy(targetPath);
      final avatarB64 = await encodeAvatarToBase64(savedFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAvatarKey, savedFile.path);
      if (avatarB64 != null) {
        await prefs.setString(_prefAvatarBase64Key, avatarB64);
      } else {
        await prefs.remove(_prefAvatarBase64Key);
      }

      _currentUser = UserProfile(
        uid: _currentUser!.uid,
        displayName: _currentUser!.displayName,
        secretToken: _currentUser!.secretToken,
        createdAt: _currentUser!.createdAt,
        avatarPath: savedFile.path,
        avatarBase64: avatarB64,
      );

      currentUserNotifier.value = _currentUser;
      _syncToFirestore();
    } catch (e) {
      debugPrint('Error updating avatar: $e');
    }
  }

  /// Sync user profile to Firestore
  Future<void> _syncToFirestore() async {
    if (_currentUser == null) return;
    try {
      if (!isCloudConfigured) return;
      final docRef = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      final payload = <String, dynamic>{
        'uid': _currentUser!.uid,
        'displayName': _currentUser!.displayName,
        'createdAt': _currentUser!.createdAt,
        'lastActive': FieldValue.serverTimestamp(),
      };
      if (_currentUser!.avatarBase64 != null && _currentUser!.avatarBase64!.isNotEmpty) {
        payload['avatarBase64'] = _currentUser!.avatarBase64;
      }
      await docRef.set(payload, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Firestore User Sync: $e');
    }
  }

  /// Generate QR payload for adding friend (Public)
  String generateFriendQrPayload() {
    if (_currentUser == null) return '';
    return jsonEncode({
      'type': 'iconnative_add_friend',
      'uid': _currentUser!.uid,
      'name': _currentUser!.displayName,
    });
  }

  /// Generate QR payload for Account Recovery / Backup (Private)
  String generateBackupQrPayload() {
    if (_currentUser == null) return '';
    return jsonEncode({
      'type': 'iconnative_account_backup',
      'uid': _currentUser!.uid,
      'name': _currentUser!.displayName,
      'secret': _currentUser!.secretToken,
      'createdAt': _currentUser!.createdAt,
    });
  }

  /// Restore identity from backup QR code
  Future<bool> restoreFromBackupPayload(String jsonPayload) async {
    try {
      final data = jsonDecode(jsonPayload) as Map<String, dynamic>;
      if (data['type'] != 'iconnative_account_backup') return false;

      final uid = data['uid'] as String?;
      final secret = data['secret'] as String?;
      final name = data['name'] as String? ?? 'Bạn Vui Vẻ';
      final createdAt = data['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch;

      if (uid == null || uid.isEmpty || secret == null || secret.isEmpty) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefUidKey, uid);
      await prefs.setString(_prefNameKey, name);
      await prefs.setString(_prefSecretKey, secret);
      await prefs.setInt(_prefCreatedKey, createdAt);

      _currentUser = UserProfile(
        uid: uid,
        displayName: name,
        secretToken: secret,
        createdAt: createdAt,
        avatarPath: prefs.getString(_prefAvatarKey),
        avatarBase64: prefs.getString(_prefAvatarBase64Key),
      );

      currentUserNotifier.value = _currentUser;
      await _syncToFirestore();
      return true;
    } catch (e) {
      debugPrint('Restore Error: $e');
      return false;
    }
  }
}
