import 'package:flutter/material.dart';
import 'package:icnative/services/friend_service.dart';

/// Model thông tin bạn bè mẫu cho chế độ Demo / Bản Showcase
class DemoFriendItem {
  final String uid;
  final String displayName;
  final int tier; // 1: Cận tâm (tương tác gần nhất), 2: Tầm trung, 3: Vòng ngoài
  final String recentActivity;
  final List<String> recentReactions;
  final Color avatarColor;
  final bool hasAuraGlow;

  const DemoFriendItem({
    required this.uid,
    required this.displayName,
    required this.tier,
    required this.recentActivity,
    required this.recentReactions,
    required this.avatarColor,
    this.hasAuraGlow = false,
  });

  String get initial => displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?';

  Friend toFriend() {
    return Friend(
      uid: uid,
      displayName: displayName,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Model bài đăng ảnh bạn bè chụp trong mục Lịch sử / Feed
class DemoPhotoItem {
  final String id;
  final String assetPath;
  final String senderName;
  final String senderUid;
  final String caption;
  final String timeAgo;
  final String location;
  final Map<String, int> reactions;
  final String? memeStickerAsset;
  final Offset stickerOffsetRatio;

  const DemoPhotoItem({
    required this.id,
    required this.assetPath,
    required this.senderName,
    required this.senderUid,
    required this.caption,
    required this.timeAgo,
    required this.location,
    required this.reactions,
    this.memeStickerAsset,
    this.stickerOffsetRatio = const Offset(0.65, 0.65),
  });

  int get totalReactions => reactions.values.fold(0, (sum, count) => sum + count);
}

/// Service quản lý toàn bộ dữ liệu mẫu cho Bản Trải Nghiệm (Demo Showcase)
class DemoDataService {
  static final DemoDataService instance = DemoDataService._internal();
  DemoDataService._internal();

  /// Danh sách 8 bạn bè mẫu phân tầng rõ ràng (Cận tâm -> Tầm trung -> Xa)
  final List<DemoFriendItem> demoFriends = const [
    // TẦNG 1: CẬN TÂM (Tương tác gần nhất 24h-48h - Vòng trong, kích thước lớn, hào quang sáng)
    DemoFriendItem(
      uid: 'demo_f1',
      displayName: 'An Nhiên',
      tier: 1,
      recentActivity: 'Vừa gửi ảnh 10 phút trước 📸',
      recentReactions: ['❤️', '🔥'],
      avatarColor: Color(0xFFFF7043),
      hasAuraGlow: true,
    ),
    DemoFriendItem(
      uid: 'demo_f2',
      displayName: 'Bảo Long',
      tier: 1,
      recentActivity: 'Vừa thả tim 45 phút trước ❤️',
      recentReactions: ['❤️'],
      avatarColor: Color(0xFFFFB74D),
      hasAuraGlow: true,
    ),
    DemoFriendItem(
      uid: 'demo_f3',
      displayName: 'Chi Mai',
      tier: 1,
      recentActivity: 'Đang online 2 giờ trước ✨',
      recentReactions: ['😍', '✨'],
      avatarColor: Color(0xFFBA68C8),
      hasAuraGlow: true,
    ),

    // TẦNG 2: TẦM TRUNG (Tương tác 3-5 ngày - Vòng giữa)
    DemoFriendItem(
      uid: 'demo_f4',
      displayName: 'Dương Vũ',
      tier: 2,
      recentActivity: 'Tương tác hôm qua 🌅',
      recentReactions: ['👏'],
      avatarColor: Color(0xFF4DD0E1),
    ),
    DemoFriendItem(
      uid: 'demo_f5',
      displayName: 'Gia Hân',
      tier: 2,
      recentActivity: 'Gửi ảnh 2 ngày trước 🌸',
      recentReactions: ['🔥'],
      avatarColor: Color(0xFF81C784),
    ),
    DemoFriendItem(
      uid: 'demo_f6',
      displayName: 'Hải Đăng',
      tier: 2,
      recentActivity: 'Tương tác 3 ngày trước ☕',
      recentReactions: ['❤️'],
      avatarColor: Color(0xFFFF8A65),
    ),

    // TẦNG 3: VÒNG NGOÀI (Lâu chưa tương tác > 1 tuần)
    DemoFriendItem(
      uid: 'demo_f7',
      displayName: 'Khánh Linh',
      tier: 3,
      recentActivity: '5 ngày trước',
      recentReactions: [],
      avatarColor: Color(0xFF90A4AE),
    ),
    DemoFriendItem(
      uid: 'demo_f8',
      displayName: 'Minh Quân',
      tier: 3,
      recentActivity: '1 tuần trước',
      recentReactions: [],
      avatarColor: Color(0xFFA1887F),
    ),
  ];

  /// Danh sách bài đăng ảnh mẫu sinh động kèm caption, địa điểm, reaction, meme sticker
  final List<DemoPhotoItem> demoPhotos = const [
    DemoPhotoItem(
      id: 'demo_p1',
      assetPath: 'assets/stickers/sticker_cat_heart.jpg',
      senderName: 'An Nhiên',
      senderUid: 'demo_f1',
      caption: 'Mèo con ngủ trưa ấm áp quá nè mọi người ơi! 🐾☀️',
      timeAgo: '15 phút trước',
      location: 'Hồ Tây, Hà Nội',
      reactions: {'❤️': 24, '🔥': 8, '😍': 12},
      memeStickerAsset: 'assets/memes/meme_capybara_01.png',
      stickerOffsetRatio: Offset(0.68, 0.62),
    ),
    DemoPhotoItem(
      id: 'demo_p2',
      assetPath: 'assets/stickers/sticker_capybara_chill.jpg',
      senderName: 'Bảo Long',
      senderUid: 'demo_f2',
      caption: 'Chill cuối tuần cùng Capybara thư thái bên tách cafe ☕🌿',
      timeAgo: '1 giờ trước',
      location: 'Đà Lạt, Lâm Đồng',
      reactions: {'🔥': 19, '❤️': 15, '👏': 6},
      memeStickerAsset: 'assets/memes/meme_capybara_03.png',
      stickerOffsetRatio: Offset(0.25, 0.70),
    ),
    DemoPhotoItem(
      id: 'demo_p3',
      assetPath: 'assets/stickers/sticker_shiba_cool.jpg',
      senderName: 'Chi Mai',
      senderUid: 'demo_f3',
      caption: 'Shiba đeo kính ngầu chưa, chuẩn bị đi lượn phố cuối tuần 🐕🕶️',
      timeAgo: '3 giờ trước',
      location: 'Phố đi bộ Nguyễn Huệ, TP.HCM',
      reactions: {'❤️': 31, '😂': 14, '🔥': 10},
      memeStickerAsset: 'assets/memes/meme_capybara_08.png',
      stickerOffsetRatio: Offset(0.70, 0.25),
    ),
    DemoPhotoItem(
      id: 'demo_p4',
      assetPath: 'assets/stickers/sticker_boba_cute.jpg',
      senderName: 'Dương Vũ',
      senderUid: 'demo_f4',
      caption: 'Trà sữa trân châu full topping giải nhiệt ngày nắng nóng 🧋✨',
      timeAgo: 'Hôm qua',
      location: 'Cầu Rồng, Đà Nẵng',
      reactions: {'😍': 22, '❤️': 17, '👏': 5},
    ),
    DemoPhotoItem(
      id: 'demo_p5',
      assetPath: 'assets/stickers/sticker_bear_sleepy.jpg',
      senderName: 'Gia Hân',
      senderUid: 'demo_f5',
      caption: 'Góc học tập sáng nay tràn ngập ánh nắng bình yên 📚🌻',
      timeAgo: '2 ngày trước',
      location: 'Thảo Cầm Viên, Sài Gòn',
      reactions: {'❤️': 16, '✨': 9},
    ),
  ];

  /// Lấy danh sách Friend model tương thích với hệ thống FriendService
  List<Friend> getDemoFriendsAsFriendModel() {
    return demoFriends.map((df) => df.toFriend()).toList();
  }
}
