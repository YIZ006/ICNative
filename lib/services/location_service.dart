import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final String displayName;
  final String? street;
  final String? landmark;
  final double latitude;
  final double longitude;
  final bool isLandmark;

  LocationResult({
    required this.displayName,
    this.street,
    this.landmark,
    required this.latitude,
    required this.longitude,
    required this.isLandmark,
  });
}

class LandmarkPOI {
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  const LandmarkPOI({
    required this.name,
    required this.lat,
    required this.lng,
    this.radiusMeters = 300,
  });
}

class LocationService {
  static final LocationService instance = LocationService._internal();
  LocationService._internal();

  /// Danh bạ địa danh tiêu biểu (Offline 0 VNĐ - Tự động nhận diện khi ở gần < 300m)
  static const List<LandmarkPOI> famousLandmarks = [
    // Hà Nội
    LandmarkPOI(name: 'Hồ Hoàn Kiếm', lat: 21.0285, lng: 105.8542, radiusMeters: 450),
    LandmarkPOI(name: 'Phố Cổ Hà Nội', lat: 21.0345, lng: 105.8504, radiusMeters: 400),
    LandmarkPOI(name: 'Nhà Thờ Lớn Hà Nội', lat: 21.0288, lng: 105.8493, radiusMeters: 250),
    LandmarkPOI(name: 'Lăng Chủ tịch Hồ Chí Minh', lat: 21.0368, lng: 105.8346, radiusMeters: 350),
    LandmarkPOI(name: 'Văn Miếu Quốc Tử Giám', lat: 21.0293, lng: 105.8358, radiusMeters: 300),
    LandmarkPOI(name: 'Hồ Tây', lat: 21.0583, lng: 105.8236, radiusMeters: 800),
    LandmarkPOI(name: 'Cầu Long Biên', lat: 21.0426, lng: 105.8569, radiusMeters: 400),
    LandmarkPOI(name: 'Vincom Center Bà Triệu', lat: 21.0116, lng: 105.8501, radiusMeters: 200),
    LandmarkPOI(name: 'Royal City', lat: 21.0028, lng: 105.8158, radiusMeters: 350),
    LandmarkPOI(name: 'Times City', lat: 20.9950, lng: 105.8675, radiusMeters: 400),
    LandmarkPOI(name: 'Lotte Center Hà Nội', lat: 21.0325, lng: 105.8126, radiusMeters: 250),
    LandmarkPOI(name: 'Keangnam Landmark 72', lat: 21.0173, lng: 105.7838, radiusMeters: 300),

    // TP. Hồ Chí Minh
    LandmarkPOI(name: 'Chợ Bến Thành', lat: 10.7725, lng: 106.6980, radiusMeters: 300),
    LandmarkPOI(name: 'Phố Đi Bộ Nguyễn Huệ', lat: 10.7745, lng: 106.7035, radiusMeters: 350),
    LandmarkPOI(name: 'Nhà Thờ Đức Bà', lat: 10.7798, lng: 106.6990, radiusMeters: 250),
    LandmarkPOI(name: 'Dinh Độc Lập', lat: 10.7770, lng: 106.6953, radiusMeters: 300),
    LandmarkPOI(name: 'Bưu Điện Trung Tâm Sài Gòn', lat: 10.7799, lng: 106.6999, radiusMeters: 200),
    LandmarkPOI(name: 'Landmark 81', lat: 10.7950, lng: 106.7219, radiusMeters: 350),
    LandmarkPOI(name: 'Bitexco Financial Tower', lat: 10.7716, lng: 106.7044, radiusMeters: 250),
    LandmarkPOI(name: 'Hồ Bán Nguyệt & Cầu Ánh Sao', lat: 10.7188, lng: 106.7170, radiusMeters: 350),
    LandmarkPOI(name: 'Thảo Cầm Viên Sài Gòn', lat: 10.7876, lng: 106.7053, radiusMeters: 400),

    // Đà Nẵng
    LandmarkPOI(name: 'Cầu Rồng Đà Nẵng', lat: 16.0611, lng: 108.2272, radiusMeters: 350),
    LandmarkPOI(name: 'Cầu Sông Hàn', lat: 16.0722, lng: 108.2272, radiusMeters: 300),
    LandmarkPOI(name: 'Bãi Biển Mỹ Khê', lat: 16.0600, lng: 108.2467, radiusMeters: 600),
    LandmarkPOI(name: 'Bà Nà Hills', lat: 15.9989, lng: 107.9961, radiusMeters: 800),

    // Đà Lạt & Huế
    LandmarkPOI(name: 'Quảng Trường Lâm Viên', lat: 11.9360, lng: 108.4447, radiusMeters: 350),
    LandmarkPOI(name: 'Chợ Đêm Đà Lạt', lat: 11.9424, lng: 108.4373, radiusMeters: 250),
    LandmarkPOI(name: 'Đại Nội Huế', lat: 16.4699, lng: 107.5786, radiusMeters: 500),
    LandmarkPOI(name: 'Cầu Trường Tiền', lat: 16.4678, lng: 107.5919, radiusMeters: 300),
  ];

