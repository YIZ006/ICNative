import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icnative/services/friend_service.dart';
import 'package:icnative/services/soulmate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('Soulmate & Couple Interaction Feature Tests', () {
    test('SoulmateData serialization and new location/status fields', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final soulmate = SoulmateData(
        uid: 'soulmate_123',
        displayName: 'Mèo Béo Đáng Yêu #554',
        startDateMillis: now - (50 * 24 * 60 * 60 * 1000), // 50 days ago
        statusMood: 'Đang uống trà sữa 🧋',
        latitude: 21.0285,
        longitude: 105.8542,
        placeName: 'Hồ Hoàn Kiếm, Hà Nội',
        lastActiveMillis: now - (2 * 60 * 1000), // 2 mins ago
        lastNote: 'Tối nay 7h đón tui nhé ❤️',
        lastNoteTime: now,
      );

      expect(soulmate.daysTogether, equals(50));
      expect(soulmate.isOnline, isTrue);
      expect(soulmate.timeAgo, equals('2 phút trước'));
      expect(soulmate.placeName, equals('Hồ Hoàn Kiếm, Hà Nội'));
      expect(soulmate.lastNote, equals('Tối nay 7h đón tui nhé ❤️'));

      final map = soulmate.toMap();
      final restored = SoulmateData.fromMap(map);

      expect(restored.uid, equals('soulmate_123'));
      expect(restored.displayName, equals('Mèo Béo Đáng Yêu #554'));
      expect(restored.statusMood, equals('Đang uống trà sữa 🧋'));
      expect(restored.latitude, equals(21.0285));
      expect(restored.longitude, equals(105.8542));
      expect(restored.placeName, equals('Hồ Hoàn Kiếm, Hà Nội'));
      expect(restored.lastNote, equals('Tối nay 7h đón tui nhé ❤️'));
    });

    test('CoupleInteraction serialization and emojis', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final heartbeat = CoupleInteraction(
        id: 'act_1',
        senderId: 'user_a',
        senderName: 'Mèo Béo',
        receiverId: 'user_b',
        type: 'heartbeat',
        message: 'Thình thịch',
        timestamp: now,
      );

      expect(heartbeat.typeEmoji, equals('💓'));
      expect(heartbeat.typeTitle, contains('nhịp tim'));
      expect(heartbeat.timeAgo, equals('Vừa xong'));

      final kiss = CoupleInteraction(
        id: 'act_2',
        senderId: 'user_a',
        senderName: 'Mèo Béo',
        receiverId: 'user_b',
        type: 'kiss',
        timestamp: now - (15 * 60 * 1000), // 15 mins ago
      );
      expect(kiss.typeEmoji, equals('💋'));
      expect(kiss.timeAgo, equals('15 phút trước'));

      final note = CoupleInteraction(
        id: 'act_3',
        senderId: 'user_a',
        senderName: 'Mèo Béo',
        receiverId: 'user_b',
        type: 'love_note',
        message: 'Ghim lên widget nè',
        timestamp: now,
      );
      expect(note.typeEmoji, equals('💌'));
      expect(note.typeTitle, contains('Widget'));

      final map = note.toMap();
      final restored = CoupleInteraction.fromMap(map);
      expect(restored.type, equals('love_note'));
      expect(restored.message, equals('Ghim lên widget nè'));
    });

    test('SoulmateService formatDistance outputs clean couple-friendly units', () {
      final service = SoulmateService.instance;

      expect(service.formatDistance(null), equals('Đang định vị...'));
      expect(service.formatDistance(0.02), equals('Cùng một nơi (0 km) 💞'));
      expect(service.formatDistance(0.35), equals('350 m (Đang rất gần!)'));
      expect(service.formatDistance(0.8), equals('800 m (Đang rất gần!)'));
      expect(service.formatDistance(2.4), equals('2.4 km'));
      expect(service.formatDistance(15.7), equals('15.7 km'));
    });

    test('calculateDistanceKm handles real GPS coordinates accurately without NaN', () async {
      final service = SoulmateService.instance;
      final friend = Friend(uid: 'friend_test', displayName: 'Bạn Hồ Tây', addedAt: DateTime.now().millisecondsSinceEpoch);
      await service.setSoulmate(friend, lat: 21.0583, lng: 105.8236, placeName: 'Hồ Tây, Hà Nội');

      // Vị trí người dùng tại Hồ Hoàn Kiếm (21.0285, 105.8542)
      final dist = service.calculateDistanceKm(21.0285, 105.8542);
      expect(dist, isNotNull);
      expect(dist!, greaterThan(4.4));
      expect(dist, lessThan(4.8));
      expect(service.formatDistance(dist), equals('$dist km'));

      // Khi ở cùng vị trí
      final zeroDist = service.calculateDistanceKm(21.0583, 105.8236);
      expect(zeroDist, equals(0.0));
      expect(service.formatDistance(zeroDist), equals('Cùng một nơi (0 km) 💞'));
    });
  });
}
