# PROMPT GIAO CHO AI (BẢN SẢN PHẨM THẬT): Firebase + Gửi ảnh tạm + Kết bạn 2 chiều + Giảm dung lượng

> Cách dùng: copy toàn bộ phần "PROMPT" bên dưới dán cho AI. Làm tuần tự Phần A -> E. Xong mỗi phần phải ghi `docs/WORK_LOG.md`.
> Giả định: người dùng ĐÃ/SẼ có Firebase project thật gói Blaze (có đặt budget alert) và tự thay file cấu hình. AI không tạo được project, chỉ viết code + cấu hình + tài liệu.

---

## PROMPT

Bạn đang làm việc trong dự án Flutter "Orbit" (thư mục `d:\project\IConNative`, Windows, PowerShell). Đây là SẢN PHẨM THẬT, không phải bản thử nghiệm: bảo mật, độ ổn định và chi phí phải được tính đúng. Làm đúng thứ tự, từng bước nhỏ, không làm thêm ngoài yêu cầu.

### 0. ĐỌC TRƯỚC (bắt buộc)
1. Đọc `AGENTS.md`, `agent.md`. Sau MỖI phần (A, B, C, D, E) ghi một mục vào `docs/WORK_LOG.md` đúng mẫu trong `agent.md`. Sắp hết token thì ghi trạng thái dở dang trước khi dừng.
2. Đọc kỹ trước khi sửa: `lib/main.dart`, `lib/services/auth_service.dart`, `lib/services/friend_service.dart`, `lib/services/sync_service.dart`, `lib/screens/qr_scanner_screen.dart`, `lib/screens/friends_screen.dart`, `lib/screens/profile_screen.dart`, `lib/screens/home.dart`, `lib/screens/preview.dart` (đoạn gọi `broadcastPhotoToFriends`, ~dòng 1225-1260), `lib/settings/global.dart`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`.

### RÀNG BUỘC CỨNG
- Người dùng đã CHỦ ĐỘNG đồng ý dùng Firebase gói Blaze (có hạn mức miễn phí + budget alert) cho sản phẩm thật. Vẫn cấm tuyệt đối Cloud AI trả phí; mọi xử lý AI/ảnh vẫn 100% on-device. Không sửa `AGENTS.md`/`agent.md` (người dùng tự cập nhật nguyên tắc "Server = 0 VNĐ").
- Giữ quy tắc 2 bản release Clean/Demo, không đụng `UpdateService`, không đổi tên APK. KHÔNG build/upload release trong tác vụ này. Không đổi `version` trong `pubspec.yaml`.
- Chế độ Demo (`isDemoModeNotifier == true`) và bản Demo showcase: TUYỆT ĐỐI không ghi/đọc dữ liệu cloud, không gửi ảnh, không tạo invite (bạn bè trong demo là dữ liệu giả).
- Ảnh người nhận được vẫn lưu trong máy (thư mục documents). Không làm tính năng backup thủ công.
- Không xóa/sửa comment, docstring không liên quan. Không bịa file cấu hình Firebase: `android/app/google-services.json` hiện là file GIẢ (`project_id: "iconnative-offline"`), iOS chưa có `GoogleService-Info.plist`; người dùng sẽ thay. Giữ `AuthService.isCloudConfigured` làm chốt an toàn: khi cấu hình còn giả (ví dụ chạy test), app không crash và không gọi cloud.
- Cuối mỗi phần chạy `flutter analyze` (phải `No issues found`) và `flutter test`.
- Thêm package bằng `flutter pub add <tên>` để pub tự chọn phiên bản tương thích với `firebase_core ^5` / `cloud_firestore ^7` hiện có. Không hạ cấp package có sẵn.
- Mọi chuỗi giao diện bằng tiếng Việt có dấu, lưu UTF-8.

### HỢP ĐỒNG GIỮA CLIENT VÀ SERVER (dùng đúng tên, đừng tự đổi)
Region Cloud Functions: `asia-southeast1` (client dùng `FirebaseFunctions.instanceFor(region: 'asia-southeast1')`). Mọi callable bật `enforceAppCheck` ở chế độ cấu hình qua biến môi trường `ENFORCE_APP_CHECK` (mặc định `false` để rollout an toàn, xem phần B).

| Hàm | Loại | Đầu vào | Kết quả / Lỗi |
|---|---|---|---|
| `registerSecret` | callable (cần đăng nhập) | `{secret}` | Lưu `sha256(secret)` vào `users_private/{uid}` (chỉ ghi lần đầu, ghi lại khi trùng hash). `{ok:true}` |
| `recoverAccount` | callable (KHÔNG cần đăng nhập) | `{uid, secret}` | So khớp hash bằng `crypto.timingSafeEqual`; đúng thì trả `{customToken}` (`admin.auth().createCustomToken(uid)`). Sai/không tồn tại: lỗi `permission-denied` (thông báo chung chung). Giới hạn 5 lần sai/giờ/uid (đếm trong Firestore `rate_limits`). |
| `createInvite` | callable | không | Tạo `invites/{code}` với `code` = 20 ký tự ngẫu nhiên an toàn (base32/hex từ `crypto.randomBytes`), `{ownerUid, createdAt, expireAt = +10 phút}`. Trả `{code, expiresAt}`. Giới hạn 30 invite/giờ/uid. |
| `redeemInvite` | callable | `{code}` | Kiểm tra tồn tại + chưa hết hạn. Không tự kết bạn với chính mình (`failed-precondition`). Giới hạn tối đa 50 bạn mỗi bên (`resource-exhausted`). Dùng admin SDK ghi 2 document `users/{A}/friends/{B}` và `users/{B}/friends/{A}` trong một batch (`{uid, displayName, addedAt}`). Trả `{friendUid, friendName, alreadyFriends}`. Lỗi mã sai/hết hạn: `not-found`. |
| `removeFriend` | callable | `{friendUid}` | Xóa cả 2 document friends bằng một batch. `{ok:true}` |
| `onPostCreated` | trigger Firestore v2 `posts/{postId}` onCreate | | Xem Phần A.4 |
| `onUserNameChanged` | trigger `users/{uid}` onUpdate (tùy chọn, làm sau cùng) | | Khi `displayName` đổi, cập nhật `displayName` trong các document friends tương ứng (collection group `friends` where `uid == X`). |

---

## PHẦN A. Hạ tầng Firebase trong repo (không đụng code Flutter)

A.1. Tạo ở gốc repo: `firebase.json`, `.firebaserc` (để project id là chữ `REPLACE_WITH_PROJECT_ID`, người dùng tự điền), `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `storage_lifecycle.json`, thư mục `functions/` (JavaScript, Node 20, `firebase-functions` v2 API, `firebase-admin`; có `package.json` với `"engines": {"node": "20"}`), và cấu hình emulator (auth, firestore, storage, functions) trong `firebase.json`.

