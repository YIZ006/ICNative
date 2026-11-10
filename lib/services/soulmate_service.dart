import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'friend_service.dart';
import 'location_service.dart';
import 'sync_service.dart';

class SoulmateData {
  final String uid;
  final String displayName;
  final String? avatarPath;
  final int startDateMillis;
  final String statusMood;
  final double? latitude;
  final double? longitude;
  final String? placeName;
  final int? lastActiveMillis;
  final String? lastNote;
  final int? lastNoteTime;

  SoulmateData({
    required this.uid,
    required this.displayName,
    this.avatarPath,
    required this.startDateMillis,
    this.statusMood = 'Đang nhớ bạn 💭',
    this.latitude,
    this.longitude,
    this.placeName,
    this.lastActiveMillis,
    this.lastNote,
    this.lastNoteTime,
  });

  int get daysTogether {
    final start = DateTime.fromMillisecondsSinceEpoch(startDateMillis);
    final now = DateTime.now();
    final diff = now.difference(start).inDays;
    return diff < 1 ? 1 : diff;
  }

  bool get isOnline {
    if (lastActiveMillis == null) return false;
    final diff = DateTime.now().millisecondsSinceEpoch - lastActiveMillis!;
    return diff < 15 * 60 * 1000;
  }

  String get timeAgo {
    if (lastActiveMillis == null) return 'Vừa cập nhật';
    final diffSeconds = (DateTime.now().millisecondsSinceEpoch - lastActiveMillis!) ~/ 1000;
    if (diffSeconds < 60) return 'Vừa xong';
    final diffMinutes = diffSeconds ~/ 60;
    if (diffMinutes < 60) return '$diffMinutes phút trước';
    final diffHours = diffMinutes ~/ 60;
    if (diffHours < 24) return '$diffHours giờ trước';
    return '${diffHours ~/ 24} ngày trước';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarPath': avatarPath,
      'startDateMillis': startDateMillis,
      'statusMood': statusMood,
      'latitude': latitude,
      'longitude': longitude,
      'placeName': placeName,
      'lastActiveMillis': lastActiveMillis,
      'lastNote': lastNote,
      'lastNoteTime': lastNoteTime,
    };
  }

  factory SoulmateData.fromMap(Map<String, dynamic> map) {
    return SoulmateData(
      uid: map['uid'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Soulmate',
      avatarPath: map['avatarPath'] as String?,
      startDateMillis: (map['startDateMillis'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      statusMood: map['statusMood'] as String? ?? 'Đang nhớ bạn 💭',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      placeName: map['placeName'] as String?,
      lastActiveMillis: (map['lastActiveMillis'] as num?)?.toInt(),
      lastNote: map['lastNote'] as String?,
      lastNoteTime: (map['lastNoteTime'] as num?)?.toInt(),
    );
  }
}

class CoupleInteraction {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String type; // 'heartbeat', 'kiss', 'miss_you', 'hug', 'poke', 'love_note'
  final String? message;
  final int timestamp;
  final bool isRead;

  CoupleInteraction({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.type,
    this.message,
    required this.timestamp,
    this.isRead = false,
  });

  String get typeEmoji {
    switch (type) {
      case 'heartbeat':
        return '💓';
      case 'kiss':
        return '💋';
      case 'miss_you':
        return '🥺';
      case 'hug':
        return '🫂';
      case 'poke':
        return '🛸';
      case 'love_note':
        return '💌';
      default:
        return '✨';
    }
  }

  String get typeTitle {
    switch (type) {
      case 'heartbeat':
        return 'Đã gửi nhịp tim đồng bộ';
      case 'kiss':
        return 'Đã gửi một nụ hôn nồng ấm';
      case 'miss_you':
        return 'Đang nhớ bạn rất nhiều';
      case 'hug':
        return 'Đã gửi một cái ôm thật chặt';
      case 'poke':
        return 'Đã chọt màn hình của bạn';
      case 'love_note':
        return 'Đã ghim lời nhắn lên Widget';
      default:
        return 'Đã gửi tương tác';
    }
  }

  String get timeAgo {
    final diffSeconds = (DateTime.now().millisecondsSinceEpoch - timestamp) ~/ 1000;
    if (diffSeconds < 60) return 'Vừa xong';
    final diffMinutes = diffSeconds ~/ 60;
    if (diffMinutes < 60) return '$diffMinutes phút trước';
    final diffHours = diffMinutes ~/ 60;
    if (diffHours < 24) return '$diffHours giờ trước';
    return '${diffHours ~/ 24} ngày trước';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'receiverId': receiverId,
      'type': type,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  factory CoupleInteraction.fromMap(Map<String, dynamic> map) {
    return CoupleInteraction(
      id: map['id'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Người ấy',
      receiverId: map['receiverId'] as String? ?? '',
      type: map['type'] as String? ?? 'heartbeat',
      message: map['message'] as String?,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isRead: map['isRead'] as bool? ?? false,
    );
  }
}

class SoulmateService {
  static final SoulmateService instance = SoulmateService._internal();
  SoulmateService._internal();

  static const _prefKey = 'orbit_soulmate_data';
  static const _prefInteractionsKey = 'orbit_soulmate_interactions';

  SoulmateData? _currentSoulmate;
  SoulmateData? get currentSoulmate => _currentSoulmate;

  final ValueNotifier<SoulmateData?> soulmateNotifier = ValueNotifier<SoulmateData?>(null);
  final ValueNotifier<List<CoupleInteraction>> interactionsNotifier = ValueNotifier<List<CoupleInteraction>>([]);
  final ValueNotifier<CoupleInteraction?> incomingInteractionNotifier = ValueNotifier<CoupleInteraction?>(null);

  final List<CoupleInteraction> _recentInteractions = [];
  LocationResult? myLastLocation;

  StreamSubscription<DocumentSnapshot>? _partnerStatusSub;
  StreamSubscription<QuerySnapshot>? _interactionsSub;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _currentSoulmate = SoulmateData.fromMap(map);
        soulmateNotifier.value = _currentSoulmate;
      }

      // Khôi phục lịch sử tương tác
      final rawInteractions = prefs.getString(_prefInteractionsKey);
      if (rawInteractions != null && rawInteractions.isNotEmpty) {
        final list = jsonDecode(rawInteractions) as List<dynamic>;
        _recentInteractions.clear();
        for (var item in list) {
          _recentInteractions.add(CoupleInteraction.fromMap(item as Map<String, dynamic>));
        }
        interactionsNotifier.value = List.unmodifiable(_recentInteractions);
      }

      // Lắng nghe dữ liệu thời gian thực từ Firestore nếu có kết nối Cloud
      if (AuthService.isCloudConfigured) {
        _startListeningToPartner();
        _startListeningToInteractions();
      }
    } catch (e) {
      debugPrint('SoulmateService init error: $e');
    }
  }

  /// Ghim một người bạn vào Quỹ đạo Cận tâm (Soulmate / Bestie #1)
  Future<void> setSoulmate(Friend friend, {DateTime? startDate, String? placeName, double? lat, double? lng}) async {
    _currentSoulmate = SoulmateData(
      uid: friend.uid,
      displayName: friend.displayName,
      avatarPath: SyncService.friendLatestPhotos[friend.uid],
      startDateMillis: (startDate ?? DateTime.now()).millisecondsSinceEpoch,
      statusMood: 'Đang online trên Orbit ✨',
      placeName: placeName ?? 'Hồ Tây, Hà Nội',
      latitude: lat ?? 21.0583,
      longitude: lng ?? 105.8236,
      lastActiveMillis: DateTime.now().millisecondsSinceEpoch,
    );
    soulmateNotifier.value = _currentSoulmate;
    await _persist();

    if (AuthService.isCloudConfigured) {
      _startListeningToPartner();
      _startListeningToInteractions();
    }
  }

  /// Cập nhật tâm trạng / status
  Future<void> updateMood(String mood) async {
    if (_currentSoulmate == null) return;
    _currentSoulmate = SoulmateData(
      uid: _currentSoulmate!.uid,
      displayName: _currentSoulmate!.displayName,
      avatarPath: _currentSoulmate!.avatarPath,
      startDateMillis: _currentSoulmate!.startDateMillis,
      statusMood: mood,
      latitude: _currentSoulmate!.latitude,
      longitude: _currentSoulmate!.longitude,
      placeName: _currentSoulmate!.placeName,
      lastActiveMillis: DateTime.now().millisecondsSinceEpoch,
      lastNote: _currentSoulmate!.lastNote,
      lastNoteTime: _currentSoulmate!.lastNoteTime,
    );
    soulmateNotifier.value = _currentSoulmate;
    await _persist();
    await broadcastMyLocationAndStatus();
  }

  /// Ghim lời nhắn yêu thương lên Widget của Soulmate (Love Note)
  Future<void> updateLoveNote(String note) async {
    if (_currentSoulmate == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _currentSoulmate = SoulmateData(
      uid: _currentSoulmate!.uid,
      displayName: _currentSoulmate!.displayName,
      avatarPath: _currentSoulmate!.avatarPath,
      startDateMillis: _currentSoulmate!.startDateMillis,
      statusMood: _currentSoulmate!.statusMood,
      latitude: _currentSoulmate!.latitude,
      longitude: _currentSoulmate!.longitude,
      placeName: _currentSoulmate!.placeName,
      lastActiveMillis: now,
      lastNote: note,
      lastNoteTime: now,
    );
    soulmateNotifier.value = _currentSoulmate;
    await _persist();

    // Đồng bộ lên Home Widget
    try {
      await HomeWidget.saveWidgetData<String>('soulmate_last_note', note);
      await SyncService.updateAllHomeWidgets();
    } catch (_) {}

    // Gửi tương tác love_note sang cho người kia
    await sendInteraction(type: 'love_note', message: note);
  }

  /// Cập nhật vị trí GPS chuẩn và đẩy thông tin lên Firestore cho đối phương thấy
  Future<LocationResult?> broadcastMyLocationAndStatus() async {
    try {
      final loc = await LocationService.instance.getCurrentLocationWithSmartName();
      if (loc != null) {
        myLastLocation = loc;

        final myProfile = AuthService.instance.currentUser;
        if (myProfile != null && AuthService.isCloudConfigured) {
          await FirebaseFirestore.instance.collection('soulmate_status').doc(myProfile.uid).set({
            'uid': myProfile.uid,
            'displayName': myProfile.displayName,
            'avatarPath': myProfile.avatarPath,
            'latitude': loc.latitude,
            'longitude': loc.longitude,
            'placeName': loc.displayName,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'statusMood': _currentSoulmate?.statusMood ?? 'Đang online trên Orbit ✨',
            'lastNote': _currentSoulmate?.lastNote,
          }, SetOptions(merge: true)).timeout(const Duration(seconds: 6));
        }

        // Cập nhật khoảng cách lên HomeWidget
        if (_currentSoulmate?.latitude != null && _currentSoulmate?.longitude != null) {
          final dist = calculateDistanceKm(loc.latitude, loc.longitude);
          await HomeWidget.saveWidgetData<String>('soulmate_distance', formatDistance(dist));
          await HomeWidget.saveWidgetData<String>('soulmate_partner_place', _currentSoulmate?.placeName ?? '');
          await SyncService.updateAllHomeWidgets();
        }

        return loc;
      }
    } catch (e) {
      debugPrint('Error broadcasting soulmate location: $e');
    }
    return null;
  }

  /// Gửi tương tác trực tiếp (Nhịp tim, Nụ hôn, Nhớ bạn, Cái ôm, Ping)
  Future<bool> sendInteraction({
    required String type,
    String? message,
  }) async {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null || _currentSoulmate == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final interaction = CoupleInteraction(
      id: 'act_${myProfile.uid}_$now',
      senderId: myProfile.uid,
      senderName: myProfile.displayName,
      receiverId: _currentSoulmate!.uid,
      type: type,
      message: message,
      timestamp: now,
    );

    // Lưu vào lịch sử cục bộ
    _recentInteractions.insert(0, interaction);
    if (_recentInteractions.length > 30) {
      _recentInteractions.removeLast();
    }
    interactionsNotifier.value = List.unmodifiable(_recentInteractions);
    await _persistInteractions();

    // Rung phản hồi haptic người gửi
    _triggerSenderHaptic(type);

    // Đẩy lên Firestore nếu có cấu hình Cloud
    if (AuthService.isCloudConfigured) {
      try {
        await FirebaseFirestore.instance
            .collection('soulmate_interactions')
            .doc(interaction.id)
            .set(interaction.toMap())
            .timeout(const Duration(seconds: 6));
      } catch (e) {
        debugPrint('Error sending interaction to Firestore: $e');
      }
    } else {
      // Mô phỏng đối phương phản hồi lại sau 2.5s (Phục vụ Test / Demo Showcase 100% Offline 0 VNĐ)
      _simulatePartnerResponse(type);
    }

    return true;
  }

  /// Đóng thông báo tương tác đang nổi
  void dismissIncomingInteraction() {
    incomingInteractionNotifier.value = null;
  }

  /// Lắng nghe trạng thái toạ độ và địa danh thời gian thực của Soulmate
  void _startListeningToPartner() {
    if (_currentSoulmate == null || !AuthService.isCloudConfigured) return;

    _partnerStatusSub?.cancel();
    _partnerStatusSub = FirebaseFirestore.instance
        .collection('soulmate_status')
        .doc(_currentSoulmate!.uid)
        .snapshots()
        .listen(
      (snap) {
        if (snap.exists && snap.data() != null) {
          final data = snap.data()!;
          final lat = (data['latitude'] as num?)?.toDouble();
          final lng = (data['longitude'] as num?)?.toDouble();
          final place = data['placeName'] as String?;
          final mood = data['statusMood'] as String?;
          final updated = (data['updatedAt'] as num?)?.toInt();
          final note = data['lastNote'] as String?;

          _currentSoulmate = SoulmateData(
            uid: _currentSoulmate!.uid,
            displayName: _currentSoulmate!.displayName,
            avatarPath: _currentSoulmate!.avatarPath,
            startDateMillis: _currentSoulmate!.startDateMillis,
            statusMood: mood ?? _currentSoulmate!.statusMood,
            latitude: lat ?? _currentSoulmate!.latitude,
            longitude: lng ?? _currentSoulmate!.longitude,
            placeName: place ?? _currentSoulmate!.placeName,
            lastActiveMillis: updated ?? _currentSoulmate!.lastActiveMillis,
            lastNote: note ?? _currentSoulmate!.lastNote,
            lastNoteTime: updated,
          );
          soulmateNotifier.value = _currentSoulmate;
          _persist();
        }
      },
      onError: (e) => debugPrint('Soulmate status listen error: $e'),
    );
  }

  /// Lắng nghe các tương tác trực tiếp gửi đến mình thời gian thực
  void _startListeningToInteractions() {
    final myProfile = AuthService.instance.currentUser;
    if (myProfile == null || !AuthService.isCloudConfigured) return;

    _interactionsSub?.cancel();
    _interactionsSub = FirebaseFirestore.instance
        .collection('soulmate_interactions')
        .where('receiverId', isEqualTo: myProfile.uid)
        .snapshots()
        .listen(
      (snap) {
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null) {
              final interaction = CoupleInteraction.fromMap(data);
              // Bỏ qua tương tác quá cũ (> 5 phút trước)
              final age = DateTime.now().millisecondsSinceEpoch - interaction.timestamp;
              if (age < 5 * 60 * 1000) {
                _handleIncomingInteraction(interaction);
              }
            }
          }
        }
      },
      onError: (e) => debugPrint('Interactions listen error: $e'),
    );
  }

  /// Xử lý khi nhận được tương tác trực tiếp từ đối phương
  void _handleIncomingInteraction(CoupleInteraction interaction) {
    // 1. Thêm vào lịch sử tương tác
    if (!_recentInteractions.any((i) => i.id == interaction.id)) {
      _recentInteractions.insert(0, interaction);
      if (_recentInteractions.length > 30) {
        _recentInteractions.removeLast();
      }
      interactionsNotifier.value = List.unmodifiable(_recentInteractions);
      _persistInteractions();
    }

    // 2. Kích hoạt banner thông báo nổi thời gian thực
    incomingInteractionNotifier.value = interaction;

    // 3. Rung haptic đặc thù theo nhịp điệu tương tác
    _triggerReceiverHaptic(interaction.type);

    // 4. Đồng bộ lên Home Widget màn hình chính
    try {
      HomeWidget.saveWidgetData<String>(
        'soulmate_last_interaction',
        '${interaction.senderName}: ${interaction.typeEmoji} ${interaction.message ?? interaction.typeTitle}',
      );
      SyncService.updateAllHomeWidgets();
    } catch (_) {}
  }

  void _triggerSenderHaptic(String type) {
    switch (type) {
      case 'heartbeat':
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 220), () => HapticFeedback.heavyImpact());
        break;
      case 'kiss':
        HapticFeedback.mediumImpact();
        break;
      case 'poke':
        HapticFeedback.selectionClick();
        break;
      default:
        HapticFeedback.lightImpact();
    }
  }

  void _triggerReceiverHaptic(String type) {
    switch (type) {
      case 'heartbeat':
        // Nhịp đập tim thình thịch 3 lần
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 250), () => HapticFeedback.heavyImpact());
        });
        break;
      case 'kiss':
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.lightImpact());
        break;
      case 'poke':
        HapticFeedback.heavyImpact();
        break;
      default:
        HapticFeedback.vibrate();
    }
  }

  /// Mô phỏng người ấy phản hồi lại khi chạy offline / Demo Showcase Mode (0 VNĐ)
  void _simulatePartnerResponse(String sentType) {
    final soulmate = _currentSoulmate;
    if (soulmate == null) return;

    Future.delayed(const Duration(milliseconds: 2400), () {
      final now = DateTime.now().millisecondsSinceEpoch;
      CoupleInteraction response;
      switch (sentType) {
        case 'heartbeat':
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'heartbeat',
            message: 'Đã nhận được nhịp tim của bạn và đập cùng tần số! 💓',
            timestamp: now,
          );
          break;
        case 'kiss':
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'kiss',
            message: 'Gửi lại cho bạn một nụ hôn nồng ấm nè 😘💋',
            timestamp: now,
          );
          break;
        case 'miss_you':
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'miss_you',
            message: 'Tớ cũng đang nhớ bạn rất nhiều! 🥺🤍',
            timestamp: now,
          );
          break;
        case 'hug':
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'hug',
            message: 'Ôm bạn một cái thật ấm áp nhé 🫂',
            timestamp: now,
          );
          break;
        case 'poke':
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'poke',
            message: 'Đang online đây nè, chọt lại bạn nè 🛸',
            timestamp: now,
          );
          break;
        case 'love_note':
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'love_note',
            message: 'Đã đọc lời nhắn và ghim lên màn hình rồi nhé 🥰',
            timestamp: now,
          );
          break;
        default:
          response = CoupleInteraction(
            id: 'sim_$now',
            senderId: soulmate.uid,
            senderName: soulmate.displayName,
            receiverId: 'my_uid',
            type: 'heartbeat',
            message: 'Đã nhận được tín hiệu vũ trụ từ bạn ✨',
            timestamp: now,
          );
      }
      _handleIncomingInteraction(response);
    });
  }

  /// Tính khoảng cách địa lý Haversine (km) giữa 2 người (100% Offline, 0 VNĐ)
  double? calculateDistanceKm(double myLat, double myLng) {
    if (_currentSoulmate?.latitude == null || _currentSoulmate?.longitude == null) {
      return null;
    }
    const double earthRadiusKm = 6371.0;
    final dLat = _degToRad(_currentSoulmate!.latitude! - myLat);
    final dLon = _degToRad(_currentSoulmate!.longitude! - myLng);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(myLat)) *
            math.cos(_degToRad(_currentSoulmate!.latitude!)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final clampedA = a.clamp(0.0, 1.0);
    final c = 2 * math.atan2(math.sqrt(clampedA), math.sqrt(1.0 - clampedA));
    return double.parse((earthRadiusKm * c).toStringAsFixed(1));
  }

  /// Định dạng khoảng cách thân thiện cho cặp đôi
  String formatDistance(double? km) {
    if (km == null) return 'Đang định vị...';
    if (km < 0.05) return 'Cùng một nơi (0 km) 💞';
    if (km < 1.0) return '${(km * 1000).round()} m (Đang rất gần!)';
    return '$km km';
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  Future<void> clearSoulmate() async {
    _currentSoulmate = null;
    soulmateNotifier.value = null;
    _recentInteractions.clear();
    interactionsNotifier.value = [];
    incomingInteractionNotifier.value = null;
    _partnerStatusSub?.cancel();
    _interactionsSub?.cancel();
    await _persist();
    await _persistInteractions();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentSoulmate != null) {
        await prefs.setString(_prefKey, jsonEncode(_currentSoulmate!.toMap()));
      } else {
        await prefs.remove(_prefKey);
      }
    } catch (e) {
      debugPrint('SoulmateService persist error: $e');
    }
  }

  Future<void> _persistInteractions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapped = _recentInteractions.map((i) => i.toMap()).toList();
      await prefs.setString(_prefInteractionsKey, jsonEncode(mapped));
    } catch (e) {
      debugPrint('SoulmateService persistInteractions error: $e');
    }
  }
}
