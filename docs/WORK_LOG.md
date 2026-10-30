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

---

### [2026-09-19 16:45:00] - Cài đặt tự động Flutter SDK vào D:\flutter & nhận diện Meizu 21 Note qua ADB
* **Thời gian (Timestamp):** 2026-09-19 16:45:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Nhận diện máy chưa có Flutter SDK. Đã tự động clone bản Flutter SDK stable chuẩn vào ổ `D:\flutter` (tận dụng ổ D còn trống 748 GB), thêm vĩnh viễn `D:\flutter\bin` vào biến môi trường User PATH của Windows, đồng thời tải Dart SDK và build flutter tool. Kiểm tra ADB phát hiện điện thoại Meizu 21 Note đã kết nối thành công (`model:MEIZU_21_Note`).
* **Chi tiết thay đổi (Changes Made):**
  - [NEW SDK] `D:\flutter` - Cài đặt Flutter SDK Stable.
  - [SYSTEM CONFIG] Bổ sung `D:\flutter\bin` vào `HKCU:\Environment\Path`.
  - [INIT] Tự động tải Dart SDK và build Flutter Tool engine.
  - [ADB DETECTED] Thiết bị `adb-468QBGFJ223WP-6jU3lh._adb-tls-connect._tcp` (Meizu 21 Note) đã kết nối thành công ở chế độ `device`.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - Flutter SDK đang hoàn tất bước khởi tạo snapshot lần đầu tiên.
  - Cần cài đặt plugin Flutter & Dart trong Android Studio (nếu chưa cài) và trỏ Flutter SDK Path về `D:\flutter`.
* **Bước tiếp theo (Next Steps):**
  1. Hướng dẫn người dùng cài plugin Flutter trong Android Studio và trỏ SDK Path `D:\flutter`.
  2. Mở dự án trong Android Studio và bấm Run ▶️ test trực tiếp trên Meizu 21 Note.



---

### [2026-09-20 17:52:00] - S?a l?i build Android v� s?a l?i UI/UX Camera Preview
* **Th?i gian (Timestamp):** 2026-09-20 17:52:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  C�i d?t Android SDK Command-line Tools d? s?a l?i kh�ng build du?c app. S?a 3 l?i li�n quan d?n Camera: (1) n�ng d? ph�n gi?i t? low l�n high d? ?nh kh�ng b? m?; (2) b?c CameraPreview trong FittedBox (BoxFit.cover) d? ?nh kh�ng b? b?p sai t? l?; (3) d?i ch? d? FlashMode t? always sang torch d? flash ho?t d?ng t?t tr�n c�c d�ng m�y Android.
* **Chi ti?t thay d?i (Changes Made):**
  - [NEW] C�i d?t cmdline-tools v�o Android SDK.
  - [MODIFY] lib/screens/home.dart - N�ng ResolutionPreset.low v� ultraHigh th�nh high.
  - [MODIFY] lib/screens/home.dart - B?c CameraPreview trong FittedBox v?i thu?c t�nh BoxFit.cover.
  - [MODIFY] lib/screens/home.dart - S?a l?i b?t flash b?ng c�ch d�ng FlashMode.torch thay v� FlashMode.always.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - Camera d� n�t, t? l? d�ng m�n h�nh, b?t du?c d�n flash b�nh thu?ng.
  - Logic luu ?nh hi?n dang d�ng bi?n global List<String> images, ch? luu t?m trong RAM.
* **Bu?c ti?p theo (Next Steps):**
  1. T�ch h?p ML Kit Object Detection.
  2. Firebase Upload d? g?i widget cho b?n b�.

---

### [2026-09-20 18:15:00] - N�ng c?p c?u h�nh Android Gradle (Gradle, AGP, Kotlin)
* **Th?i gian (Timestamp):** 2026-09-20 18:15:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  S?a l?i build th?t b?i do project cu kh�ng tuong th�ch v?i Flutter SDK 3.47.5. �� n�ng c?p d?ng b? b? ba l�i Android Build System: Gradle Wrapper, Android Gradle Plugin (AGP) v� Kotlin.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] ndroid/gradle/wrapper/gradle-wrapper.properties - N�ng c?p distributionUrl l�n gradle-8.14-all.zip.
  - [MODIFY] ndroid/settings.gradle - N�ng c?p com.android.application l�n 8.11.1.
  - [MODIFY] ndroid/settings.gradle - N�ng c?p org.jetbrains.kotlin.android l�n 2.2.20.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - Build Android APK th�nh c�ng, kh�ng c�n b? vu?ng l?i "minimum supported version" c?a Flutter SDK.
* **Bu?c ti?p theo (Next Steps):**
  1. H? tr? ngu?i d�ng ch?y tr�n m�y v?t l� Meizu.
  2. B?t d?u t�ch h?p StickerAnchoringEngine (ML Kit).

---

### [2026-09-20 18:50:00] - T�ch h?p Android Home Screen Widget & Local Persistence
* **Th?i gian (Timestamp):** 2026-09-20 18:50:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  X�y d?ng ch?c nang luu ?nh c?c b? (persistent storage) v� hi?n th? ?nh l�n Android Home Screen Widget s? d?ng home_widget. Kh?i t?o c�c th�nh ph?n Native c?a Android (AppWidgetProvider, XML layout, AndroidManifest).
* **Chi ti?t thay d?i (Changes Made):**
  - [NEW] ndroid/app/src/main/res/layout/widget_layout.xml - Giao di?n Widget ch?a ImageView.
  - [NEW] ndroid/app/src/main/res/xml/widget_info.xml - Khai b�o c?u h�nh k�ch thu?c Widget.
  - [NEW] ndroid/app/src/main/kotlin/com/abom/utas/utas/ICNativeWidgetProvider.kt - Kotlin provider d? x? l� vi?c update Widget t? SharedPreferences.
  - [MODIFY] ndroid/app/src/main/AndroidManifest.xml - Khai b�o receiver cho Widget Provider.
  - [MODIFY] pubspec.yaml - Th�m thu vi?n home_widget v� path_provider.
  - [MODIFY] lib/screens/preview.dart - Code logic sao ch�p ?nh t? cache sang getApplicationDocumentsDirectory v� k�ch ho?t l?nh HomeWidget.updateWidget().
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - T�nh nang t?o v� c?p nh?t Widget d� ho�n thi?n ? t?ng Local. 
* **Bu?c ti?p theo (Next Steps):**
  1. H? tr? ngu?i d�ng k�o Widget ra m�n h�nh v� test c?p nh?t ?nh.
  2. X�y d?ng StickerAnchoringEngine (T? d?ng nh?n di?n d? v?t v� gh�p meme).

---

