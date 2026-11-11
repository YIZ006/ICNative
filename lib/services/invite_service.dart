import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'friend_service.dart';

class InvitePayload {
  final String uid;
  final String displayName;
  final String rawSource;

  const InvitePayload({
    required this.uid,
    required this.displayName,
    required this.rawSource,
  });
}

class InviteConnectEvent {
  final String uid;
  final String displayName;
  final FriendAddResult result;
  final int timestamp;

  InviteConnectEvent({
    required this.uid,
    required this.displayName,
    required this.result,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}

class InviteService {
  static final InviteService instance = InviteService._internal();
  InviteService._internal();

  static const MethodChannel _channel = MethodChannel('com.abom.utas.utas/deep_link');
  static const String hostingBaseUrl = 'https://ncnative-bcf6d.web.app/invite';
  static const String _prefPendingInviteKey = 'iconnative_pending_invite_link';
  static const String _prefLastHandledClipKey = 'iconnative_last_handled_clipboard_uid';

  /// Thông báo sự kiện khi vừa tự động xử lý xong một link kết bạn để UI hiển thị hộp thoại chúc mừng
  final ValueNotifier<InviteConnectEvent?> inviteEventNotifier =
      ValueNotifier<InviteConnectEvent?>(null);

  bool _isInitialized = false;
  bool _isProcessingLink = false;
  String? _lastProcessedUidAndTime;

  /// Tạo đường link HTTPS kết bạn gắn trực tiếp với tài khoản hiện tại (bấm được trong mọi ứng dụng chat)
  String generateInviteLink() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.uid.isEmpty) return hostingBaseUrl;
    final uri = Uri.parse(hostingBaseUrl).replace(
      queryParameters: {
        'uid': user.uid,
        'name': user.displayName,
      },
    );
    return uri.toString();
  }

  /// Tạo đường link scheme nội bộ (orbit://invite?uid=...&name=...)
  String generateCustomSchemeLink() {
    final user = AuthService.instance.currentUser;
    if (user == null || user.uid.isEmpty) return 'orbit://invite';
    final uri = Uri(
      scheme: 'orbit',
      host: 'invite',
      queryParameters: {
        'uid': user.uid,
        'name': user.displayName,
      },
    );
    return uri.toString();
  }

  /// Nội dung tin nhắn chia sẻ lời mời kết bạn có gắn link bấm được ngay
  String generateShareMessage() {
    final user = AuthService.instance.currentUser;
    final myName = user?.displayName ?? 'Mình';
    final link = generateInviteLink();
    return '🪐 Kết bạn với $myName trên Orbit Widget nhé!\n'
        '👉 Bấm vào link này để mở app và kết nối thẳng với tài khoản của mình:\n'
        '$link';
  }

  /// Mở bảng chia sẻ hệ thống (Zalo, Messenger, Instagram, Tin nhắn...)
  Future<bool> shareInviteLink() async {
    final message = generateShareMessage();
    try {
      final ok = await _channel.invokeMethod<bool>('shareText', {
        'text': message,
        'title': 'Chia sẻ link kết bạn Orbit',
      });
      if (ok == true) return true;
    } catch (e) {
      debugPrint('Native shareText fallback to clipboard: $e');
    }
    await Clipboard.setData(ClipboardData(text: message));
    return false;
  }

  /// Sao chép link kết bạn vào bộ nhớ tạm
  Future<String> copyInviteLinkToClipboard() async {
    final link = generateInviteLink();
    await Clipboard.setData(ClipboardData(text: link));
    return link;
  }

