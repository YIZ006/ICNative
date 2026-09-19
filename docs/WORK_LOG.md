# Nhật Ký Báo Cáo Tiến Độ (Work Log) - ICNative

Tài liệu này ghi nhận toàn bộ lịch sử thực thi, thay đổi kỹ thuật và trạng thái của dự án theo thời gian thực.
Quy chuẩn báo cáo tuân thủ nghiêm ngặt theo quy định tại [agent.md](../agent.md).

---

### [2026-09-19 16:20:00] - Khởi tạo tài liệu dự án, thiết lập luật Agent và kiến trúc hệ thống
* **Thời gian (Timestamp):** 2026-09-19 16:20:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Khởi tạo Git repo, phân tích toàn bộ kiến trúc bài toán Chia sẻ ảnh Widget kèm Meme Snap On-Device (0 VNĐ Cloud AI), thiết lập tài liệu kỹ thuật toàn diện trong `docs/` và ban hành luật bắt buộc ghi báo cáo trong `agent.md`.
* **Chi tiết thay đổi (Changes Made):**
  - [NEW] `agent.md` - Ban hành luật bắt buộc ghi báo cáo tiến độ (kể cả khi đứt đoạn/hết token) và 4 nguyên tắc kỹ thuật cốt lõi (0 VNĐ, <500ms, WebP 150KB, Widget native).
  - [NEW] `AGENTS.md` - Đồng bộ cấu hình phát hiện tự động của Antigravity Agent.
  - [NEW] `docs/README.md` - Trang chỉ mục điều hướng toàn bộ hệ thống tài liệu.
  - [NEW] `docs/ARCHITECTURE.md` - Đặc tả kiến trúc End-to-End: Flutter Client, On-Device Vision, Firebase Spark 0 VNĐ, WidgetKit & RemoteViews.
  - [NEW] `docs/ANCHORING_ENGINE.md` - Công thức toán học và quy trình 3 bước tính tọa độ neo sticker (ML Kit ROI + Extremum Point + Normal Vector + Affine Transform).
  - [NEW] `docs/WIDGET_INTEGRATION.md` - Hướng dẫn chi tiết setup `home_widget`, App Groups iOS, SwiftUI Provider, Android AppWidgetProvider.
  - [NEW] `docs/WORK_LOG.md` - File nhật ký báo cáo tiến độ chuẩn hóa.
  - [NEW] `README.md` - Khởi tạo commit đầu tiên trên nhánh `main` trỏ remote tới `https://github.com/YIZ006/ICNative.git`.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - Lệnh `git push` đang chờ người dùng xác thực tài khoản GitHub thông qua Git Credential Manager trên máy tính.
  - Mã nguồn Flutter khởi tạo hiện đang nằm trong thư mục con `Lockit/` (cần quyết định chuyển ra thư mục gốc).
* **Bước tiếp theo (Next Steps):**
  1. Hỗ trợ người dùng hoàn tất đẩy mã nguồn lên GitHub `origin main`.
  2. Dọn dẹp đưa code từ `Lockit/` ra thư mục gốc `IConNative/`.
  3. Bắt đầu cài đặt `google_mlkit_object_detection` và xây dựng module `StickerAnchoringEngine`.

---

### [2026-09-19 16:28:00] - Tạo thư mục tham chiếu home_widget bên ngoài & chắt lọc tài nguyên icon/font/mẫu
* **Thời gian (Timestamp):** 2026-09-19 16:28:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Clone repo `home_widget` ra thư mục độc lập bên ngoài dự án (`d:\project\home_widget_reference`) để tránh làm nặng và bẩn Git của `ICNative`. Chắt lọc các tài nguyên thiết yếu gồm icon font dùng cho native widget, ảnh mẫu và các template file widget chuẩn (iOS SwiftUI Provider và Android Jetpack Glance) vào `IConNative`. Đồng thời xác nhận toàn bộ 4 commit trước đó đã được push thành công lên GitHub `origin main`.
* **Chi tiết thay đổi (Changes Made):**
  - [NEW DIRECTORY] `d:\project\home_widget_reference` - Kho tham chiếu mã nguồn gốc của thư viện `home_widget` (nằm ngoài git tree).
  - [NEW] `assets/fonts/widget_material_icons.otf` - Font icon Material dùng hiển thị icon trên native widget.
  - [NEW] `assets/fonts/widget_cupertino_icons.ttf` - Font icon Cupertino dùng hiển thị icon trên native widget.
  - [NEW] `images/sample_widget.png` - Ảnh mẫu widget.
  - [NEW] `templates/widget/ios/ImageWidget.swift` - Template Swift WidgetKit với App Group container.
  - [NEW] `templates/widget/android/ImageWidgetHomeWidget.kt` - Template Kotlin Jetpack Glance widget nạp ảnh bitmap.
  - [NEW] `templates/widget/android/image_widget_home_widget.xml` - XML cấu hình kích thước và thuộc tính Android widget.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - Git remote `origin main` đã đồng bộ hoàn hảo đến commit `d82f4c0`.
  - Tài nguyên icon font và template widget đã sẵn sàng trong project.