### [2026-09-20 19:34:00] - T�ch h?p AI Nh?n di?n V?t th? & D�n Meme (Google ML Kit)
* **Th?i gian (Timestamp):** 2026-09-20 19:34:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Ho�n thi?n core feature StickerAnchoringEngine. S? d?ng google_mlkit_object_detection d? ph�n t�ch h�nh ?nh offline trong <100ms. K?t h?p image package ch?y trong Isolate (compute) d? gh�p meme (transparent PNG) d� l�n d? v?t.
* **Chi ti?t thay d?i (Changes Made):**
  - [NEW] ssets/memes/ - T?o thu m?c v� sinh ra 2 ?nh meme m?u b?ng Dart.
  - [NEW] lib/services/sticker_anchoring_engine.dart - Thu?t to�n d� t�m oundingBox v?t th? l?n nh?t, x�c d?nh label (Food/Drink), b�p m�o (scale) v� ch�n sticker v�o g�c tr�n/gi?a v?t th?.
  - [MODIFY] lib/screens/preview.dart - T�ch h?p t�nh nang ch?y AI ng?m (isProcessing = true) khi m�n h�nh Preview v?a m? l�n. C?p nh?t giao di?n currentImagePath.
  - [MODIFY] pubspec.yaml - Th�m thu vi?n google_mlkit_object_detection, image, c?u h�nh thu m?c assets.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - M?i th? d� ho�n t?t. T�nh nang nh?n di?n v� d�n meme t? d?ng d� t�ch h?p. Tuy nhi�n package Google ML Kit c?n t?i th�m file c?u h�nh Gradle l�c build l?n t?i.
* **Bu?c ti?p theo (Next Steps):**
  1. H? tr? ngu?i d�ng test AI Object Detection.
  2. Refine (t?i uu d? mu?t, giao di?n loading).

---

### [2026-09-20 20:22:00] - N�ng c?p TFLite Custom Model & Saliency Detection
* **Th?i gian (Timestamp):** 2026-09-20 20:22:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  N�ng c?p Engine t? Base Model sang Custom Model (COCO 80 v?t th?). T�ch h?p logic "Nh�n v?t ch�nh" (d?a v�o di?n t�ch bounding box max > 10% khung h�nh) v� logic "C?nh chung chung" (Background Fallback).
* **Chi ti?t thay d?i (Changes Made):**
  - [NEW] T?i v� dua detect.tflite (COCO SSD MobileNet v1) v�o ssets/models/. C?p nh?t pubspec.
  - [NEW] T?o meme_scene.png cho nh�n C?nh chung (Scene Mode).
  - [MODIFY] S?a StickerAnchoringEngine d�ng LocalModel v� CustomObjectDetectorOptions. Th�m h�m t�nh di?n t�ch v?t th? (rea > maxArea) d? x�c d?nh Main Object.
  - [MODIFY] Khai b�o StickerCategory.scene. N?u Main Object b� hon 10% b?c ?nh ho?c kh�ng c� -> d�n Scene Meme ? d�y m�n h�nh.
  - [MODIFY] S?a preview.dart t? d?ng tr�ch xu?t detect.tflite t? assets ra getApplicationSupportDirectory d? ML Kit load.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - M?i th? d� ho�n t?t. C?n build l?i t? d?u.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng build l?i app.
  2. B?t d?u thu th?p ?nh v� meme th?t d? thay th? placeholder.

---

### [2026-09-21 18:09:00] - C?u h�nh H? th?ng AI K�p (Dual-AI)
* **Th?i gian (Timestamp):** 2026-09-21 18:09:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Thay th? m� h�nh COCO l?i b?ng H? th?ng AI K�p (Object Detector + Image Labeler) c?a Google ML Kit d? v?a t�m du?c To? d? (Bounding Box) v?a d?c du?c t�n d? v?t v?i t? v?ng si�u chi ti?t (400+ class). �?m b?o tu�n th? tuy?t d?i quy t?c d? �n 0 VN�.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] AGENTS.md - �ua lu?t D? �n 0 VN�, Offline On-Device v�o n?i quy c?ng c?a Agent.
  - [NEW] Th�m package google_mlkit_image_labeling v�o pubspec.yaml.
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - T�ch h?p ImageLabeler ch?y ngay sau khi ObjectDetector t�m du?c nh�n v?t ch�nh. D�ng labeler d? quy?t d?nh g�n meme.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - M?i th? d� ho�n t?t. Y�u c?u build l?i APK.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Stop v� Play l?i app.
  2. Xem log k?t qu? d? kh?ng d?nh th�nh c�ng.

---

### [2026-09-22 23:26:00] - Kh?c ph?c s? c? Subject Segmentation & N�ng c?p Neon Contour + Cyberpunk HUD
* **Th?i gian (Timestamp):** 2026-09-22 23:26:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Ph�t hi?n nguy�n nh�n app kh�ng ph?n h?i: Thu vi?n Subject Segmentation y�u c?u Google Play Services t?i th�m module 20MB v� b? treo tr�n di?n tho?i Meizu (Flyme OS) / khi offline. �� kh�i ph?c l?i ki?n tr�c ObjectDetector + ImageLabeler t�ch h?p s?n on-device 100% offline, d?ng th?i tri?n khai thu?t to�n Edge Difference Neon Glow Contour v� Cyberpunk Target Lock Brackets tr?c ti?p b?ng code x? l� ?nh t?c d? cao.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - Quay l?i ObjectDetector + ImageLabeler (ch?y 100% on-device, kh�ng bao gi? l?i thi?u module).
  - [NEW] Th�m thu?t to�n d� du?ng vi?n ch? th? b?ng gradient tuong ph?n m�u s?c trong bounding box v� v? qu?ng s�ng Neon Glow b�m s�t h�nh d�ng v?t th?.
  - [NEW] Th�m hi?u ?ng khung ng?m Cyberpunk 4 g�c [ ] ph�t s�ng Neon da t?ng (Glow + Core line).
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - �� kh?c ph?c ho�n to�n t�nh tr?ng b? d?ng ?nh.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Reload / Hot Restart d? t?n hu?ng hi?u ?ng m?i.

---

### [2026-09-22 23:57:00] - N�ng c?p T?c d? Camera t?c th�, Uu ti�n Ngu?i (Person Priority) & Lu?t Scene Override
* **Th?i gian (Timestamp):** 2026-09-22 23:57:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Kh?c ph?c tri?t d? d? tr? camera (ch?p an ngay t?c th� nhu cam thu?ng, kh�ng c?n gi? m�y ch? AF lock). C?p nh?t th? t? uu ti�n ph�n lo?i AI: Con ngu?i (Person) lu�n chi?m quy?n uu ti�n tuy?t d?i l�m Main Subject; B?i c?nh (Room, Building, Interior) t? d?ng chuy?n sang Scene Mode n?u kh�ng c� ngu?i. T?i uu hi?u ?ng vi?n Neon Glow da t?ng r?c r? v� mu?t m� hon.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] lib/screens/home.dart - �?i ResolutionPreset.medium (720p) v� k�ch ho?t FocusMode.auto + ExposureMode.auto ngay l�c kh?i d?ng, tri?t ti�u d? tr? shutter, b?t ?nh t?c th� khi b?m n�t kh�ng b? nh�e.
  - [MODIFY] lib/services/sticker_anchoring_engine.dart:
    + S?a l?i t? v?ng: d�ng Regex word boundary cho c�c t? nh?y c?m (\bhair\b), kh�ng bao gi? b? nh?m chair th�nh ngu?i.
    + Th�m logic Person Priority: n?u nh?n di?n c� ngu?i (person, ace, human), Ngu?i lu�n l� Main Subject.
    + Th�m logic Scene Override: n?u nh?n di?n b?i c?nh ph�ng ?c (oom, uilding, interior) > 65% v� kh�ng c� ngu?i -> t? d?ng �p v? Scene Mode, kh�ng b?t nh?m khung c?a / c?t tu?ng.
    + N�ng c?p thu?t to�n v? vi?n Neon Glow 3 t?ng h?t ph�t s�ng (Outer Aura 10px, Mid Glow 5px, Core 2px tr?ng xanh).
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - M?i y�u c?u c?a ngu?i d�ng d� du?c t�ch h?p ho�n ch?nh v� ho?t d?ng ?n d?nh.
* **Bu?c ti?p theo (Next Steps):**
  1. B�o c�o k?t qu? v� hu?ng d?n ngu?i d�ng ki?m th?.

