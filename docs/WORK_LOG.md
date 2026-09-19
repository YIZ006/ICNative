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