A.2. **`firestore.rules`** (đúng theo ý, nội dung do bạn viết chặt chẽ, mặc định từ chối mọi thứ khác):
   - `users/{uid}`: chỉ chủ (`request.auth.uid == uid`) được đọc/ghi hồ sơ của mình; chỉ cho các trường `uid, displayName (<= 40 ký tự), createdAt, lastActive`.
   - `users/{uid}/friends/{friendUid}`: chủ được ĐỌC; KHÔNG ai được ghi từ client (chỉ Cloud Functions bằng admin SDK).
   - `users/{uid}/devices/{deviceId}`: chủ đọc/ghi (`fcmToken`, `platform`, `updatedAt`).
   - `posts/{postId}`: `create` chỉ khi `request.auth.uid == request.resource.data.senderId`, tập trường chỉ gồm `senderId, senderName, imageUrl, storagePath, caption (<= 200 ký tự), createdAt, expireAt` (dùng `keys().hasOnly`), KHÔNG được có `receiverIds` (server điền); `read` khi `request.auth.uid in resource.data.receiverIds || request.auth.uid == resource.data.senderId`; `update`/`delete` bị từ chối.
   - `invites`, `users_private`, `rate_limits`: từ chối toàn bộ từ client.
   - Bỏ collection `friend_requests` khỏi rules (luồng lời mời cũ ngừng dùng). Giữ code UI cũ nếu còn tham chiếu nhưng không cần cloud cho nó.
   - Thêm test rules bằng `@firebase/rules-unit-testing` trong `functions/test` hoặc `rules_test/` (chạy với emulator). Nếu máy chưa có Node/Java thì bỏ qua test và ghi rõ trong WORK_LOG.