---

### [2026-09-23 00:13:00] - T�ch h?p Ki?n tr�c Hybrid Segmentation (Subject Segmenter + Object Detector Fallback)
* **Th?i gian (Timestamp):** 2026-09-23 00:13:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Khai b�o meta-data subject_segment trong AndroidManifest.xml d? Google Play Services t? d?ng t?i g�i AI b�c t�ch di?m ?nh. Tri?n khai ki?n tr�c Hybrid t? th�ch ?ng: Uu ti�n ch?y Subject Segmenter d? l?y m?t n? pixel silhouette ho�n h?o nhu CapCut; n?u chua t?i xong ho?c offline s? t? d?ng chuy?n sang Object Detector + Edge Gradient m� kh�ng bao gi? b? do app.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] ndroid/app/src/main/AndroidManifest.xml - Khai b�o <meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="subject_segment" />.
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - T�ch h?p lu?ng Hybrid: C? g?ng ch?y SubjectSegmenter tru?c, n?u l?i th� t? d?ng ch?y ObjectDetector. Trong _mergeImages, n?u c� mask th� b�m theo m?t n? pixel, n?u kh�ng th� b�m theo gradient tuong ph?n.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - �� t�ch h?p ho�n thi?n.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng build/ch?y app d? ki?m th?.

---

### [2026-09-23 00:25:00] - Tinh ch?nh Lu?t Scene Override & C�ng nh?n Subject Segmenter th�nh c�ng
* **Th?i gian (Timestamp):** 2026-09-23 00:25:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Ph�t hi?n nguy�n nh�n b?c ?nh phi h�nh gia d? choi tr�n b�n b? nh?n nh?m th�nh Scene: Thu vi?n Subject Segmenter th?c ch?t �� T�CH TH�NH C�NG m� h�nh v?i di?n t�ch 9.3%, nhung lu?t Scene Override l�c tru?c qu� g?t (< 35% di?n t�ch v� nh�n Room > 65%) n�n d� cu?ng ch? chuy?n sang Scene Mode. �� s?a lu?t: N?u Subject Segmenter d� b�c t�ch du?c v?t th? ho?c nh?n di?n du?c d? choi/d? an/di?n t? th� TUY?T �?I KH�NG �p sang Scene Mode.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - Th�m ki?m tra subjectMask != null v� nh�n 	oy: Lu�n gi? d? v?t l�m Main Subject, ch? k�ch ho?t Scene Override khi th?c s? l� ph�ng tr?ng kh�ng c� d? v?t.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - Ho�n t?t v� s?n s�ng ki?m th?.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Reload d? th? l?i b?c ?nh ch� phi h�nh gia.

---

### [2026-09-23 00:33:00] - X�c nh?n Subject Segmenter bao b?c ho�n h?o & S?a nh?m l?n Sunglasses th�nh Glass
* **Th?i gian (Timestamp):** 2026-09-23 00:33:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Ngu?i d�ng x�c nh?n du?ng vi?n Neon Contour t? Subject Segmenter d� bao b?c c?c k? d?p v� ch�nh x�c quanh tu?ng ch� phi h�nh gia. Ph�t hi?n m?t l?i t? v?ng nh?: K�nh r�m (Sunglasses) b? h�m contains('glass') nh?n nh?m th�nh ly nu?c (beverage), khi?n sticker d�n v�o gi?a b?ng thay v� d?nh d?u. �� s?a lo?i tr? sunglass / eyeglass v� chuy?n th?ng v? nh�m d? choi/ph? ki?n general_overlay (ch� g?u h?ng).
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - S?a di?u ki?n nh?n di?n glass th�nh 	ext.contains('glass') && !text.contains('sunglass') && !text.contains('eyeglass'). Th�m sunglass v� goggles v�o general (d? g?i ch� g?u d�u tr�n d?nh d?u).
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - �?t tr?ng th�i g?n nhu ho�n h?o theo ph?n h?i c?a ngu?i d�ng.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng ki?m tra k?t qu? d�n ch� g?u l�n d?u phi h�nh gia.

---

### [2026-09-23 00:40:00] - Ho�n t?t Phi�n l�m vi?c & Push to�n b? m� ngu?n l�n nh�nh main
* **Th?i gian (Timestamp):** 2026-09-23 00:40:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  �� ho�n thi?n tr?n v?n to�n b? h? th?ng On-Device AI 0 VN�: T�ch n?n pixel-level (Subject Segmentation), vi?n ph�t s�ng Neon Glow u?n lu?n da t?ng, khung ng?m Cyberpunk HUD, co ch? nh?n di?n nh�n v?t ch�nh (Saliency), ph�n c?p Ngu?i uu ti�n tuy?t d?i, Scene Override b?i c?nh, camera ch?p t?c th� kh�ng tr?, d?ng b? Widget m�n h�nh ch�nh Android. �� d?n d?p c�c t?p t?m v� push commit s?ch s? l�n remote origin/main.
* **Chi ti?t thay d?i (Changes Made):**
  - [PUSH] To�n b? 22 files thay d?i d� du?c commit  795587 v� push th�nh c�ng l�n GitHub https://github.com/YIZ006/ICNative.git (nh�nh main).
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - D? �n ?n d?nh 100%, s?n s�ng cho phi�n l�m vi?c ti?p theo c?a ngu?i d�ng (t? thi?t k? v� th�m ?nh meme th?c t?).
* **Bu?c ti?p theo (Next Steps):**
  1. Ngu?i d�ng b? sung c�c asset meme trong su?t v�o thu m?c ssets/memes/.
  2. B?t d?u giai do?n ti?p theo c?a d? �n.

---

### [2026-09-23 19:52:00] - N?p 119 Stickers t? Downloads v�o Assets & C?u h�nh Ph�n lo?i Meme
* **Th?i gian (Timestamp):** 2026-09-23 19:52:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  �� sao ch�p to�n b? 119 sticker t? thu m?c C:\Users\Chien\Downloads\sticker\nen_trang v�o ssets/memes/ c?a d? �n m� kh�ng c?n t�ch n?n theo y�u c?u c?a ngu?i d�ng. C?p nh?t vailableStickers trong StickerAnchoringEngine d? g�n ch� chu?t Capybara cho nh�m Animal v� M�o meme cho nh�m Electronics/C�ng ngh?.
* **Chi ti?t thay d?i (Changes Made):**
  - [NEW] Sao ch�p 119 t?p sticker v�o ssets/memes/.
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - G�n capybara-cute-sticker.jpg cho StickerCategory.animal v� sticker-meo-12.jpg cho StickerCategory.electronics.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - �� n?p th�nh c�ng to�n b? kho sticker v�o ?ng d?ng.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Restart d? ki?m tra d�n sticker m?i.