  /// Khởi tạo lắng nghe Deep Link từ hệ điều hành (Cold Start & Warm Resume)
  Future<void> init() async {
    if (_isInitialized) {
      await processPendingInviteIfNeeded();
      return;
    }
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments as String?;
        if (link != null && link.trim().isNotEmpty) {
          debugPrint('🔗 Received real-time deep link: $link');
          await handleIncomingLink(link);
        }
      }
    });

    // Kiểm tra xem app có được mở từ một link kết bạn lúc khởi động không
    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.trim().isNotEmpty) {
        debugPrint('🔗 Captured initial launch deep link: $initialLink');
        await handleIncomingLink(initialLink);
        return;
      }
    } catch (e) {
      debugPrint('getInitialLink error: $e');
    }

    await processPendingInviteIfNeeded();
  }

  /// Xử lý link kết bạn đang chờ trong SharedPreferences (nếu nhận được trước khi AuthService khởi tạo xong)
  Future<void> processPendingInviteIfNeeded() async {
    if (AuthService.instance.currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_prefPendingInviteKey);
    if (pending != null && pending.trim().isNotEmpty) {
      await prefs.remove(_prefPendingInviteKey);
      await handleIncomingLink(pending);
    }
  }

  /// Tự động kiểm tra Clipboard nếu người dùng vừa bấm "Sao chép mã kết bạn" từ trình duyệt trong Zalo/Messenger rồi mở app
  Future<InviteConnectEvent?> checkClipboardForInvite({bool silent = true}) async {
    try {
      if (AuthService.instance.currentUser == null) return null;
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) return null;

      // Chỉ tự động bắt nếu trong clipboard thật sự là một đường link mời của Orbit
      final lower = text.toLowerCase();
      final isOrbitInviteUrl = lower.contains('ncnative-bcf6d.web.app/invite') ||
          lower.contains('ncnative-bcf6d.firebaseapp.com/invite') ||
          lower.contains('orbit://invite') ||
          lower.contains('icnative://invite');
      if (!isOrbitInviteUrl) return null;

      final payload = parseInviteInput(text);
      if (payload == null) return null;

      // Không tự bắt nếu là link của chính mình hoặc đã là bạn bè
      final myUid = AuthService.instance.currentUser?.uid;
      if (payload.uid == myUid) return null;
      if (FriendService.instance.friends.any((f) => f.uid == payload.uid)) return null;

      final prefs = await SharedPreferences.getInstance();
      final lastClipUid = prefs.getString(_prefLastHandledClipKey);
      if (silent && lastClipUid == payload.uid) return null;

      await prefs.setString(_prefLastHandledClipKey, payload.uid);
      return await connectFromPayload(payload);
    } catch (e) {
      debugPrint('checkClipboardForInvite error: $e');
      return null;
    }
  }

  /// Xử lý một đường link hoặc chuỗi kết bạn gửi vào app
  Future<InviteConnectEvent?> handleIncomingLink(String rawLink) async {
    final payload = parseInviteInput(rawLink);
    if (payload == null) return null;

    // Nếu AuthService chưa khởi tạo xong tài khoản, lưu lại để xử lý ngay khi có UID
    if (AuthService.instance.currentUser == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPendingInviteKey, rawLink);
      return null;
    }

    return await connectFromPayload(payload);
  }

  /// Thực hiện kết nối bạn bè từ InvitePayload và phát thông báo lên giao diện
  Future<InviteConnectEvent?> connectFromPayload(
    InvitePayload payload, {
    bool notifyGlobal = true,
  }) async {
    if (_isProcessingLink) return null;

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 3000;
    final dedupKey = '${payload.uid}_$nowSec';
    if (_lastProcessedUidAndTime == dedupKey) return null;

    _isProcessingLink = true;
    _lastProcessedUidAndTime = dedupKey;

    try {
      String friendName = payload.displayName.trim();
      final isGenericName = friendName.isEmpty ||
          friendName == 'Bạn bè' ||
          friendName == 'Bạn Bè Orbit';

      // Nếu link chỉ có UID hoặc chưa rõ tên, ưu tiên tra cứu tên thật trên Cloud Firestore
      if (isGenericName && AuthService.isCloudConfigured) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(payload.uid)
              .get()
              .timeout(const Duration(milliseconds: 2500));
          final cloudName = doc.data()?['displayName'] as String?;
          if (cloudName != null && cloudName.trim().isNotEmpty) {
            friendName = cloudName.trim();
          }
        } catch (e) {
          debugPrint('Lookup friend name from Firestore error: $e');
        }
      }

      if (friendName.isEmpty) {
        friendName = 'Bạn Bè Orbit';
      }

      final result = await FriendService.instance.sendFriendRequestOrConnect(
        friendUid: payload.uid,
        friendName: friendName,
      );

      final event = InviteConnectEvent(
        uid: payload.uid,
        displayName: friendName,
        result: result,
      );

      if (notifyGlobal) {
        inviteEventNotifier.value = event;
      }
      return event;
    } finally {
      _isProcessingLink = false;
    }
  }

  /// Phân tích mọi định dạng link kết bạn, tin nhắn chứa link, JSON QR hoặc mã UID
  static InvitePayload? parseInviteInput(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // 1. Thử phân tích nếu là chuỗi JSON từ mã QR
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        if (map['type'] == 'iconnative_add_friend') {
          final uid = (map['uid'] as String? ?? '').trim();
          final name = (map['name'] as String? ?? 'Bạn bè').trim();
          if (_isValidUid(uid)) {
            return InvitePayload(
              uid: uid,
              displayName: name.isEmpty ? 'Bạn bè' : name,
              rawSource: trimmed,
            );
          }
        }
      } catch (_) {}
    }

    // 2. Tìm kiếm URL (https://..., http://..., orbit://..., icnative://...) nằm trong đoạn văn bản
    final urlRegex = RegExp(
      r'((?:https?|orbit|icnative)://[^\s<>"]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(trimmed);
    final candidateUrl = match != null ? match.group(1)! : trimmed;

    final parsedFromUri = _parseUriString(candidateUrl);
    if (parsedFromUri != null) {
      return parsedFromUri;
    }

    // 3. Nếu người dùng dán trực tiếp mã UID (ví dụ: u_f7bcfb29)
    final uidRegex = RegExp(r'\b(u_[a-zA-Z0-9]{6,20})\b');
    final uidMatch = uidRegex.firstMatch(trimmed);
    if (uidMatch != null) {
      final uid = uidMatch.group(1)!;
      return InvitePayload(
        uid: uid,
        displayName: 'Bạn bè',
        rawSource: trimmed,
      );
    }

    return null;
  }

  static InvitePayload? _parseUriString(String urlStr) {
    try {
      final uri = Uri.parse(urlStr);
      final scheme = uri.scheme.toLowerCase();
      if (scheme != 'https' && scheme != 'http' && scheme != 'orbit' && scheme != 'icnative') {
        return null;
      }

      String uid = (uri.queryParameters['uid'] ?? uri.queryParameters['u'] ?? '').trim();
      String name = (uri.queryParameters['name'] ?? uri.queryParameters['n'] ?? '').trim();

      // Hỗ trợ cả dạng đường dẫn /invite/u_f7bcfb29 hoặc orbit://invite/u_f7bcfb29
      if (uid.isEmpty && uri.pathSegments.isNotEmpty) {
        final lastSeg = uri.pathSegments.last.trim();
        if (lastSeg.isNotEmpty && lastSeg.toLowerCase() != 'invite') {
          uid = Uri.decodeComponent(lastSeg);
        }
      }

      if (!_isValidUid(uid)) return null;

      return InvitePayload(
        uid: uid,
        displayName: name.isEmpty ? 'Bạn bè' : name,
        rawSource: urlStr,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isValidUid(String uid) {
    if (uid.length < 4 || uid.length > 64) return false;
    if (uid.contains(' ') || uid.contains('/') || uid.contains('?')) return false;
    return true;
  }
}
