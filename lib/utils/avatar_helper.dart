import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:icnative/settings/theme_colors.dart';

class AvatarHelper {
  /// Xác định sticker linh vật mặc định dựa trên biệt danh hoặc UID của tài khoản
  static String getMascotAsset(String name, [String? uid]) {
    final lower = name.toLowerCase();
    if (lower.contains('mèo') || lower.contains('cat') || lower.contains('meo')) {
      return 'assets/stickers/sticker_cat_heart.jpg';
    }
    if (lower.contains('cún') ||
        lower.contains('chó') ||
        lower.contains('shiba') ||
        lower.contains('dog')) {
      return 'assets/stickers/sticker_shiba_cool.jpg';
    }
    if (lower.contains('capybara')) {
      return 'assets/stickers/sticker_capybara_chill.jpg';
    }

    // Phân bổ ngẫu nhiên nhưng cố định theo chuỗi (Deterministic Hash)
    const list = [
      'assets/stickers/sticker_cat_heart.jpg',
      'assets/stickers/sticker_shiba_cool.jpg',
      'assets/stickers/sticker_capybara_chill.jpg',
    ];
    final seed = (uid ?? name).hashCode.abs();
    return list[seed % list.length];
  }

  /// Widget hiển thị Avatar đa tầng: File cục bộ -> Base64 Cloud -> Sticker Linh vật -> Ký tự đại diện
  static Widget buildAvatar({
    String? avatarPath,
    String? avatarBase64,
    required String displayName,
    String? uid,
    double size = 44,
    Color backgroundColor = OrbitColors.buttonPrimary,
    BoxBorder? border,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: border,
      ),
      child: ClipOval(
        child: _buildInnerImage(
          avatarPath: avatarPath,
          avatarBase64: avatarBase64,
          displayName: displayName,
          uid: uid,
          size: size,
        ),
      ),
    );
  }

  static Widget _buildInnerImage({
    String? avatarPath,
    String? avatarBase64,
    required String displayName,
    String? uid,
    required double size,
  }) {
    // 1. Ảnh tệp cục bộ trên máy
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        final file = File(avatarPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallback(displayName, uid, size),
          );
        }
      } catch (_) {}
    }

    // 2. Ảnh Base64 đồng bộ từ Cloud Firestore
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(avatarBase64);
        return Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallback(displayName, uid, size),
        );
      } catch (_) {}
    }

    // 3. Fallback sticker linh vật siêu dễ thương
    return _buildFallback(displayName, uid, size);
  }

  static Widget _buildFallback(String displayName, String? uid, double size) {
    final assetPath = getMascotAsset(displayName, uid);
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '🐾';
        return Center(
          child: Text(
            initial,
            style: TextStyle(
              color: OrbitColors.textLight,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.45,
            ),
          ),
        );
      },
    );
  }
}