A.3. **`storage.rules`**: đường dẫn `posts/{uid}/{fileName}`: `write` chỉ khi `request.auth.uid == uid`, `request.resource.size < 1 * 1024 * 1024`, `request.resource.contentType == 'image/jpeg'`; không cho `list`; `read` cho người đã đăng nhập (ảnh còn được bảo vệ thêm bởi download token không đoán được). `storage_lifecycle.json`: xóa object sau 7 ngày (`{"rule":[{"action":{"type":"Delete"},"condition":{"age":7}}]}`).

A.4. **Cloud Functions** (`functions/index.js`, region `asia-southeast1`, đặt `maxInstances` hợp lý, ví dụ 10, để chặn chi phí vượt kiểm soát):
   - Các callable theo bảng hợp đồng ở trên; xác thực dữ liệu đầu vào chặt chẽ; không log `secret` hay token.
   - `onPostCreated`: (1) đọc `posts/{postId}`; kiểm tra `storagePath` thuộc `posts/{senderId}/`; (2) giới hạn tối đa 50 bài/24 giờ/người gửi, vượt thì xóa document + file Storage và dừng; (3) lấy danh sách bạn THẬT của người gửi từ `users/{senderId}/friends` (nguồn tin cậy duy nhất), ghi `receiverIds` = các bạn đó (không gồm người gửi) bằng admin SDK; (4) gửi FCM tới mọi token trong `users/{receiverUid}/devices`: tin nhắn dữ liệu `{type:'new_post', postId, senderName, imageUrl}`; Android `priority: 'high'`; iOS `apns-priority: 5`, `content-available: 1` kèm thông báo hiển thị "<tên> vừa gửi một khoảnh khắc"; (5) token lỗi (`registration-token-not-registered`) thì xóa document device đó. Mỗi bước phải bắt lỗi riêng, không để một lỗi làm hỏng cả luồng.
   - TTL: tài liệu hóa trong `docs/FIREBASE_SETUP.md`: bật TTL policy cho `posts.expireAt` và `invites.expireAt` (Firestore TTL).

A.5. **`docs/FIREBASE_SETUP.md`** (tiếng Việt, từng bước cho người không rành): tạo project; chọn vị trí Firestore/Storage (khuyến nghị `asia-southeast1`; lưu ý vị trí KHÔNG đổi được); nâng gói Blaze và đặt budget alert; bật Authentication (Anonymous); bật Firestore + Storage; thêm app Android/iOS, thay `google-services.json`, thêm `GoogleService-Info.plist` vào target Runner; thêm SHA-1/SHA-256 của keystore release vào Firebase (cần cho Play Integrity/App Check); bật App Check (Play Integrity cho Android, App Attest cho iOS) ở chế độ "unenforced" trước; tải APNs Auth Key (.p8) lên Firebase Cloud Messaging cho iOS; `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`; bật TTL; áp `storage_lifecycle.json` bằng `gcloud storage buckets update gs://<bucket> --lifecycle-file=storage_lifecycle.json`; kiểm tra bằng emulator; checklist trước khi bật enforce App Check; lưu ý lifecycle/TTL chạy theo chu kỳ, không xóa đúng từng giây.

Tiêu chí xong Phần A: các file tồn tại; `node --check functions/index.js` không lỗi; nếu có Node thì `npm install` trong `functions/` chạy được; rules không có chỗ nào cho client ghi `friends`/`receiverIds`.

---

## PHẦN B. Client: Firebase Auth + App Check + danh tính

