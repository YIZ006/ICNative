# Báo cáo: Chuyển bạn bè từ Locket sang Orbit

Ngày: 2026-11-05

## 1. Kết luận nhanh

| Hướng | Khả thi? | Ghi chú |
|---|---|---|
| Giải mã ID Locket rồi copy sang Orbit | **Không** | Xem mục 2 |
| Lấy danh sách bạn của người dùng từ server Locket bằng API không chính thức | **Không nên làm** | Xem mục 3 |
| Mời bạn bè bằng link/QR "một chạm", tự kết bạn khi mở app | **Khả thi, nên làm** | Mục 4 |
| Đối chiếu danh bạ (SĐT đã băm) | Khả thi, tùy chọn | Mục 5 |

## 2. Vì sao copy ID không dùng được

- Orbit dùng định danh riêng: `UserProfile.uid` (UUID tự sinh, lưu ở `AuthService`), danh bạn bè ở `FriendService` (Firestore `friend_requests` và `friends`).
- ID người dùng Locket là ID thuộc backend của Locket. Có copy được thì vẫn vô nghĩa với Orbit: không có tài khoản Orbit nào mang UID đó, nên không có gì để kết nối.
- Bạn bè **bắt buộc phải cài Orbit và tạo hồ sơ** thì mới có UID Orbit. Đây là rào cản chính, và không có cách kỹ thuật nào bỏ qua nó. Không thể "kết bạn thay" cho người chưa dùng app.
- "Giải mã" không phải bài toán. UID chỉ là mã định danh, không chứa tên, ảnh hay liên hệ.

## 3. Vì sao không nên lấy dữ liệu từ Locket

- Muốn lấy danh sách bạn phải gọi API riêng tư của Locket bằng token đăng nhập của người dùng, hoặc dịch ngược app Locket. Việc này vi phạm điều khoản dịch vụ của Locket và có thể bị khóa tài khoản người dùng.
- Danh sách bạn chứa dữ liệu cá nhân của người khác. Họ chưa đồng ý chuyển sang Orbit.
- Locket có thể đổi API bất cứ lúc nào, nên tính năng sẽ hỏng liên tục.
- Có thể bị gỡ khỏi Play Store/App Store.

Vì vậy báo cáo này **không** kèm prompt cho hướng đó.

## 4. Giải pháp đề xuất: Invite link "kết bạn một chạm"

Mục tiêu: người dùng Orbit gửi link vào nhóm chat (Zalo/Messenger/Story Locket của chính họ). Bạn bè bấm link, cài app, và **tự thành bạn ngay khi tạo hồ sơ xong**, không cần quét QR hay gõ mã.

### Luồng

1. A bấm **Mời bạn từ Locket/Zalo** trong `friends_screen.dart`.
2. App tạo link, ví dụ `https://<domain>/invite/<A_uid>` (hoặc `orbit://invite/<A_uid>`), kèm văn bản mẫu như "Mình chuyển qua Orbit rồi, vào đây kết bạn lại nhé".
3. A chia sẻ bằng share sheet của hệ điều hành.
4. B bấm link:
   - Đã có Orbit: mở app, hiện hộp thoại "A mời bạn kết bạn", bấm đồng ý để kết bạn.
   - Chưa có Orbit: mở trang tải bản Clean trên GitHub Releases. Mã mời được giữ lại bằng **Android Install Referrer** hoặc nhập tay lần đầu.
5. Lần đầu mở app, B tạo hồ sơ, rồi app tự gọi luồng kết bạn có sẵn (`FriendService`, ví dụ `FriendAddResult.requestSent` hoặc `acceptedImmediately`).

### Việc cần làm trong code (dự kiến)

- Thêm gói deep link: `app_links` (hoặc `uni_links`) và `share_plus`.
- Cấu hình Android `intent-filter` và iOS URL scheme / Universal Links.
- `lib/services/invite_service.dart` (mới): tạo và phân tích link, lưu `pendingInviteUid` trong `SharedPreferences` nếu app chưa onboard xong.
- `main.dart`: lắng nghe link lúc khởi động và lúc app đang chạy.
- `friends_screen.dart`: nút **Mời bạn bè** và hộp thoại xác nhận.
- Dùng lại logic của `FriendService` và `qr_scanner_screen.dart`, không viết lại.
- Bản Clean: không thêm dữ liệu mẫu. Bản Demo: giữ nguyên.
- Updater: không đổi, vẫn đúng quy tắc chống tải nhầm bản `demo`.

### Rủi ro và lưu ý

- Cần xác nhận của người nhận, không tự thêm bạn mà không hỏi.
- Giới hạn tần suất và chống spam lời mời. Kiểm tra lại Firestore rules.
- Link không được chứa `secretToken`, chỉ chứa `uid` công khai.
- Phải chạy 100% offline hoặc 0 VNĐ. Firebase gói miễn phí hiện có là đủ, không cần dịch vụ Dynamic Links trả phí.

## 5. Tùy chọn: Đối chiếu danh bạ

- Xin quyền `READ_CONTACTS`, băm SĐT bằng SHA-256 kèm muối, rồi đối chiếu với hồ sơ Orbit đã tự nguyện đăng ký SĐT.
- Cần thêm trường SĐT (đã băm) vào hồ sơ, cùng chính sách quyền riêng tư và kiểm tra Firestore rules.
- Để sau, khi lượng người dùng đủ lớn.

## 6. Prompt giao cho AI khác (cho giải pháp mục 4)

```
Bạn đang làm việc trong dự án Flutter "Orbit" (thư mục d:\project\IConNative). Hãy đọc AGENTS.md và agent.md trước, và ghi nhật ký vào docs/WORK_LOG.md khi xong.

MỤC TIÊU: thêm tính năng "Mời bạn bè bằng link" để người dùng chuyển bạn bè từ app khác (Locket, Zalo...) sang Orbit mà không phải quét QR. TUYỆT ĐỐI không gọi API, không dịch ngược hay lấy dữ liệu từ Locket hoặc app bên thứ ba nào.

RÀNG BUỘC: 0 VNĐ, không dùng cloud API trả phí; giữ hai bản release Clean/Demo; không phá luồng UpdateService; không đưa secretToken vào link.

VIỆC CẦN LÀM:
1. Thêm deep link (app_links) và share_plus trong pubspec.yaml; cấu hình Android intent-filter (AndroidManifest.xml) và iOS (Info.plist) cho scheme orbit://invite/<uid> (và https nếu có domain).
2. Tạo lib/services/invite_service.dart: tạo link từ AuthService.instance.currentUser.uid, phân tích link, lưu pendingInviteUid vào SharedPreferences nếu người dùng chưa tạo hồ sơ, xử lý khi app mở lần đầu và khi link đến lúc app đang chạy.
3. Sửa lib/main.dart để lắng nghe link và gọi InviteService.
4. Sửa lib/screens/friends_screen.dart: nút "Mời bạn bè" mở share sheet với lời nhắn tiếng Việt; hiển thị hộp thoại xác nhận khi nhận lời mời. Chỉ gọi FriendService để gửi lời mời hoặc kết bạn sau khi người dùng đồng ý.
5. Tái sử dụng FriendService và logic của qr_scanner_screen.dart; xử lý các kết quả FriendAddResult (đã là bạn, tự mời mình, lỗi mạng).
6. Chống spam: giới hạn số lời mời đang chờ; kiểm tra Firestore rules.
7. Chạy flutter analyze (phải 0 issues) và viết test cho phần phân tích link.
8. Cập nhật docs/WORK_LOG.md theo đúng mẫu trong agent.md.
```