  /// Yêu cầu cấp quyền và lấy tên địa điểm (Địa danh hoặc Tên đường thực tế)
  Future<LocationResult?> getCurrentLocationWithSmartName({
    void Function(String message)? onStatusMessage,
  }) async {
    try {
      // 1. Kiểm tra dịch vụ định vị GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onStatusMessage?.call('Dịch vụ GPS đang tắt. Vui lòng bật vị trí.');
        await Geolocator.openLocationSettings();
        return null;
      }

      // 2. Kiểm tra & hỏi quyền vị trí chính thức
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          onStatusMessage?.call('Cần cấp quyền vị trí để lấy tên địa điểm.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        onStatusMessage?.call('Quyền vị trí bị từ chối vĩnh viễn. Vui lòng bật trong Cài đặt.');
        await Geolocator.openAppSettings();
        return null;
      }

      // 3. Lấy vị trí GPS hiện tại (nhanh & chính xác)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      // 4. Ưu tiên 1: Quét xem có đang ở gần địa danh tiêu biểu nổi tiếng nào không
      final matchedLandmark = _findNearbyLandmark(position.latitude, position.longitude);
      if (matchedLandmark != null) {
        return LocationResult(
          displayName: matchedLandmark,
          landmark: matchedLandmark,
          latitude: position.latitude,
          longitude: position.longitude,
          isLandmark: true,
        );
      }

      // 5. Ưu tiên 2: Sử dụng Geocoder hệ thống Native On-Device (0 VNĐ)
      try {
        final placemarks = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;

          final name = p.name?.trim();
          final street = p.thoroughfare?.trim();
          final subLocality = p.subLocality?.trim();
          final locality = p.locality?.trim();
          final administrativeArea = p.administrativeArea?.trim();

          final isNumericOnly = name != null && RegExp(r'^\d+[\w/-]*$').hasMatch(name);
          final isSpecialPoi = name != null &&
              name.isNotEmpty &&
              !isNumericOnly &&
              name != street &&
              !name.toLowerCase().startsWith('đường') &&
              !name.toLowerCase().startsWith('phố');

          if (isSpecialPoi) {
            String fullDisplay = name;
            if (subLocality != null && subLocality.isNotEmpty && !name.contains(subLocality)) {
              fullDisplay = '$name, $subLocality';
            }
            return LocationResult(
              displayName: fullDisplay,
              landmark: name,
              street: street,
              latitude: position.latitude,
              longitude: position.longitude,
              isLandmark: true,
            );
          }

          // Hiển thị tên đường kèm Phường/Quận
          if (street != null && street.isNotEmpty) {
            final streetName = street.toLowerCase().startsWith('đường') ||
                    street.toLowerCase().startsWith('phố') ||
                    street.toLowerCase().startsWith('ngõ')
                ? street
                : 'Đường $street';

            final areaSuffix = (subLocality != null && subLocality.isNotEmpty)
                ? ', $subLocality'
                : (locality != null && locality.isNotEmpty ? ', $locality' : '');

            return LocationResult(
              displayName: '$streetName$areaSuffix',
              street: streetName,
              latitude: position.latitude,
              longitude: position.longitude,
              isLandmark: false,
            );
          }

          // Không có tên đường: hiển thị Phường/Quận/Thành phố
          final parts = [subLocality, locality, administrativeArea]
              .whereType<String>().where((s) => s.isNotEmpty)
              .toList();
          final areaName = parts.isNotEmpty ? parts.take(2).join(', ') : 'Việt Nam';

          return LocationResult(
            displayName: areaName,
            street: areaName,
            latitude: position.latitude,
            longitude: position.longitude,
            isLandmark: false,
          );
        }
      } catch (geocodeErr) {
        debugPrint('Geocoder error: $geocodeErr');
      }

      // Fallback khi offline: Toạ độ GPS gọn gàng
      final latStr = position.latitude.toStringAsFixed(2);
      final lngStr = position.longitude.toStringAsFixed(2);
      return LocationResult(
        displayName: 'GPS: $latStr, $lngStr',
        latitude: position.latitude,
        longitude: position.longitude,
        isLandmark: false,
      );
    } catch (e) {
      debugPrint('Get location error: $e');
      onStatusMessage?.call('Lỗi khi lấy vị trí: $e');
      return null;
    }
  }

  /// Tính khoảng cách Haversine đến các địa danh nổi tiếng
  String? _findNearbyLandmark(double lat, double lng) {
    for (final landmark in famousLandmarks) {
      final distance = _calculateDistanceMeters(lat, lng, landmark.lat, landmark.lng);
      if (distance <= landmark.radiusMeters) {
        return landmark.name;
      }
    }
    return null;
  }

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // mét
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