B.1. Thêm `firebase_auth`, `firebase_app_check`, `cloud_functions`, `firebase_messaging` bằng `flutter pub add`. Android: thêm quyền cần thiết vào `AndroidManifest.xml` (ví dụ `POST_NOTIFICATIONS`), không phá cấu hình widget hiện có. iOS: ghi chú vào `docs/FIREBASE_SETUP.md` các bước bật Push Notifications/Background Modes (không tự sửa file `.pbxproj` nếu không chắc).

B.2. **`main.dart`**: sau `Firebase.initializeApp()`, kích hoạt App Check: Android dùng Play Integrity, iOS dùng App Attest (fallback DeviceCheck); `kDebugMode` thì dùng provider debug. Mọi lỗi App Check chỉ log, không làm app dừng. Giữ cơ chế khởi tạo không crash khi cấu hình giả.

B.3. **Danh tính = Firebase Auth UID.** Sửa `AuthService`:
   - Lần đầu (có cloud, không ở chế độ demo): `FirebaseAuth.instance.signInAnonymously()`; UID nhận được trở thành `UserProfile.uid` (server cấp nên không trùng/không bị chiếm). Sau đó gọi `registerSecret` với `secretToken` hiện có.
   - Máy đã có danh tính cũ kiểu `u_xxxxxxxx` (bản thử trước đây): đăng nhập ẩn danh rồi chuyển sang UID mới, GIỮ ảnh/lịch sử local và tên hiển thị, bỏ danh sách bạn cũ (bạn cũ trỏ vào UID không tồn tại trên server). Ghi rõ quyết định này trong WORK_LOG.
   - Khôi phục tài khoản bằng QR backup (`restoreFromBackupPayload`): gọi `recoverAccount` -> `signInWithCustomToken` -> UID giữ nguyên như máy cũ; cập nhật prefs và `currentUserNotifier`; sau đó khởi động lại `FriendService.startRealtimeSync()` và `SyncService.startListening()`. Thất bại (sai secret/không mạng) thì báo lỗi rõ ràng, không ghi đè danh tính hiện tại.
   - `_syncToFirestore` chỉ ghi các trường rules cho phép.
   - Không đưa `secretToken` vào mã QR kết bạn; mã QR backup vẫn chứa `secret` nhưng chỉ hiện sau khi người dùng chủ động mở màn hình sao lưu (giữ hành vi hiện tại, thêm cảnh báo "không chia sẻ mã này").

B.4. `isCloudConfigured` giữ nguyên ý nghĩa; bổ sung điều kiện `FirebaseAuth.instance.currentUser != null` ở các nơi thực sự cần đăng nhập, để không gọi cloud khi chưa có phiên.

Tiêu chí xong Phần B: `flutter analyze` sạch; khi cấu hình giả app chạy offline như cũ; code Auth có test cho phần logic thuần (ví dụ phân tích payload backup).

---

## PHẦN C. Client: Gửi/nhận ảnh (nén, Storage tạm, Firestore, FCM)

C.1. **Nén ảnh** (`sync_service.dart`, dùng `compute` để không đơ UI, dùng package `image` có sẵn): cạnh dài tối đa 1080 px (chỉ thu nhỏ), JPEG quality 85, mục tiêu 150-300 KB. Ảnh có alpha thì đặt nền trắng trước khi mã hóa. Không sửa file gốc ở máy người gửi.

C.2. **Gửi**: bỏ qua nếu demo mode hoặc chưa đăng nhập. Tải lên Storage đường dẫn `posts/<uid>/<postId>.jpg` (`contentType: image/jpeg`), lấy `getDownloadURL()`, rồi tạo document `posts/<postId>` ĐÚNG tập trường theo rules: `senderId, senderName, imageUrl, storagePath, caption, createdAt, expireAt (Timestamp, +7 ngày)`. KHÔNG tự điền `receiverIds`; server làm việc đó. Bỏ `serverTimestamp` thừa nếu không nằm trong tập trường cho phép.

