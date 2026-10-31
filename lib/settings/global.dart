import 'package:flutter/foundation.dart';

List<String> images = [];

/// Cờ xác định phiên bản build (Clean Release vs Demo Showcase)
/// Mặc định false cho Bản Chuẩn Sạch (Clean Release)
/// Đặt true khi build với --dart-define=DEFAULT_DEMO_MODE=true cho Bản Demo Trải Nghiệm
const bool isDefaultDemoMode = bool.fromEnvironment('DEFAULT_DEMO_MODE', defaultValue: false);

/// ValueNotifier điều khiển chế độ hiển thị dữ liệu mẫu (Demo Mode)
final ValueNotifier<bool> isDemoModeNotifier = ValueNotifier<bool>(isDefaultDemoMode);