* **Bước tiếp theo (Next Steps):**
  1. Commit các file tài nguyên và template mới vào Git.
  2. Cập nhật `pubspec.yaml` tích hợp `google_mlkit_object_detection`, `image`, `home_widget`.
  3. Bắt đầu code module `StickerAnchoringEngine`.

---

### [2026-09-19 16:21:00] - Tái cấu trúc đưa source code từ Lockit ra thư mục gốc & đổi tên package
* **Thời gian (Timestamp):** 2026-09-19 16:21:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Di chuyển toàn bộ mã nguồn Flutter từ thư mục con `Lockit/` ra thư mục gốc dự án `IConNative/`, xóa bỏ `.git` con để loại trừ xung đột nested repository, chuẩn hóa `.gitignore` chống rác IDE, đổi tên package thành `icnative` trong `pubspec.yaml` và cập nhật toàn bộ import trong `lib/` và `test/`.
* **Chi tiết thay đổi (Changes Made):**
  - [DELETE] `Lockit/` - Xóa thư mục con và repo git cũ sau khi di chuyển toàn bộ file.
  - [MODIFY] `.gitignore` - Bổ sung quy tắc bỏ qua `.idea/`, `*.iml`, `.vscode/`, `.DS_Store`, `Thumbs.db`.
  - [MODIFY] `pubspec.yaml` - Đổi tên package từ `Lockit` sang `icnative`.
  - [MODIFY] `lib/screens/history.dart` - Cập nhật import sang `package:icnative/`.
  - [MODIFY] `lib/screens/home.dart` - Cập nhật import sang `package:icnative/`.
  - [MODIFY] `lib/screens/preview.dart` - Cập nhật import sang `package:icnative/`.
  - [MODIFY] `test/widget_test.dart` - Cập nhật import sang `package:icnative/main.dart`.
  - [MODIFY] `README.md` - Nâng cấp tài liệu giới thiệu tổng quan dự án ICNative.
  - [COMMIT] Git commit `3a2338d` đã lưu toàn bộ 85 files của codebase.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - Codebase đã nằm ngay ngắn ở thư mục gốc, sẵn sàng cho việc phát triển feature mà không bị lỗi cấu trúc IDE.
  - Cần push 3 commit (`c6c70a6`, `dc1a7c1`, `3a2338d`) lên remote GitHub `origin main`.
* **Bước tiếp theo (Next Steps):**
  1. Hướng dẫn/Hỗ trợ người dùng push lên GitHub remote repository.
  2. Bắt đầu cài đặt thư viện On-Device AI `google_mlkit_object_detection` và xây dựng module `StickerAnchoringEngine`.

---

### [2026-09-19 16:32:00] - Kiểm tra điều kiện chạy thử trên Meizu 21 Note & bổ sung quyền AndroidManifest
* **Thời gian (Timestamp):** 2026-09-19 16:32:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Kiểm tra toàn diện môi trường Android Studio, kết nối ADB và thiết bị thực tế Meizu 21 Note. Phát hiện và bổ sung các quyền bắt buộc trong `AndroidManifest.xml` (Camera, Internet, Hardware Feature) để tránh văng app (crash) khi khởi chạy trên điện thoại thật. Hướng dẫn chi tiết checklist 3 bước để chạy app trên máy thật Meizu 21 Note.
* **Chi tiết thay đổi (Changes Made):**
  - [MODIFY] `android/app/src/main/AndroidManifest.xml` - Thêm quyền `android.permission.CAMERA`, `android.permission.INTERNET`, khai báo phần cứng camera và đổi tên app hiển thị thành `ICNative`.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - Điện thoại Meizu 21 Note chưa kết nối hoặc chưa bật gỡ lỗi USB (lệnh ADB chưa nhận diện thiết bị).
  - Máy tính chưa có Flutter SDK trong biến môi trường PATH (cần thiết lập Flutter SDK Path trong Android Studio).
* **Bước tiếp theo (Next Steps):**
  1. Hướng dẫn người dùng kết nối điện thoại Meizu 21 Note qua USB Debugging.
  2. Hướng dẫn thiết lập Flutter SDK trong Android Studio để bấm Run chạy app.


