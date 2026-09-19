# ICNative 📸✨

> **Interactive Context-Aware Meme & Photo Sharing Home Screen Widget**  
> Ứng dụng chia sẻ ảnh màn hình chính theo thời gian thực (tương tự Locket), tích hợp AI thị giác cục bộ (On-Device) tự động nhận diện mép vật thể và gắn sticker/meme tương tác khớp tự nhiên (0 VNĐ Cloud AI).

---

## 🌟 Tính Năng Nổi Bật (Features)
- 📸 **Fast Capture & Live Widget:** Chụp ảnh nhanh và cập nhật trực tiếp lên Widget màn hình chính của bạn bè.
- 🎯 **Contextual Meme Snapping (USP):** Tự động nhận diện mép bánh, viền đĩa, đồ vật nổi bật và gắn sticker meme (ví dụ: meme cắn mép bánh, meme ôm ly nước) với độ trễ < 500ms.
- 🎨 **Interactive Preview:** Cho phép vuốt đổi meme, kéo thả, phóng to thu nhỏ và xoay sticker trước khi gửi.
- ⚡ **Zero Cloud Cost (0 VNĐ):** 100% xử lý hình học và thị giác On-Device (Google ML Kit / On-device Vision).
- 📉 **WebP Compression Engine:** Tối ưu ảnh gửi đi <= 150KB, giúp hoạt động vĩnh viễn trên Firebase Spark Tier miễn phí.
- 📱 **Cross-Platform Widgets:** Hỗ trợ đầy đủ iOS WidgetKit (SwiftUI qua App Groups) và Android Home Widget (`RemoteViews`).

---

## 📚 Hệ Thống Tài Liệu (Documentation)
Toàn bộ tài liệu kỹ thuật chi tiết được lưu trữ tại thư mục [`docs/`](docs/):
* 📖 [Kiến trúc Tổng thể Hệ thống (Architecture)](docs/ARCHITECTURE.md)
* 📐 [Đặc tả Thuật toán Neo Sticker (Anchoring Engine)](docs/ANCHORING_ENGINE.md)
* 📲 [Hướng dẫn Tích hợp Home Screen Widget (iOS & Android)](docs/WIDGET_INTEGRATION.md)
* 📝 [Nhật ký Tiến độ Bắt buộc (Work Log)](docs/WORK_LOG.md)
* 🤖 [Luật & Quy chuẩn cho AI Agent (Agent Rules)](agent.md)

---

## 🚀 Bắt Đầu (Getting Started)
```bash
# Clone repository
git clone https://github.com/YIZ006/ICNative.git
cd ICNative

# Cài đặt dependencies
flutter pub get

# Chạy ứng dụng
flutter run
```

---

## 📄 License
Dự án được phát triển dưới giấy phép [MIT License](LICENSE).