C.3. **Hàng đợi gửi lại (outbox)**: gửi lỗi do mạng thì lưu `{localImagePath, caption, createdAt}` vào SharedPreferences (tối đa 20 mục, bỏ mục quá 7 ngày); thử lại khi khởi động và khi app quay lại foreground, có giới hạn số lần, không lặp vô hạn. Giữ nguyên cách gọi "bắn và quên" ở `preview.dart` (không chặn UI người dùng).

C.4. **Nhận (foreground)**: sửa `startListening`:
   - Lắng nghe `posts` với `where('receiverIds', arrayContains: uid)`; chỉ xử lý `docChanges` loại `added` (document bắt đầu khớp truy vấn khi server điền `receiverIds` cũng được báo là `added`, vì vậy đừng lọc theo `modified`).
   - Idempotent theo file: bỏ qua nếu `friend_widget_<postId>.jpg` đã tồn tại. Chỉ đánh dấu đã xử lý SAU khi tải + ghi file thành công (lỗi mạng thì để lần sau thử lại). Bỏ qua bài đã quá `expireAt`. Chỉ giữ 500 `postId` gần nhất.
   - Lưu ảnh nhận được dưới tên `friend_widget_<postId>.jpg` và giữ nguyên các bước hiện có (thêm vào History, `savePhotoMetadata`, cập nhật widget Android/iOS, `latestReceivedPhotoNotifier`).

C.5. **Nhận khi app đóng (FCM)**:
   - Đăng ký token: sau khi đăng nhập và mỗi lần `onTokenRefresh`, ghi `users/{uid}/devices/{token}` (`fcmToken, platform, updatedAt`). Xin quyền thông báo (iOS và Android 13+) vào lúc hợp lý (không chặn lúc mở app lần đầu; ví dụ sau khi có bạn đầu tiên).
   - `FirebaseMessaging.onBackgroundMessage(handler)` với handler là hàm top-level có `@pragma('vm:entry-point')`: khởi tạo Firebase trong isolate, đọc `type == 'new_post'`, tải `imageUrl`, lưu `friend_widget_<postId>.jpg`, cập nhật dữ liệu widget (`HomeWidget.saveWidgetData`, `updateAllHomeWidgets`). Dùng kiểm tra tồn tại file để tránh trùng với luồng foreground.
   - iOS: ghi rõ trong tài liệu giới hạn của silent push (hệ điều hành có thể trì hoãn); widget cập nhật tốt nhất khi mở app hoặc khi hệ thống cho phép.

C.6. Test: hàm nén (cạnh tối đa, không phóng to ảnh nhỏ, xử lý alpha); logic outbox; logic idempotent theo file.

Tiêu chí xong Phần C: `flutter analyze` sạch; demo mode không phát sinh lệnh cloud; payload tạo `posts` khớp đúng tập trường trong rules (có test so khớp danh sách khóa).

---

## PHẦN D. Client: Kết bạn 2 chiều bằng QR/invite (server xác thực)

D.1. **Mã QR mới** (`AuthService.generateFriendQrPayload` trở thành bất đồng bộ hoặc có hàm mới): màn hình hiển thị QR gọi `createInvite`, payload `{type:'iconnative_add_friend', v:2, code, name}` (không chứa UID hay secret). Tự làm mới mã khi màn hình mở và mỗi ~5 phút (mã sống 10 phút). Mất mạng thì hiện thông báo "Cần kết nối mạng để tạo mã kết bạn" thay vì mã cũ.

D.2. **Quét** (`qr_scanner_screen.dart`, `FriendService.sendFriendRequestOrConnect` giữ chữ ký và enum `FriendAddResult`): nếu `v == 2` và có `code` thì gọi `redeemInvite`; map kết quả: `alreadyFriends` -> `alreadyFriends`; thành công -> `acceptedImmediately`; lỗi `failed-precondition` (tự quét mình) -> `selfError`; `not-found`/hết hạn -> thêm giá trị enum mới `inviteExpired` và hiển thị "Mã đã hết hạn, hãy nhờ bạn tạo mã mới"; `resource-exhausted` -> `friendLimitReached`; lỗi mạng -> `networkError` kèm thông báo "Cần kết nối mạng để kết bạn". KHÔNG còn tự thêm bạn một chiều ở local khi lỗi. Mã QR kiểu cũ (không có `code`) hiện thông báo "Mã QR cũ, hãy cập nhật Orbit ở máy người kia".
   - Sau khi `redeemInvite` thành công, danh sách bạn tự cập nhật qua listener `users/{uid}/friends` ở cả 2 máy (không cần thao tác tay).

