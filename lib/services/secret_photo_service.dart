import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class SecretPhoto {
  final String id;
  final String senderUid;
  final String senderName;
  final String imagePath;
  final String teaserMessage;
  final int createdAt;
  final bool isRevealed;

  SecretPhoto({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.imagePath,
    this.teaserMessage = 'Tao vừa gửi cho mày 1 tấm ảnh bí mật trên Orbit 🤫',
    required this.createdAt,
    this.isRevealed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUid': senderUid,
      'senderName': senderName,
      'imagePath': imagePath,
      'teaserMessage': teaserMessage,
      'createdAt': createdAt,
      'isRevealed': isRevealed,
    };
  }

  factory SecretPhoto.fromMap(Map<String, dynamic> map) {
    return SecretPhoto(
      id: map['id'] as String? ?? '',
      senderUid: map['senderUid'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Bạn bè',
      imagePath: map['imagePath'] as String? ?? '',
      teaserMessage: map['teaserMessage'] as String? ?? 'Ảnh bí mật',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isRevealed: map['isRevealed'] as bool? ?? false,
    );
  }
}

class SecretPhotoService {
  static final SecretPhotoService instance = SecretPhotoService._internal();
  SecretPhotoService._internal();

  static const _prefKey = 'orbit_secret_photos';
  final List<SecretPhoto> _cachedPhotos = [];
  List<SecretPhoto> get secretPhotos => List.unmodifiable(_cachedPhotos);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _cachedPhotos.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _cachedPhotos.add(SecretPhoto.fromMap(item));
          }
        }
      }
    } catch (e) {
      debugPrint('SecretPhotoService init error: $e');
    }
  }

  /// Tạo link bí mật để gửi qua Story Locket / Messenger / Instagram
  String generateSecretShareText({
    required String photoId,
    String? customMessage,
  }) {
    final user = AuthService.instance.currentUser;
    final senderName = user?.displayName ?? 'Tôi';
    final senderUid = user?.uid ?? 'unknown';
    final msg = customMessage ?? '$senderName vừa gửi cho bạn 1 tấm ảnh bí mật trên Orbit 🤫';
    
    return '$msg\n\n👉 Vào cào ảnh để xem ngay: orbit://peek?id=$photoId&from=$senderUid\n(Nếu chưa có Orbit, tải ngay bản 0 VNĐ không giới hạn bạn bè)';
  }

  /// Đánh dấu ảnh đã được cào mở
  Future<void> markAsRevealed(String photoId) async {
    final idx = _cachedPhotos.indexWhere((p) => p.id == photoId);
    if (idx != -1) {
      final old = _cachedPhotos[idx];
      _cachedPhotos[idx] = SecretPhoto(
        id: old.id,
        senderUid: old.senderUid,
        senderName: old.senderName,
        imagePath: old.imagePath,
        teaserMessage: old.teaserMessage,
        createdAt: old.createdAt,
        isRevealed: true,
      );
      await _persist();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _cachedPhotos.map((p) => p.toMap()).toList();
      await prefs.setString(_prefKey, jsonEncode(data));
    } catch (e) {
      debugPrint('SecretPhotoService persist error: $e');
    }
  }
}
