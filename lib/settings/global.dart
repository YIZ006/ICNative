import 'package:flutter/foundation.dart';

List<String> images = [];

// Chế độ Trải Nghiệm Mẫu (30 Bạn Bè): false cho bản phát hành chính thức
final ValueNotifier<bool> isDemoModeNotifier = ValueNotifier<bool>(false);