D.3. **Sửa lỗi xóa nhầm bạn khi sync** (`startRealtimeSync`, nhánh `friends`): nếu `snapshot.metadata.isFromCache` và `snapshot.docs.isEmpty` thì BỎ QUA, không xóa danh sách local. Nguồn sự thật là server; cache local chỉ để hiển thị nhanh.

D.4. `removeFriend`: gọi callable `removeFriend` (xóa 2 phía). Cập nhật local sau khi server báo thành công; mất mạng thì báo "Cần kết nối mạng".

D.5. Giữ các lớp/hàm lời mời cũ (`FriendRequest`, `acceptFriendRequest`, `pendingRequestsNotifier`...) nếu `friends_screen.dart`/`home.dart` còn tham chiếu, nhưng đánh dấu `@Deprecated` và không còn ghi vào cloud. Không để lỗi biên dịch.

D.6. Test: ánh xạ lỗi callable -> `FriendAddResult`; bỏ qua snapshot rỗng từ cache; phân tích payload QR v1/v2.

Tiêu chí xong Phần D: `flutter analyze` sạch; không còn đường nào client tự ghi `friends` hay `receiverIds`; rules + hợp đồng khớp nhau.

---

## PHẦN E. Giảm dung lượng app nhưng KHÔNG hỏng chất lượng

Hiện trạng đã đo: APK ~158 MB, trong khi `assets/` chỉ ~41 MB (memes 30 MB / 135 PNG; `memes/bite` 3.6 MB; stickers 3.5 MB gồm 10 JPG; `models/detect.tflite` 4 MB). `android/app/build.gradle` đang `minifyEnabled false`, `shrinkResources false`, chưa có `abiFilters` (đang đóng gói cả x86_64). Phần này CHỈ làm sau khi A-D xong và analyze/test sạch (vì thêm Firebase Auth/Messaging/Functions làm APK nặng hơn, phải đo lại sau cùng).

E.1. **Đo trước** (ghi số liệu vào WORK_LOG): `flutter build apk --release --analyze-size --target-platform android-arm64` hoặc giải nén APK `Orbit-v1.4.7-clean-release.apk` (đổi đuôi .zip) lập bảng dung lượng theo thành phần: `assets/flutter_assets`, `lib/<abi>`, `classes*.dex`, `res`...

E.2. **Tối ưu ảnh meme/sticker, GIỮ NGUYÊN TÊN FILE** (không phải sửa code tham chiếu asset):
   - Backup bản gốc ra `scratch/assets_backup/` (không đưa vào app, không commit).
   - Bước A, lossless: tối ưu PNG cho 135 file trong `assets/memes/` (kể cả `bite/`) bằng `oxipng` (hoặc `optipng`/`zopflipng`). Chưa có công cụ thì viết `tool/optimize_assets.dart` dùng package `image` (PNG nén mức cao nhất) hoặc Python Pillow nếu có sẵn.
   - Bước B, chỉ khi A chưa đủ: đọc `lib/services/sticker_anchoring_engine.dart` và `lib/screens/preview.dart` để biết sticker được vẽ tối đa bao nhiêu pixel trên ảnh đầu ra (tính theo bề rộng ảnh đầu ra x tỉ lệ sticker lớn nhất). Chỉ thu nhỏ file có cạnh dài > 2 x kích thước vẽ tối đa, về đúng mức đó bằng bộ lọc Lanczos/cubic, giữ nguyên alpha.
   - Bước C, tùy chọn và có kiểm soát: lượng tử hóa màu (pngquant) CHỈ cho file nào vượt cổng chất lượng.
   - **Cổng chất lượng bắt buộc**: mỗi file sau tối ưu so với bản gốc ở cùng kích thước hiển thị phải đạt PSNR >= 40 dB (hoặc SSIM >= 0.985) trên RGB và alpha; không đạt thì khôi phục bản gốc. Xuất `docs/ASSET_OPTIMIZATION_REPORT.md`: tổng dung lượng trước/sau, danh sách file, kích thước pixel trước/sau, PSNR/SSIM nhỏ nhất. Mở xem 5 meme bất kỳ nếu có thể.
   - `assets/stickers/*.jpg`: chỉ tối ưu lossless (jpegtran/mozjpeg) hoặc thu nhỏ theo nguyên tắc Bước B; không nén lossy thêm nếu không qua cổng chất lượng.
   - TUYỆT ĐỐI không đụng `assets/models/detect.tflite` và font.

