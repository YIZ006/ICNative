import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'friend_service.dart';

class SoulmateData {
  final String uid;
  final String displayName;
  final String? avatarPath;
  final int startDateMillis;
  final String statusMood;
  final double? latitude;
  final double? longitude;

  SoulmateData({
    required this.uid,
    required this.displayName,
    this.avatarPath,
    required this.startDateMillis,
    this.statusMood = 'Đang nhớ bạn 💭',
    this.latitude,
    this.longitude,
  });

  int get daysTogether {
    final start = DateTime.fromMillisecondsSinceEpoch(startDateMillis);
    final now = DateTime.now();
    final diff = now.difference(start).inDays;
    return diff < 1 ? 1 : diff;
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
    );
  }
}

class SoulmateService {
  static final SoulmateService instance = SoulmateService._internal();
  SoulmateService._internal();

  static const _prefKey = 'orbit_soulmate_data';
  SoulmateData? _currentSoulmate;
  SoulmateData? get currentSoulmate => _currentSoulmate;

  final ValueNotifier<SoulmateData?> soulmateNotifier = ValueNotifier<SoulmateData?>(null);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _currentSoulmate = SoulmateData.fromMap(map);
        soulmateNotifier.value = _currentSoulmate;
      }
    } catch (e) {
      debugPrint('SoulmateService init error: $e');
    }
  }

  /// Ghim một người bạn vào Quỹ đạo Cận tâm (Soulmate / Bestie #1)
  Future<void> setSoulmate(Friend friend, {DateTime? startDate}) async {
    _currentSoulmate = SoulmateData(
      uid: friend.uid,
      displayName: friend.displayName,
      startDateMillis: (startDate ?? DateTime.now()).millisecondsSinceEpoch,
      statusMood: 'Đang online trên Orbit ✨',
    );
    soulmateNotifier.value = _currentSoulmate;
    await _persist();
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
    );
    soulmateNotifier.value = _currentSoulmate;
    await _persist();
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

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return double.parse((earthRadiusKm * c).toStringAsFixed(1));
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

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
}
