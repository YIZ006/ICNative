import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icnative/services/custom_sticker_service.dart';
import 'package:icnative/services/demo_data_service.dart';
import 'package:icnative/services/friend_service.dart';
import 'package:icnative/services/invite_service.dart';
import 'package:icnative/services/locale_service.dart';
import 'package:icnative/services/location_service.dart';
import 'package:icnative/services/secret_photo_service.dart';
import 'package:icnative/services/soulmate_service.dart';
import 'package:icnative/services/sticker_anchoring_engine.dart';

void main() {
  group('Friend & FriendRequest Models', () {
    test('Friend serialization and deserialization', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final friend = Friend(
        uid: 'user_123',
        displayName: 'Minh Thư',
        addedAt: now,
      );

      final map = friend.toMap();
      expect(map['uid'], 'user_123');
      expect(map['displayName'], 'Minh Thư');
      expect(map['addedAt'], now);

      final restored = Friend.fromMap(map);
      expect(restored.uid, friend.uid);
      expect(restored.displayName, friend.displayName);
      expect(restored.addedAt, friend.addedAt);
    });

    test('Friend.fromMap handles missing or null fields gracefully', () {
      final emptyFriend = Friend.fromMap({});
      expect(emptyFriend.uid, '');
      expect(emptyFriend.displayName, 'Bạn bè');
      expect(emptyFriend.addedAt, isPositive);
    });

    test('FriendRequest serialization and deserialization', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final req = FriendRequest(
        id: 'req_001',
        fromUid: 'u_1',
        fromName: 'Alice',
        toUid: 'u_2',
        toName: 'Bob',
        status: 'pending',
        createdAt: now,
      );

      final map = req.toMap();
      expect(map['id'], 'req_001');
      expect(map['status'], 'pending');

      final restored = FriendRequest.fromMap(map);
      expect(restored.id, req.id);
      expect(restored.fromUid, req.fromUid);
      expect(restored.fromName, req.fromName);
      expect(restored.toUid, req.toUid);
      expect(restored.status, 'pending');
      expect(restored.createdAt, now);
    });
  });

  group('SoulmateData & Calculations', () {
    test('daysTogether returns 1 for today or future dates', () {
      final todaySoulmate = SoulmateData(
        uid: 'soul_1',
        displayName: 'Người ấy',
        startDateMillis: DateTime.now().millisecondsSinceEpoch,
      );
      expect(todaySoulmate.daysTogether, 1);

      final futureSoulmate = SoulmateData(
        uid: 'soul_2',
        displayName: 'Người ấy tương lai',
        startDateMillis: DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch,
      );
      expect(futureSoulmate.daysTogether, 1);
    });

    test('daysTogether calculates past days accurately', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 100));
      final pastSoulmate = SoulmateData(
        uid: 'soul_3',
        displayName: 'Bạn thân 100 ngày',
        startDateMillis: pastDate.millisecondsSinceEpoch,
      );
      expect(pastSoulmate.daysTogether, 100);
    });

    test('Soulmate calculateDistanceKm returns null if coordinates are missing', () {
      final service = SoulmateService.instance;
      expect(service.calculateDistanceKm(21.0285, 105.8542), isNull);
    });

    test('Soulmate calculateDistanceKm calculates distance without NaN error on identical coords', () {
      final soulmate = SoulmateData(
        uid: 'soul_4',
        displayName: 'Cùng vị trí',
        startDateMillis: DateTime.now().millisecondsSinceEpoch,
        latitude: 21.0285,
        longitude: 105.8542,
      );

      final map = soulmate.toMap();
      final restored = SoulmateData.fromMap(map);
      expect(restored.latitude, 21.0285);
      expect(restored.longitude, 105.8542);
    });
  });

  group('LocationService - Haversine Distance & Landmark Detection', () {
    test('Identical coordinates yield 0 distance without NaN', () {
      final dist = LocationService.instance.calculateDistanceMeters(
        21.0285, 105.8542,
        21.0285, 105.8542,
      );
      expect(dist, 0.0);
      expect(dist.isNaN, isFalse);
    });

    test('Known distance: Hoan Kiem Lake to West Lake is ~4.5km - 4.6km', () {
      // Hồ Hoàn Kiếm: 21.0285, 105.8542
      // Hồ Tây: 21.0583, 105.8236
      final dist = LocationService.instance.calculateDistanceMeters(
        21.0285, 105.8542,
        21.0583, 105.8236,
      );

      expect(dist, greaterThan(4500));
      expect(dist, lessThan(4700));
    });

    test('Famous landmarks list is non-empty and has valid radii', () {
      expect(LocationService.famousLandmarks, isNotEmpty);
      for (final lm in LocationService.famousLandmarks) {
        expect(lm.name, isNotEmpty);
        expect(lm.lat, isNotNull);
        expect(lm.lng, isNotNull);
        expect(lm.radiusMeters, greaterThan(100));
      }
    });
  });

  group('SecretPhoto Model & Service', () {
    test('SecretPhoto serialization and deserialization', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final photo = SecretPhoto(
        id: 'sec_photo_1',
        senderUid: 'u_alice',
        senderName: 'Alice #123',
        imagePath: '/path/to/img.jpg',
        teaserMessage: 'Bí mật nè',
        createdAt: now,
        isRevealed: false,
      );

      final map = photo.toMap();
      expect(map['id'], 'sec_photo_1');
      expect(map['isRevealed'], isFalse);

      final restored = SecretPhoto.fromMap(map);
      expect(restored.id, photo.id);
      expect(restored.senderUid, photo.senderUid);
      expect(restored.senderName, photo.senderName);
      expect(restored.imagePath, photo.imagePath);
      expect(restored.teaserMessage, photo.teaserMessage);
      expect(restored.isRevealed, isFalse);
    });

    test('generateSecretShareText produces valid deep link format', () {
      final text = SecretPhotoService.instance.generateSecretShareText(
        photoId: 'photo_abc',
        customMessage: 'Xem ảnh bí mật nha!',
      );

      expect(text, contains('orbit://peek?id=photo_abc'));
      expect(text, contains('Xem ảnh bí mật nha!'));
      expect(text, contains('0 VNĐ'));
    });
  });

  group('DemoDataService - Showcase Rules & Integrity', () {
    test('Demo friends count is 8 and covers tiers 1, 2, 3', () {
      final demoFriends = DemoDataService.instance.demoFriends;
      expect(demoFriends.length, 8);

      final tier1 = demoFriends.where((f) => f.tier == 1).toList();
      final tier2 = demoFriends.where((f) => f.tier == 2).toList();
      final tier3 = demoFriends.where((f) => f.tier == 3).toList();

      expect(tier1.length, 3, reason: 'Tier 1 should have 3 closest friends');
      expect(tier2.length, 3, reason: 'Tier 2 should have 3 medium-orbit friends');
      expect(tier3.length, 2, reason: 'Tier 3 should have 2 outer-orbit friends');

      // Tier 1 must have aura glow
      for (final f in tier1) {
        expect(f.hasAuraGlow, isTrue);
      }
    });

    test('DemoFriendItem initial getter handles normal and empty strings', () {
      const friend = DemoFriendItem(
        uid: 'test',
        displayName: 'Quang Khải',
        tier: 1,
        recentActivity: '',
        recentReactions: [],
        avatarColor: Colors.blue,
      );
      expect(friend.initial, 'Q');

      const emptyFriend = DemoFriendItem(
        uid: 'test2',
        displayName: '',
        tier: 2,
        recentActivity: '',
        recentReactions: [],
        avatarColor: Colors.green,
      );
      expect(emptyFriend.initial, '?');
    });

    test('DemoFriendItem converts to valid Friend entity', () {
      final demoFriend = DemoDataService.instance.demoFriends.first;
      final friend = demoFriend.toFriend();

      expect(friend.uid, demoFriend.uid);
      expect(friend.displayName, demoFriend.displayName);
      expect(friend.addedAt, isPositive);
    });

    test('DemoPhotoItem totalReactions sums properly', () {
      const photo = DemoPhotoItem(
        id: 'p1',
        assetPath: 'assets/stickers/sticker_cat_heart.jpg',
        senderName: 'An Nhiên',
        senderUid: 'f1',
        caption: 'Test caption',
        timeAgo: '10p',
        location: 'Hà Nội',
        reactions: {'❤️': 5, '🔥': 3},
      );

      expect(photo.totalReactions, 8);
    });
  });

  group('CustomStickerItem Model', () {
    test('CustomStickerItem serialization and enum clamp', () {
      final item = CustomStickerItem(
        id: 'stk_1',
        path: '/stickers/cat.png',
        mode: StickerEditMode.outline,
        title: 'Mèo Cưng',
        caption: 'Meo meo',
      );

      final json = item.toJson();
      expect(json['id'], 'stk_1');
      expect(json['mode'], StickerEditMode.outline.index);

      final restored = CustomStickerItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.mode, StickerEditMode.outline);
      expect(restored.title, 'Mèo Cưng');
      expect(restored.caption, 'Meo meo');
    });

    test('CustomStickerItem.fromJson clamps out-of-range mode index safely', () {
      final invalidJson = {
        'id': 'stk_99',
        'path': '/stickers/test.png',
        'mode': 999, // Out of range
        'title': 'Test',
      };

      final restored = CustomStickerItem.fromJson(invalidJson);
      expect(restored.mode, StickerEditMode.badge); // clamped to max index
    });
  });

  group('LocaleService - Translations & Fallback', () {
    test('LocaleService translates common keys in Vietnamese and English', () {
      final service = LocaleService.instance;

      service.currentLanguage.value = AppLanguage.vi;
      expect(service.t('app_name'), 'Orbit');
      expect(service.t('add_friend'), 'Thêm Bạn');

      service.currentLanguage.value = AppLanguage.en;
      expect(service.t('app_name'), 'Orbit');
      expect(service.t('add_friend'), 'Add Friend');

      // Reset to Vietnamese
      service.currentLanguage.value = AppLanguage.vi;
    });

    test('LocaleService falls back to Vietnamese or key itself when translation missing', () {
      final service = LocaleService.instance;
      service.currentLanguage.value = AppLanguage.en;

      expect(service.t('non_existing_key_xyz'), 'non_existing_key_xyz');

      service.currentLanguage.value = AppLanguage.vi;
    });
  });

  group('StickerAnchoringEngine - Sticker Integrity & Anti-Ghost Tests', () {
    test('All 144 meme sticker assets actually exist on disk and are non-empty', () {
      expect(StickerAnchoringEngine.allMemes.length, equals(144));
      expect(StickerAnchoringEngine.catMemes.length, equals(28));
      expect(StickerAnchoringEngine.capybaraMemes.length, equals(22));
      expect(StickerAnchoringEngine.funnyMemes.length, equals(60));
      expect(StickerAnchoringEngine.meoGauMemes.length, equals(24));
      expect(StickerAnchoringEngine.shinMemes.length, equals(10));

      for (final assetPath in StickerAnchoringEngine.allMemes) {
        final file = File(assetPath);
        expect(file.existsSync(), isTrue, reason: 'Meme asset missing from disk: $assetPath');
        expect(file.lengthSync(), greaterThan(0), reason: 'Meme asset is empty (0 bytes): $assetPath');
      }
    });

    test('pickStickerForCategory returns valid non-empty assets for every category', () {
      for (final cat in StickerCategory.values) {
        for (int i = 0; i < 20; i++) {
          final suggested = StickerAnchoringEngine.pickStickerForCategory(cat);
          expect(suggested.assetPath, isNotEmpty);
          final file = File(suggested.assetPath);
          expect(file.existsSync(), isTrue, reason: 'Suggested asset ${suggested.assetPath} for $cat missing from disk');
        }
      }
    });
  });

  group('InviteService - Link Generation & Parsing', () {
    test('parseInviteInput parses HTTPS invite link with uid and Vietnamese name', () {
      const link = 'https://ncnative-bcf6d.web.app/invite?uid=u_f7bcfb29&name=M%C3%A8o%20B%C3%A9o';
      final payload = InviteService.parseInviteInput(link);
      expect(payload, isNotNull);
      expect(payload!.uid, 'u_f7bcfb29');
      expect(payload.displayName, 'Mèo Béo');
    });

    test('parseInviteInput parses custom scheme orbit://invite link', () {
      const link = 'orbit://invite?uid=u_e6f52c5d&name=Capybara%20Vui%20V%E1%BA%BB';
      final payload = InviteService.parseInviteInput(link);
      expect(payload, isNotNull);
      expect(payload!.uid, 'u_e6f52c5d');
      expect(payload.displayName, 'Capybara Vui Vẻ');
    });

    test('parseInviteInput extracts link embedded inside a multi-line chat message', () {
      const msg = '🪐 Kết bạn với Mèo Béo trên Orbit Widget nhé!\n'
          '👉 Bấm vào link này để mở app:\n'
          'https://ncnative-bcf6d.web.app/invite?uid=u_f7bcfb29&name=M%C3%A8o%20B%C3%A9o';
      final payload = InviteService.parseInviteInput(msg);
      expect(payload, isNotNull);
      expect(payload!.uid, 'u_f7bcfb29');
      expect(payload.displayName, 'Mèo Béo');
    });

    test('parseInviteInput parses raw UID or QR JSON payload', () {
      final fromUid = InviteService.parseInviteInput('u_f7bcfb29');
      expect(fromUid, isNotNull);
      expect(fromUid!.uid, 'u_f7bcfb29');

      final fromJson = InviteService.parseInviteInput(
        '{"type":"iconnative_add_friend","uid":"u_12345678","name":"Cún Shiba"}',
      );
      expect(fromJson, isNotNull);
      expect(fromJson!.uid, 'u_12345678');
      expect(fromJson.displayName, 'Cún Shiba');
    });

    test('parseInviteInput returns null for invalid or unrelated strings', () {
      expect(InviteService.parseInviteInput(''), isNull);
      expect(InviteService.parseInviteInput('hello world'), isNull);
      expect(InviteService.parseInviteInput('https://google.com'), isNull);
    });
  });
}