E.3. **Giảm kích thước build Android** (`android/app/build.gradle`):
   - Thêm `ndk { abiFilters "arm64-v8a", "armeabi-v7a" }` trong `defaultConfig` (bỏ x86/x86_64, chỉ dành cho máy ảo). KHÔNG dùng `--split-per-abi` vì phá quy tắc đặt tên APK và `UpdateService`; vẫn 1 APK cho mỗi bản Clean/Demo.
   - Thử bật `minifyEnabled true` + `shrinkResources true` cho `release`, kèm `proguard-rules.pro` giữ lại class cần cho Flutter, Firebase (Auth, Firestore, Storage, Functions, Messaging, App Check), Google ML Kit, TFLite, `home_widget` và các Kotlin widget (`ICNativeWidgetProvider`, `ICNativePebbleWidgetProvider`, `WidgetComposer`). Build thử `flutter build apk --release` cả mặc định và `--dart-define=DEFAULT_DEMO_MODE=true`; nếu R8 lỗi không sửa được sau vài lần thì TẮT shrink, giữ `abiFilters`, ghi lý do.
   - Không đổi `ndkVersion`, `minSdk`, `targetSdk`.

E.4. **Đo sau** và ghi bảng trước/sau (APK Clean và Demo, dung lượng `assets`). Báo rõ phần nào chiếm nhiều nhất (ví dụ ML Kit) để người dùng quyết định bước tiếp; không tự bỏ tính năng AI để giảm dung lượng.

Tiêu chí xong Phần E: analyze sạch; build được cả 2 chế độ; báo cáo tối ưu có số liệu; không meme nào vượt cổng chất lượng mà vẫn bị đổi; đường dẫn asset trong `pubspec.yaml`/code không đổi.

---

## NGOÀI PHẠM VI (đừng làm, chỉ nhắc trong báo cáo cuối)
Chính sách quyền riêng tư, chức năng xóa tài khoản/xóa dữ liệu, chặn/báo cáo người dùng, đăng cửa hàng Play Store/App Store, hệ thống thanh toán. Đây là việc cần cho sản phẩm thật nhưng làm ở đợt sau.

## QUY TẮC DỪNG VÀ BÁO CÁO
- Cần file cấu hình Firebase thật mà chưa có: KHÔNG bịa; hoàn thành phần code còn lại, ghi rõ trong WORK_LOG và `docs/FIREBASE_SETUP.md` việc người dùng phải làm.
- Một bước làm app crash hoặc analyze lỗi mà không sửa được sau 3 lần: hoàn tác bước đó, ghi lý do, sang bước kế tiếp.
- Không tự "nới" rules cho dễ chạy. Nếu rules chặn một thao tác hợp lệ thì sửa code client cho khớp, hoặc dừng và báo.
- Cuối cùng trả lời ngắn: đã làm gì, số liệu trước/sau (ảnh gửi, assets, APK), việc người dùng phải tự làm trên Firebase Console, rủi ro còn lại (đặc biệt: App Check với APK cài ngoài Play, push iOS).
