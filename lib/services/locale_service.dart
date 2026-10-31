import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  vi('Tiếng Việt', '🇻🇳', 'vi'),
  en('English', '🇬🇧', 'en');

  final String label;
  final String flag;
  final String code;

  const AppLanguage(this.label, this.flag, this.code);
}

class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const String _prefKey = 'app_language_code';

  final ValueNotifier<AppLanguage> currentLanguage = ValueNotifier<AppLanguage>(AppLanguage.vi);

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);

      if (savedCode != null) {
        if (savedCode == 'en') {
          currentLanguage.value = AppLanguage.en;
        } else {
          currentLanguage.value = AppLanguage.vi;
        }
      } else {
        // Tự động nhận diện theo ngôn ngữ hệ thống thiết bị (System Locale)
        final systemLocale = Platform.localeName.toLowerCase();
        if (systemLocale.startsWith('vi')) {
          currentLanguage.value = AppLanguage.vi;
        } else {
          currentLanguage.value = AppLanguage.en;
        }
      }
    } catch (e) {
      debugPrint('LocaleService init error: $e');
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    currentLanguage.value = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  Future<void> toggleLanguage() async {
    final next = currentLanguage.value == AppLanguage.vi ? AppLanguage.en : AppLanguage.vi;
    await setLanguage(next);
  }

  bool get isVietnamese => currentLanguage.value == AppLanguage.vi;

  String t(String key) {
    final isVi = currentLanguage.value == AppLanguage.vi;
    final map = isVi ? _viMap : _enMap;
    return map[key] ?? _viMap[key] ?? key;
  }

  static final Map<String, String> _viMap = {
    // App Branding
    'app_name': 'Orbit',
    'app_tagline': 'Vòng Tròn Quan Hệ & Gắn Kết Yêu Thương',

    // Top Bar
    'widget_installed': 'Widget Hoạt Động',
    'status_connected': 'Đã kết nối',
    'profile_title': 'Trang Cá Nhân & Cài Đặt',
    'friends_title': 'Mạng Lưới Bạn Bè',
    'add_friend': 'Thêm Bạn',
    'widget_guide': 'Hướng Dẫn Widget',

    // Camera & Viewfinder
    'tap_to_expand': 'Bấm để phóng to khung ngắm vuông',
    'tap_to_collapse': 'Bấm để thu nhỏ về hình tròn',
    'all_friends': 'Tất cả bạn bè',
    'send_to_all': 'Gửi cho toàn bộ bạn bè',
    'send_to': 'Gửi riêng cho',
    'capturing': 'Đang chụp...',
    'camera_initializing': 'Đang mở ống kính...',
    'camera_error': 'Không thể kết nối máy ảnh',

    // Location & Time Tagging
    'loc_btn_title': 'Gán Vị Trí & Thời Gian',
    'loc_detecting': 'Đang xác định vị trí...',
    'loc_permission_needed': 'Cần cấp quyền vị trí để gán địa danh',
    'loc_landmark_found': 'Địa danh gần bạn',
    'loc_road_found': 'Tuyến đường',
    'loc_tag_added': 'Đã gán nhãn địa điểm',

    // History & Memories
    'history_title': 'Kho Ảnh Kỷ Niệm',
    'history_empty_title': 'Chưa Có Kỷ Niệm Nào',
    'history_empty_subtitle': 'Hãy chụp ảnh và gửi widget để lưu giữ khoảnh khắc!',
    'history_back_to_camera': 'Quay Lại Camera',
    'history_swipe_hint': 'Vuốt xuống hoặc bấm để về Camera',
    'history_photos_count': 'ảnh',
    'history_delete_confirm': 'Xóa ảnh này khỏi kho kỷ niệm?',
    'history_cancel': 'Hủy',
    'history_delete': 'Xóa',

    // Widget Guide Screen
    'wg_title': 'Hướng Dẫn Cài Đặt Widget',
    'wg_subtitle': 'Đưa bạn bè và người thương lên màn hình chính',
    'wg_quick_pin_section': 'Cài Đặt Nhanh 1-Chạm (Tự Động)',
    'wg_pin_galaxy_btn': 'Ghim Thiên Hà Vệ Tinh',
    'wg_pin_pebble_btn': 'Ghim Đá Cuội Gợn Sóng',
    'wg_pin_success': 'Đã mở màn hình chính! Bạn có thể chạm giữ widget trong hộp thoại để kéo thả tới vị trí mong muốn.',
    'wg_pin_not_supported': 'Trình khởi chạy của máy chưa hỗ trợ ghim tự động. Vui lòng làm theo hướng dẫn thủ công bên dưới.',
    'wg_manual_guide_title': 'Cách Cài Đặt Thủ Công',
    'wg_step_1': '1. Quay về màn hình chính, nhấn giữ vào khoảng trống bất kỳ.',
    'wg_step_2': '2. Chọn mục "Tiện ích" hoặc "Widgets".',
    'wg_step_3': '3. Tìm kiếm "Orbit", chọn kích thước mong muốn (2x2 hoặc 4x2) rồi kéo ra màn hình.',
    'wg_step_4': '4. Chạm vào widget để chụp và cập nhật ảnh mới bất kỳ lúc nào!',
    'wg_ios_notice_title': 'Cơ Chế Tiện Ích Trên iOS (iPhone/iPad)',
    'wg_ios_notice_desc': 'Theo cơ chế bảo mật của Apple WidgetKit, tiện ích trên iPhone được thêm trực tiếp từ Màn hình chính theo các bước đơn giản bên dưới.',
    'wg_ios_styles_section': 'Các Kiểu Tiện Ích Orbit Trên iOS',
    'wg_ios_supported_sizes': 'Cỡ Nhỏ (2x2) & Vừa (4x2)',
    'wg_ios_ready_badge': '✨ Đã sẵn sàng trong Thư viện tiện ích',
    'wg_ios_manual_guide_title': 'Cách Thêm Widget Trên iPhone (iOS 14+)',
    'wg_ios_step_1': '1. Quay về Màn hình chính (Home Screen), chạm và giữ một vùng trống bất kỳ cho đến khi các ứng dụng rung lắc.',
    'wg_ios_step_2': '2. Chạm vào nút dấu cộng (+) ở góc trên cùng bên trái màn hình.',
    'wg_ios_step_3': '3. Tìm kiếm "Orbit" trong danh sách tiện ích của iPhone.',
    'wg_ios_step_4': '4. Chọn kiểu và kích thước Widget mong muốn (Nhỏ hoặc Vừa), rồi nhấn "Thêm tiện ích" (Add Widget).',
    'wg_ios_step_5': '5. Kéo thả widget đến vị trí yêu thích rồi nhấn "Xong" (Done) ở góc trên bên phải.',
    'wg_ios_step_6': '6. Chạm vào Widget bất cứ lúc nào để mở kính ngắm chụp và cập nhật ảnh mới gửi đến bạn bè!',
    'wg_ios_lockscreen_tip': '💡 Mẹo Màn hình khóa (iOS 16+): Nhấn giữ Màn hình khóa > chạm "Tùy chỉnh" > chọn Màn hình khóa > "Thêm tiện ích" > chọn Orbit để luôn thấy khoảnh khắc bạn bè!',
    'wg_ios_troubleshoot_title': '❓ Chưa thấy Orbit trong danh sách Tiện ích?',
    'wg_ios_troubleshoot_step_1': '1. Mở ứng dụng Orbit lên ít nhất 1 lần để iOS kích hoạt và nạp dịch vụ tiện ích.',
    'wg_ios_troubleshoot_step_2': '2. Thử tìm kiếm với cả hai từ khóa: "Orbit" hoặc "ICNative" trong thanh tìm kiếm.',
    'wg_ios_troubleshoot_step_3': '3. Khởi động lại iPhone (Tắt nguồn rồi bật lại): Với app cài qua file IPA (Sideload / AltStore / TrollStore / Scarlet), iOS SpringBoard cần khởi động lại máy để làm mới bộ nhớ đệm tiện ích.',

    // Settings & Profile
    'settings_title': 'Cài Đặt',
    'language_setting': 'Ngôn Ngữ (Language)',
    'language_toggle_btn': '🇻🇳 Tiếng Việt (Bấm để đổi sang English)',
    'language_toggle_short': '🇻🇳 VI',
    'demo_mode_title': 'Chế độ Bạn Bè Mẫu (Trải Nghiệm Trực Quan)',
    'demo_mode_subtitle': 'Hiển thị nhóm bạn bè thân thiết mô phỏng trên quỹ đạo tinh gọn',
    'sync_widget_now': 'Đồng Bộ Widget Ngay',
    'sync_widget_success': 'Đã đồng bộ ảnh mới nhất ra Widget màn hình chính!',
    'check_update': 'Kiểm Tra Bản Cập Nhật Mới',
    'app_version': 'Phiên bản',

    // Reactions
    'reaction_sent': 'Đã thả biểu cảm!',
    'double_tap_to_react': 'Nhấn đúp vào bạn bè để thả tim',
  };

  static final Map<String, String> _enMap = {
    // App Branding
    'app_name': 'Orbit',
    'app_tagline': 'Relationship Orbits & Social Connection',

    // Top Bar
    'widget_installed': 'Widget Active',
    'status_connected': 'Connected',
    'profile_title': 'Profile & Settings',
    'friends_title': 'Friend Orbit Network',
    'add_friend': 'Add Friend',
    'widget_guide': 'Widget Guide',

    // Camera & Viewfinder
    'tap_to_expand': 'Tap to expand square viewfinder',
    'tap_to_collapse': 'Tap to collapse to circle',
    'all_friends': 'All Friends',
    'send_to_all': 'Send to all friends',
    'send_to': 'Send directly to',
    'capturing': 'Capturing...',
    'camera_initializing': 'Initializing lens...',
    'camera_error': 'Unable to connect to camera',

    // Location & Time Tagging
    'loc_btn_title': 'Tag Location & Time',
    'loc_detecting': 'Detecting location...',
    'loc_permission_needed': 'Location permission required for place tagging',
    'loc_landmark_found': 'Nearby landmark',
    'loc_road_found': 'Street / Area',
    'loc_tag_added': 'Location badge tagged',

    // History & Memories
    'history_title': 'Memory Archive',
    'history_empty_title': 'No Memories Yet',
    'history_empty_subtitle': 'Snap a photo and share via widget to preserve moments!',
    'history_back_to_camera': 'Back to Camera',
    'history_swipe_hint': 'Swipe down or tap to return to Camera',
    'history_photos_count': 'photos',
    'history_delete_confirm': 'Delete this photo from memory archive?',
    'history_cancel': 'Cancel',
    'history_delete': 'Delete',

    // Widget Guide Screen
    'wg_title': 'Home Screen Widget Setup',
    'wg_subtitle': 'Pin your closest friends & moments to your home screen',
    'wg_quick_pin_section': '1-Tap Quick Pin (Automatic)',
    'wg_pin_galaxy_btn': 'Pin Galaxy Satellite Widget',
    'wg_pin_pebble_btn': 'Pin Ripple Zen Pebble Widget',
    'wg_pin_success': 'Navigated to home screen! You can touch and hold the widget in the dialog to drag it to your desired spot.',
    'wg_pin_not_supported': 'Your device launcher does not support direct programmatic pinning. Please follow manual steps below.',
    'wg_manual_guide_title': 'Manual Setup Guide',
    'wg_step_1': '1. Return to home screen and long-press on any empty space.',
    'wg_step_2': '2. Select "Widgets" from the launcher menu.',
    'wg_step_3': '3. Find "Orbit", choose desired size (2x2 or 4x2), and drag it to your screen.',
    'wg_step_4': '4. Tap the widget anytime to capture and update fresh moments!',
    'wg_ios_notice_title': 'Apple WidgetKit on iOS',
    'wg_ios_notice_desc': 'Under Apple WidgetKit security policy, widgets on iPhone are added directly from your Home Screen following the quick steps below.',
    'wg_ios_styles_section': 'Orbit Widget Styles on iOS',
    'wg_ios_supported_sizes': 'Small (2x2) & Medium (4x2)',
    'wg_ios_ready_badge': '✨ Ready in iPhone Widget Gallery',
    'wg_ios_manual_guide_title': 'How to Add Widget on iPhone (iOS 14+)',
    'wg_ios_step_1': '1. Return to Home Screen, touch and hold any empty area until apps start jiggling.',
    'wg_ios_step_2': '2. Tap the plus button (+) in the top corner of the screen.',
    'wg_ios_step_3': '3. Search for "Orbit" in your iPhone widget gallery.',
    'wg_ios_step_4': '4. Choose your preferred widget size (Small or Medium) and tap "Add Widget".',
    'wg_ios_step_5': '5. Drag the widget to your desired spot and tap "Done" in the top right.',
    'wg_ios_step_6': '6. Tap the widget anytime to open camera and share moments with friends!',
    'wg_ios_lockscreen_tip': '💡 Lock Screen Tip (iOS 16+): Touch & hold Lock Screen > tap Customize > select Lock Screen > Add Widgets > choose Orbit.',
    'wg_ios_troubleshoot_title': '❓ Cannot find Orbit in Widget Gallery?',
    'wg_ios_troubleshoot_step_1': '1. Open the Orbit app at least once so iOS can index and load the widget extension.',
    'wg_ios_troubleshoot_step_2': '2. Try searching for both keywords: "Orbit" or "ICNative" in the search box.',
    'wg_ios_troubleshoot_step_3': '3. Restart your iPhone (Power off and back on): Sideloaded IPA apps (AltStore / TrollStore / Scarlet) require a reboot to refresh the iOS SpringBoard widget cache.',

    // Settings & Profile
    'settings_title': 'Settings',
    'language_setting': 'Language (Ngôn Ngữ)',
    'language_toggle_btn': '🇬🇧 English (Tap to switch to Tiếng Việt)',
    'language_toggle_short': '🇬🇧 EN',
    'demo_mode_title': 'Demo Friends Mode (Visual Showcase)',
    'demo_mode_subtitle': 'Display clean simulated close friends on elegant orbit',
    'sync_widget_now': 'Sync Home Screen Widgets Now',
    'sync_widget_success': 'Latest memory synced to home screen widgets!',
    'check_update': 'Check for New Updates',
    'app_version': 'Version',

    // Reactions
    'reaction_sent': 'Reaction sent!',
    'double_tap_to_react': 'Double-tap friend avatar to send hearts & reactions',
  };
}

/// Shorthand helper for easy translation
String tr(String key) => LocaleService.instance.t(key);