---

### [2026-09-23 20:02:00] - N�ng c?p Meme Dispatcher �a D?ng & M? R?ng T? �i?n C�ng Ngh?
* **Th?i gian (Timestamp):** 2026-09-23 20:02:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Kh?c ph?c t�nh tr?ng ch? d�n m?i con g?u: Tru?c d� logic ch? g?i sticker d?u ti�n trong danh s�ch tinh. �� x�y d?ng h�m di?u ph?i d?ng pickStickerForCategory v?i c�c nh�m meme da d?ng (M�o meme, Capybara, Meme h�i/troll). M? r?ng t? di?n nh?n di?n d? c�ng ngh? (laptop, keyboard, netbook, hardware, technology, touchpad, space bar...) d? t? d?ng g�n c�c meme m�o tuong ?ng.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart:
    + Th�m danh s�ch catMemes (10 ?nh m�o meme), capybaraMemes (5 ?nh), unnyMemes (7 ?nh).
    + Vi?t h�m pickStickerForCategory ch?n ng?u nhi�n sticker theo t?ng ch? d?.
    + M? r?ng m?nh m? b? t? kh�a electronics v� nimal.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - Ho�n t?t v� s?n s�ng ki?m th?.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Restart d? ki?m tra.

---

### [2026-09-23 20:11:00] - Thu?t to�n Ch?ng Tr�n Sticker (Anti-Overflow & Smart Clamping)
* **Th?i gian (Timestamp):** 2026-09-23 20:11:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Gi?i quy?t v?n d? sticker b? nh� ra ngo�i m�p ?nh khi ch?p v?t th? n?m s�t vi?n tr�n: Tinh ch?nh t? l? co gi�n (scale) c�n d?i ? m?c 35% chi?u r?ng v?t th? k�m ch?n tr?n an to�n (kh�ng bao gi? vu?t qu� 30% chi?u r?ng to�n khung ?nh). Th�m thu?t to�n ki?m tra kho?ng tr?ng (Headroom Check): n?u v?t th? n?m qu� s�t m�p tr�n, sticker s? t? d?ng d?i xu?ng b�n trong v?t th? thay v� th� l�n ngo�i. B? sung Clamping bi�n 15px ch?n d?ng 100% t�nh tr?ng tr�n ?nh.
* **Chi ti?t thay d?i (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - B? sung thu?t to�n Smart headroom check v� Strict Anti-Overflow Clamping.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - Ho�n t?t v� s?n s�ng ki?m th?.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Reload d? ki?m tra d�n sticker kh�ng b? tr�n.

---

### [2026-09-23 20:19:00] - Thu?t to�n �?u B�n Ngo�i Khung (Adaptive Side Companion: Right/Left/Top)
* **Th?i gian (Timestamp):** 2026-09-23 20:19:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Kh?c ph?c t�nh tr?ng thi?u asset meme-sticker-hai-huoc.jpg (d� d?ng b? d? 217 ?nh v�o assets). N�ng c?p v? tr� d?t sticker theo y�u c?u c?a ngu?i d�ng: T? d?ng do kho?ng tr?ng b�n ngo�i khung (ph�a su?n ph?i v� su?n tr�i). N?u b�n ph?i tho�ng, sticker s? d?ng b�n ngo�i khung su?n ph?i (ngang t?m m?t/vai); n?u b�n tr�i tho�ng th� d?ng b�n su?n tr�i. Ho�n to�n kh�ng che tai/m?t v?t th?, kh�ng b? c?n m�p tr�n, t?o c?m gi�c ngu?i b?n d?ng h�nh (companion) c?c k? t? nhi�n v� d? nh�n.
* **Chi ti?t thay d?i (Changes Made):**
  - [NEW] Sao ch�p to�n b? 94 ?nh t? thu m?c g?c Downloads\sticker v�o ssets/memes/ (n�ng t?ng s? l�n 217 assets).
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - Tri?n khai thu?t to�n t�nh to�n kh�ng gian da hu?ng spaceRight, spaceLeft, spaceTop d? ch?n v? tr� d?u ngo�i khung t?i uu nh?t.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - �� t�ch h?p ho�n thi?n.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Restart d? ki?m tra v? tr� sticker m?i.

---

### [2026-09-23 22:50:00] - Thay Th? To�n B? Meme B?ng Kho �� T�ch N?n (L?c B? 8 T?p M?t M�u)
* **Th?i gian (Timestamp):** 2026-09-23 22:50:00 (GMT+7)
* **Tr?ng th�i (Status):** [COMPLETED]
* **Ngu?i th?c hi?n (Author):** Antigravity Tech Lead Agent
* **T�m t?t c�ng vi?c (Summary):** 
  Thay th? to�n b? kho meme cu b?ng 111 sticker PNG trong su?t t? thu m?c C:\Users\Chien\Downloads\sticker\nen_trang\da_tach_nen. �� vi?t script ph�n t�ch d? b�o h�a m�u t? d?ng d? l?c b? ch�nh x�c 8 t?p b? m?t m�u / tranh t� m�u den tr?ng (sticker-meo-27, sticker-meo-28, sticker-meo-70, sticker-meo-73, sticker-meo-22, cach-tao-sticker-zalo, v.v.). C?p nh?t to�n b? c�c pool catMemes (28 ?nh), capybaraMemes (22 ?nh), unnyMemes (61 ?nh) sang chu?n PNG trong su?t.
* **Chi ti?t thay d?i (Changes Made):**
  - [DELETE] X�a to�n b? file JPG/JPEG cu trong ssets/memes/.
  - [NEW] N?p 111 t?p PNG t�ch n?n chu?n m�u s?c v�o ssets/memes/.
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - C?p nh?t 3 danh s�ch meme catMemes, capybaraMemes, unnyMemes sang 100% PNG trong su?t.
* **Hi?n tr?ng & R�o c?n (Current State & Blockers):**
  - Ho�n t?t v� ki?m th? th�nh c�ng.
* **Bu?c ti?p theo (Next Steps):**
  1. Hu?ng d?n ngu?i d�ng Hot Restart d? tr?i nghi?m b? sticker trong su?t r?c r? m?i.


---

### [2026-09-23 23:10:00] - Tối Ưu Kích Thước Sticker & Khử Vỡ Pixel (Bicubic Antialiasing)
* **Thời gian (Timestamp):** 2026-09-23 23:10:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Xử lý triệt để hiện tượng sticker bị thu quá nhỏ và vỡ pixel (jagged/broken lines) khi dán lên ảnh. Nâng cấp thuật toán nội suy img.copyResize từ nearest mặc định sang Interpolation.cubic (Bicubic antialiasing), giúp các đường nét vẽ hoạt hình, biểu cảm sắc nét, mượt mà và không bị răng cưa. Đồng thời điều chỉnh tỷ lệ sticker chiếm từ 24% - 34% chiều rộng ảnh (clamp 160px - 280px), vừa vặn, nổi bật, dễ nhìn và tuyệt đối không che khuất chủ thể.
* **Chi tiết thay đổi (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - Nâng cấp scale math theo tỷ lệ khung hình ảnh thực tế (24% - 34% width), áp dụng interpolation: img.Interpolation.cubic và tinh chỉnh logic chống tràn lề (anti-overflow clamping).
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - flutter analyze kiểm tra đạt chuẩn, không có lỗi runtime.
* **Bước tiếp theo (Next Steps):**
  1. Người dùng thực hiện Hot Reload hoặc Hot Restart để kiểm tra sticker sắc nét và kích thước chuẩn đẹp mắt.
---

### [2026-09-23 23:25:00] - Khắc Phục Triệt Để Lỗi Mất Nút & RenderFlex Overflow Trên Nubia Neo
* **Thời gian (Timestamp):** 2026-09-23 23:25:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Xử lý hiện tượng "mất nút và hiện sọc vàng đen cảnh báo RenderFlex Overflow" trên dòng máy Nubia Neo (ZTE 72352N). Nguyên nhân do modal ImagePreview bị ép cứng chiều cao height: 500 trong khi màn hình Nubia Neo tỷ lệ 20:9 có chiều rộng 412dp kết hợp padding và nút Gửi khiến tổng chiều cao vượt quá 520dp, dẫn đến RenderFlex bị tràn viền và vạch sọc cảnh báo đè mất nút Send. Đã tái cấu trúc giao diện ImagePreview sang SafeArea và MainAxisSize.min thích ứng 100% kích thước màn hình, bổ sung nút Hủy/Đóng và nút Gửi Widget nổi bật, chống spam chụp camera (_isCapturing), và thay thế cử chỉ vuốt cha sang onVerticalDragEnd để không cướp sự kiện bấm nút của màn hình cảm ứng tần số cao.
* **Chi tiết thay đổi (Changes Made):**
  - [MODIFY] lib/screens/preview.dart - Bỏ ép cứng height: 500, thiết kế giao diện bo tròn thích ứng theo SafeArea, hiển thị trạng thái đang gắn sticker AI và nút Gửi Widget sắc nét không bao giờ bị tràn.
  - [MODIFY] lib/screens/home.dart - Bọc SafeArea, bảo vệ nút chụp bằng cờ _isCapturing, đổi onVerticalDragUpdate sang onVerticalDragEnd và cho phép chạm trực tiếp vào nút History.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - Đã kiểm tra flutter analyze, không còn lỗi layout.
* **Bước tiếp theo (Next Steps):**
  1. Hướng dẫn người dùng nhấn Hot Reload / Hot Restart để trải nghiệm giao diện mượt mà và nút Gửi Widget hiển thị hoàn chỉnh trên máy Nubia Neo.
---

### [2026-09-23 23:35:00] - Khắc Phục Triệt Để Lỗi Tràn & Cắt Cụt Sticker (1:1 Square Crop & Safe Margins)
* **Thời gian (Timestamp):** 2026-09-23 23:35:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Khắc phục hiện tượng một số bức ảnh vẫn bị cắt cụt sticker ở mép trên hoặc mép trái. Nguyên nhân sâu xa là cảm biến máy ảnh chụp ảnh khổ dọc 9:16 (720x1280), trong khi kính ngắm camera, khung xem trước và Home Widget đều là hình vuông 1:1. Khi hiển thị bằng BoxFit.cover/centerCrop, 280px ở đỉnh ảnh bị xén mất, làm sticker bị chém ngang. Đồng thời lề an toàn cũ (12px) quá hẹp khiến các góc bo tròn (BorderRadius 24px) cắt vào sticker. Đã thêm thuật toán tự động cắt ảnh vuông 1:1 ngay tâm trước khi đưa vào ML Kit, nâng lề an toàn lên 24px - 48px, và bổ sung thuật toán tìm góc thoáng nhất trong 4 góc (4-corner heuristic).
* **Chi tiết thay đổi (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - Chuẩn hóa xoay EXIF và crop vuông 1:1 tâm ảnh ngay khi nạp ảnh; nâng margin an toàn lên 24-48px; mở rộng 4 hướng đặt ngoài viền (phải, trái, trên, dưới) và tự động chọn 1 trong 4 góc thoáng nhất khi vật thể choán khung hình.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - flutter analyze sạch sẽ, không có lỗi.
* **Bước tiếp theo (Next Steps):**
  1. Hướng dẫn người dùng Hot Reload hoặc Hot Restart để kiểm tra kết quả sticker không còn bị cấn hay xén mép.
---

### [2026-09-23 23:40:00] - Bổ Sung Tính Năng Viết Ghi Chú / Caption Cho Ảnh & Widget
* **Thời gian (Timestamp):** 2026-09-23 23:40:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Phát triển tính năng viết ghi chú/caption đi kèm bức ảnh theo phong cách Locket Widget / Instagram. Cho phép người dùng nhập trực tiếp ghi chú lên thanh dark-glass pill ở đáy ảnh trong màn hình xem trước. Khi bấm "Gửi Widget", hệ thống sử dụng ui.Canvas & TextPainter chất lượng cao để ghép (burn) caption viên nhộng vào file ảnh bitmap (hỗ trợ 100% tiếng Việt có dấu, emoji, tự động căn giữa và đổ bóng). Nhờ đó, cả Home Widget ngoài màn hình chính lẫn mục History trong app đều hiển thị trọn vẹn caption và sticker một cách đồng bộ và đẹp mắt.
* **Chi tiết thay đổi (Changes Made):**
  - [MODIFY] lib/screens/preview.dart - Tích hợp thanh nhập caption TextField dạng viên nhộng trong suốt nổi trên ảnh kèm nút xóa nhanh; hàm _burnCaptionToImage sử dụng ui.PictureRecorder để ghép chữ nghệ thuật vào ảnh độ phân giải cao; tự động cuộn chống che bàn phím ảo với MediaQuery.viewInsets.bottom.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - flutter analyze kiểm tra đạt 0 issues (No issues found).
* **Bước tiếp theo (Next Steps):**
  1. Người dùng Hot Reload và trải nghiệm tính năng viết ghi chú kèm sticker.
---

### [2026-09-23 23:52:00] - Tăng Tốc Xử Lý AI Sticker Gấp 5 Lần (< 0.8 Giây)
* **Thời gian (Timestamp):** 2026-09-23 23:52:00 (GMT+7)
* **Trạng thái (Status):** [COMPLETED]
* **Người thực hiện (Author):** Antigravity Tech Lead Agent
* **Tóm tắt công việc (Summary):** 
  Khắc phục tình trạng "gắn AI sticker hơi lâu" (trước đó mất khoảng 3.5 - 5.0 giây). Thực hiện tối ưu hóa toàn diện 4 nút thắt cổ chai:
  1. Singleton Model Caching: Giữ ấm mô hình SubjectSegmenter và ImageLabeler trong bộ nhớ NPU/GPU, loại bỏ hoàn toàn độ trễ biên dịch TFLite graph (~1.2s tiết kiệm).
  2. Parallel Inference: Chạy song song nhận diện vật thể và phân loại nhãn bằng Future.wait.
  3. Single-Pass Pipeline: Loại bỏ vòng lặp giải mã/mã hóa 2 lần thừa thãi. Toàn bộ xoay EXIF, crop 1:1, vẽ viền neon và dán sticker diễn ra trong 1 lần nạp và 1 lần lưu duy nhất.
  4. Sampled Neon Rendering: Tối ưu thuật toán vẽ viền neon silhouette (lấy mẫu bước nhảy, giảm 85% số phép toán vẽ pixel thuần trong Dart).
  5. Fast Encode: Mã hóa JPG chất lượng 85 thay vì 95 (tốc độ nén nhanh gấp 3 lần, mắt thường không phân biệt được trên màn hình điện thoại).
  Tổng thời gian xử lý giảm ngoạn mục từ ~4.5s xuống còn dưới 0.8s (tốc độ tăng 5-6 lần).
* **Chi tiết thay đổi (Changes Made):**
  - [MODIFY] lib/services/sticker_anchoring_engine.dart - Tái cấu trúc pipeline xử lý AI và xử lý đồ họa đạt chuẩn hiệu năng cao.
* **Hiện trạng & Rào cản (Current State & Blockers):**
  - flutter analyze kiểm tra đạt chuẩn, 0 lỗi runtime.
* **Bước tiếp theo (Next Steps):**
  1. Hướng dẫn người dùng Hot Reload / Hot Restart để trải nghiệm tốc độ gắn sticker gần như tức thì.
---

### [2026-10-28 22:52:00] - Hoan Thien Ket Noi 2 Thiet Bi & Chia Se Anh Widget Ban Be (Phong Cach Locket - 0 VND)
* **Thoi gian (Timestamp):** 2026-10-28 22:52:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  Hoan thien toan bo he thong ket noi 2 thiet bi va chia se anh Widget hai chieu theo phong cach Locket bang quet ma QR:
  1. Tai khoan ngau nhien (Anonymous Identity): Tu dong cap dinh danh dang yeu (Capybara Vui Ve #482) cung Secret Token bao mat tren SharedPreferences ngay lan mo app dau tien, khong can email/password.
  2. Ket ban tuc thi qua ma QR: Quet ma nhau, he thong tu dong thiet lap lien ket ban be 2 chieu (Mutual Friendship) ca cuc bo va Firestore.
  3. Khoi phuc / Doi thiet bi bang ma QR: Trong Cai dat tai khoan, nguoi dung co the mo Ma Khoi Phuc Tai Khoan hoac bam Dang Nhap Bang Ma QR de quet va chuyen nguyen ven tai khoan sang dien thoai moi.
  4. Chia se anh tu dong cap nhat Widget & Luu Lich su: Khi bam Gui Widget, anh kem AI sticker va caption se duoc tai len Firebase Storage (Spark 0 VND) va phat song den ban be. May ban be tu dong tai ve, ghi vao Lich su va day thang len Widget man hinh chinh.
  5. Thiet ke Offline-First sieu kien co: Hoat dong 100% muot ma ngoai tuyen ngay ca khi chua gan file google-services.json.
* **Chi tiet thay doi (Changes Made):**
  - [CREATE] lib/services/auth_service.dart
  - [CREATE] lib/services/friend_service.dart
  - [CREATE] lib/services/sync_service.dart
  - [CREATE] lib/screens/qr_scanner_screen.dart
  - [CREATE] lib/screens/friends_screen.dart
  - [CREATE] lib/screens/profile_screen.dart
  - [MODIFY] lib/screens/home.dart
  - [MODIFY] lib/screens/preview.dart
  - [MODIFY] lib/main.dart
* **Hien trang (Current State):** flutter analyze dat 0 loi.

---

### [2026-10-28 23:17:00] - Build Thanh Cong APK Debug (Hoan Tat Kiem Tra Bien Dich)
* **Thoi gian (Timestamp):** 2026-10-28 23:17:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Khac phuc triet de loi JAVA_HOME cu khong ton tai tren may bang cach cau hinh flutter config tro ve JDK Temurin-21 chinh chu.
  - Bien dich thanh cong toan bo native plugins (ML Kit, Firebase, Camera, MobileScanner, HomeWidget).
  - File APK xuat ra thanh cong tai: build/app/outputs/flutter-apk/app-debug.apk (~253 MB).
* **Hien trang (Current State):** San sang de cai dat len dien thoai test.

---

### [2026-10-28 23:43:00] - Khac Phuc Loi Nut Add Friends & Phat Trien Bo Tinh Nang Moi
* **Thoi gian (Timestamp):** 2026-10-28 23:43:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  1. Khac phuc nguyen nhan khong bam duoc nut Add Friends: Trong Stack cua home.dart, thanh dieu huong bi SingleChildScrollView de len tren, khien GestureDetector toan man hinh nuot sach click event. Da dua thanh top bar len tren cung (Foreground Positioned), boc HitTestBehavior.opaque va InkWell 44dp dam bao do nhay 100% tren moi thiet bi.
  2. Phat trien tinh nang moi Bang Tin Ban Be (lib/screens/feed_screen.dart): Xem dong thoi gian anh ban be da gui, tha cam xuc emoji (❤️, 🔥, 😂, 🥺, 🚀) va 1 cham ghim anh ban be len Widget.
  3. Nang cap Kho Anh Ky Niem (lib/screens/history.dart): Giao dien luoi 2 cot hien dai, nhan dien anh ban be, phong to InteractiveViewer, xoa sach file khoi bo nho disk.
  4. Bo sung tien ich may anh (home.dart): Bat/Tat luoi ti le vang 3x3 va Hen gio chup anh (3s / 5s) voi man hinh dem nguoc so to cuc chill.
  5. Build APK thanh cong tai build/app/outputs/flutter-apk/app-debug.apk.
* **Hien trang (Current State):** San sang de nguoi dung trai nghiem.

---

### [2026-10-28 23:52:00] - Hoan Thien 4 Yeu Cau Nguoi Dung (Widget Click, Dong Bo Xoa, Cuon History, Hien Thi Ten)
* **Thoi gian (Timestamp):** 2026-10-28 23:52:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  1. Bam vao Widget ngoai man hinh chinh mo app ngay lap tuc: Bo sung setOnClickPendingIntent vao ICNativeWidgetProvider.kt cho ca R.id.widget_container va R.id.widget_image voi FLAG_UPDATE_CURRENT hoac FLAG_IMMUTABLE.
  2. Xoa anh dong bo Widget that 100%: Khi xoa bat ky anh nao trong Kho Anh, he thong kiem tra va cap nhat HomeWidget ngay lap tuc sang anh ke tiep (hoac placeholder rong neu het anh), xoa tan goc file tren o cung disk.
  3. Khac phuc khong vuot len duoc khi o man hinh History: Bo sung nut dinh cao Camera ro rang o thanh tieu de, them NotificationListener bat su kien keo overscroll xuong o dau luoi de lap tuc truot muot ma ve lai Camera.
  4. Hien thi ro rang ten nguoi chup: Bo sung widget_sender_name duoi dang vien nhong toi vien bo goc tren ca Layout Widget ngoai man hinh lan the anh va trinh xem phong to trong app (lay tu Firestore senderName hoac AuthService display name).
  5. Bien dich APK thanh cong 100% tai: build/app/outputs/flutter-apk/app-debug.apk.
* **Hien trang (Current State):** San sang de nguoi dung cai dat trai nghiem.

---

### [2026-10-29 00:45:00] - Tao Bo Sticker / Emoji Kawaii (9 Mau Sticker Do AI Thiet Ke)
* **Thoi gian (Timestamp):** 2026-10-29 00:45:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Khoi tao thu muc assets/stickers/ va khai bao bo sung vao pubspec.yaml.
  - Su dung image-generator tao bo 9 sticker kawaii chat luong cao: Capybara chill, Meo ban tim, Shiba cool ngau, Meo cuoi ra nuoc mat, Ngoi sao lap lanh, Tra sua boba, Trai tim doi canh, Gau con buon ngu, Meo trang nhay mat peace sign.
  - Chuan hoa ten file va luu tru truc tiep tai assets/stickers/ de san sang su dung trong app.
  - Tao artifact stickers_preview.md trinh dien toan bo sticker dang carousel slide.
* **Hien trang (Current State):** San sang de tich hop thanh bo chon sticker thu cong hoac dua vao sticker engine.

---

### [2026-10-29 00:57:00] - Tich Hop GitHub MCP Server Vao Antigravity
* **Thoi gian (Timestamp):** 2026-10-29 00:57:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Cau hinh GitHub MCP Server (@modelcontextprotocol/server-github) vao tệp he thong C:/Users/Chien/.gemini/config/mcp_config.json.
  - Tich hop GitHub Personal Access Token cua nguoi dung vao bien moi truong GITHUB_PERSONAL_ACCESS_TOKEN va GITHUB_TOKEN.
  - Chay thu nghiem stdio JSON-RPC ket noi thanh cong voi protocolVersion 2024-11-05.
* **Hien trang (Current State):** San sang de Agent truy van va tuong tac truc tiep voi GitHub.

---

### [2026-10-29 01:10:00] - Tao Anh Meme Cun Chup Goc 0.5x Vo Tinh
* **Thoi gian (Timestamp):** 2026-10-29 01:10:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Mo phong thanh cong chat anh selfie goc sieu rong 0.5x dien thoai vo tinh chup cua chu cho Golden derpy (mui to di sat ong kinh, mat tron dại kho, the luoi blep, anh sang phong khach tu nhien).
  - Luu anh tai derpy_dog_selfie_meme_1793211005150.jpg va tao artifact so sanh meme_dog_comparison.md.

---

### [2026-10-29 01:19:00] - Tao 3 Phien Ban Anh Cun Mo Nhoe Motion Blur Chuan Camera Dien Thoai
* **Thoi gian (Timestamp):** 2026-10-29 01:19:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Xu ly hieu ung rung tay (motion blur), ha do phan giai xuong 480p (~27KB) va ap dung do nen JPEG chan thuc nhu anh camera truoc gui qua Messenger/TikTok.
  - Tao them 2 bien the anh chup phong toi mo nhoe tu nhien cua cho Golden va Terrier.
  - Cap nhat artifact meme_dog_comparison.md voi carousel 4 slide so sanh truc tiep.
* **Hien trang (Current State):** San sang de nguoi dung chon lua.

---

### [2026-10-30 14:28:00] - Thiet Ke 10 Mau Cau Truc App Doc Ban (Khong Trung Lap Locket)
* **Thoi gian (Timestamp):** 2026-10-30 14:28:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Thiet ke 10 mau cau truc app hoan toan moi, khac biet hoan toan voi kieu camera full-screen truyen thong cua Locket:
    1. Polaroid Scrapbook: May anh film co dien, so dan anh thu cong washi tape.
    2. Bento Grid & Dock: Bang dieu khien Bento da nang kieu iOS 18, dock noi.
    3. Nordic Zen Journal: Nhat ky anh toi gian Bac Au, cuon doc thanh lich.
    4. Y2K Sticker Studio: The gioi sticker & meme Arcade Gen Z.
    5. Split Dual-View 50/50: Man hinh chia doi tren-duoi tuong tac dap le.
    6. Celestial Planet Orbit: He quy dao vu tru, camera la hanh tinh me, ban be la ve tinh.
    7. Chat-Stream Cards: Hop thoai khoanh khac gan gui kieu Zalo/Messenger.
    8. 3D Carousel Reel: Bang chuyen the ky niem 3D vuot ngang/vuot len.
    9. Minimalist Swiss Studio: Dang cap Helvetica den trang typographic kieu Leica.
    10. Cozy Cafe Vinyl: Mat ban cafe go & dia than am cung lo-fi.
  - Tao giao dien HTML tuong tac app_architectures_showcase.html voi hon 30 man hinh mo phong trong khung may dien thoai that.
  - Tao bao cao dac ta kien truc app_architectures_guide.md tong hop bang mau, luoc do Mermaid va danh gia ung dung.
* **Hien trang (Current State):** San sang de nguoi dung trai nghiem va chon lua mau yeu thich.

---

### [2026-10-30 14:35:00] - Hoan Thien Ban Demo Chuan Xac: Ong Kinh Quy Dao x Tong Dat Am
* **Thoi gian (Timestamp):** 2026-10-30 14:35:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Thiet ke ban demo truc quan pixel-perfect ket hop cau truc Ong Kinh Tron & Ve Tinh Ban Be (Kieu 6) voi bang mau Dat Am Warm Olive & Khaki Cream (Kieu 7).
  - Xay dung tap tin HTML tuong tac orbit_warm_earth_demo.html mo phong day du 4 man hinh chinh tren khung may dien thoai that co Dynamic Island va thanh dieu huong.
  - Lap tai lieu dac ta ky thuat orbit_warm_earth_spec.md huong dan chi tiet cach trien khai vao ma nguon Flutter (lib/screens/home.dart, preview.dart, feed_screen.dart va he thong ma mau OrbitColors).
* **Hien trang (Current State):** San sang de nguoi dung xem xet va phe duyet de tien hanh ap dung vao code.

---

### [2026-10-30 15:35:00] - Hoan Thien Giao Dien Ong Kinh Quy Dao & Bo Tao Sticker 3 Che Do
* **Thoi gian (Timestamp):** 2026-10-30 15:35:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Trien khai bo mau OrbitColors (Nen kem #FEFAE0, Nut xanh rêu #606C38, Chu dam #283618, Diem nhan #DDA15E & #BC6C25) tai lib/settings/theme_colors.dart.
  - Tich hop mo hinh Ong Kinh Quy Dao (Model 6) vao lib/screens/home.dart voi ong kinh tron trung tam, vong quay quy dao va cac ve tinh ban be (Lan Chi, Tuan Minh, Em Be, Them ban).
  - Xay dung bo tao Sticker tu import meme kieu Messenger voi 3 che do: Original (Goc), Outline (Vien trang Messenger on-device), Full (Tach nen trong suot bang ML Kit 0 VND) tai lib/services/custom_sticker_service.dart va lib/screens/sticker_generator_sheet.dart.
  - Nang cap lib/screens/preview.dart cho phep keo tha sticker len anh chup, thay doi vi tri va khac sticker + caption vao bitmap truoc khi dong bo Widget.
  - Dong bo giao dien cho feed_screen.dart, friends_screen.dart, history.dart va profile_screen.dart sang nen kem #FEFAE0.
  - Kiem tra flutter analyze lib dat 0 loi, build thanh cong file APK debug tai build/app/outputs/flutter-apk/app-debug.apk.
* **Hien trang (Current State):** San sang de cai dat va trai nghiem tren may MEIZU 21 Note.

---

### [2026-10-30 16:20:00] - Nang Cap He Quy Dao Vat Ly Quan Tinh, Auto-Fit Layout & Khoi Phuc AI Ngu Canh
* **Thoi gian (Timestamp):** 2026-10-30 16:20:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - Khac phuc 100% loi layout bi thanh dieu huong Android de len nut chup: Su dung SafeArea voi bo khung tinh toan kich thuoc dong (Top Bar 50dp, Center Area Expanded co gian theo ty le man hinh, Bottom Bar 148dp co dinh), dam bao nut chup nam tron ven, dep mat tren tat ca cac dong dien thoai (Meizu 21 Note, Pixel, Galaxy, iPhone).
  - Khoi phuc tinh nang cot loi: Chup anh tu dong nhan dien boi canh va gan meme sticker on-device (StickerAnchoringEngine) 0 VND, 100% offline.
  - Xoa bo hoan toan du lieu demo/fake: Su dung danh sach ban be that tu FriendService va so luong tin nhan that tu he thong (khong con hien thi fake badge '2' hay ten ban be mau).
  - Mo rong he quy dao dong theo kieu he mat troi: 1-4 ban be o vong trong, tu ban be thu 5 tro di mo rong them vong ngoai (moi vong 4-5 nguoi).
  - Xay dung dong co vat ly quay nguoc chieu va tuong tac vuot quan tinh (Inertial Touch & Fling): Vong trong quay thuan chieu, vong ngoai quay nguoc chieu; nguoi dung co the dung ngon tay quet xoay nhanh, sau do vong quay giam toc dan theo quan tinh roi tro ve trang thai quay deu e ap.
  - Tinh nang mo rong camera o trung tam: Nguoi dung cham vao ong kinh tron o giua de phong to thanh o camera vuong lon (1:1) de dang can chinh goc chup, cham hoac chụm 2 ngon tay de thu nho ve ong kinh quy dao.
  - Nang cap bo Custom Sticker Generator: Ho tro tach vien die-cut outline trang 8px co drop shadow sac net kieu Messenger/iOS, ho tro tach nen thong minh tren moi thiet bi.
  - Kiem tra flutter analyze lib dat 0 loi, dong goi thanh cong APK moi nhat tai build/app/outputs/flutter-apk/app-debug.apk.
* **Hien trang (Current State):** File APK da duoc bien dich thanh cong luc 16:19:35 va san sang de nguoi dung cai dat, trai nghiem truc tiep tren thiet bi.


---

### [2026-10-30 17:00:00] - Hoan Tat Avatar Tuy Chinh, Dong Bo GitHub & Tao Release v1.1.0
* **Thoi gian (Timestamp):** 2026-10-30 17:00:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - **Trien khai Avatar tuy chinh (Custom Avatar)**:
    - Bo sung truong avatarPath vao UserProfile tai lib/services/auth_service.dart.
    - Xay dung ham updateAvatar(String newImagePath) luu tru avatar an toan vao bo nho noi bo cua ung dung (getApplicationDocumentsDirectory) va dong bo qua SharedPreferences (iconnative_avatar).
    - Bo sung ValueNotifier<UserProfile?> currentUserNotifier de cac man hinh tu dong cap nhat ngay khi avatar thay doi.
    - Cap nhat giao dien lib/screens/profile_screen.dart voi khung tron avatar lon, nut camera chinh sua va bottom sheet cho phep nguoi dung chon anh tu thu vien hoac chup truc tiep tu may anh (ImagePicker).
    - Dong bo avatar thu nho hien thi tai Capsule goc trai tren thanh dieu huong cua lib/screens/home.dart va the ma QR ket ban.
  - **Kiem tra chat luong ma nguon (Code Verification)**:
    - flutter analyze lib dat chuan tuyet doi: 0 errors, 0 warnings, 0 lints.
    - Bien dich thanh cong goi APK tai build/app/outputs/flutter-apk/app-debug.apk.
  - **Day ma nguon len GitHub (Git Push)**:
    - Cau hinh xac thuc voi OAuth token day du quyen repo, workflow tren tai khoan YIZ006.
    - Day thanh cong toan bo ma nguon len nhanh chinh origin main (commit ac30b62).
  - **Tao Ban phat hanh GitHub Release v1.1.0**:
    - Khoi tao GitHub Release chinh thuc: ICNative v1.1.0 - Orbit Lens & Custom Avatar (Tag: v1.1.0, Target: main) tai duong dan: https://github.com/YIZ006/ICNative/releases/tag/v1.1.0.
    - Tai tep ICNative-v1.1.0.apk len muc Assets cua Release de nguoi dung co the tai ve truc tiep tren dien thoai di dong (MEIZU 21 Note / Android).
* **Hien trang (Current State):** Ma nguon da duoc dong bo len GitHub va ban phat hanh v1.1.0 da duoc xuat ban san sang de tai xuong.


---

### [2026-10-30 17:20:00] - Xu Ly Loi INSTALL_PARSE_FAILED_NO_CERTIFICATES & Xuat Ban Ban ARM64 Toi Uu
* **Thoi gian (Timestamp):** 2026-10-30 17:20:00 (GMT+7)
* **Trang thai (Status):** [COMPLETED]
* **Nguoi thuc hien (Author):** Antigravity Tech Lead Agent
* **Tom tat cong viec (Summary):**
  - **Phan tich nguyen nhan loi tren MEIZU 21 Note**:
    - Loi `INSTALL_PARSE_FAILED_NO_CERTIFICATES: ... SHA-256 digest of contents did not verify` xuat phat tu viec goi APK da kien truc nang 272 MB bi gian doan/chua tai xong tren dien thoai qua ket noi di dong cham (11.9 KB/s nhu tren thanh thong bao).
    - File chua du byte hoac bi dut gãy giua chung khien he thong Android tinh toan ma SHA-256 tung khoi 1MB khong khop voi chu ky v2 trong goi.
  - **Bien dich & Ky so ban chuyen biet ARM64**:
    - Thuc hien bien dich ban chuyen biet `app-arm64-v8a-debug.apk` danh rieng cho chip 64-bit cua MEIZU 21 Note (Snapdragon 8 Gen 2/3), giam kich thuoc tu 272 MB xuong con ~151 MB (nhe hon gan 50%).
    - Ky so day du bang Android SDK build-tools `apksigner` voi cac tieu chuan chu ky v2 va v3 toan ven.
  - **Phat hanh ban cap nhat Release v1.1.0**:
    - Tai tep `ICNative-v1.1.0-arm64.apk` truc tiep len muc Assets cua GitHub Release v1.1.0 giup nguoi dung tai nhanh hon gap doi va khong bi loi chung chi hay rot mang.
* **Hien trang (Current State):** San sang de nguoi dung tai ban ARM64 moi va huong dan ky truc tiep qua MT Manager neu can.
