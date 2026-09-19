# AGENT GUIDELINES & WORKFLOW RULES - ICNative

Tài liệu này quy định các nguyên tắc, tiêu chuẩn kỹ thuật và luật hoạt động bắt buộc cho AI Agent khi tham gia phát triển dự án ICNative.

---

## 🚨 LUẬT BẮT BUỘC: BÁO CÁO TIẾN ĐỘ (MANDATORY WORK REPORTING RULE)

Mọi AI Agent khi làm việc trong dự án này **BẮT BUỘC** phải tuân thủ nghiêm ngặt quy tắc ghi nhận báo cáo vào file `docs/WORK_LOG.md`:

### 1. Thời điểm phải ghi báo cáo
* **Sau khi hoàn thành một tác vụ:** Bất cứ khi nào xong một module, một hàm, một file cấu hình hoặc một yêu cầu từ người dùng.
* **Khi bị đứt đoạn / Hết Token (Token Limit):** Dù công việc chưa hoàn tất nhưng nếu nhận thấy phiên làm việc sắp hết ngữ cảnh/token hoặc gặp sự cố gián đoạn, Agent **bắt buộc phải ghi ngay hiện trạng vào `docs/WORK_LOG.md`** trước khi kết thúc turn.
* **Khi chuyển giao công việc:** Giúp Agent ở lượt tiếp theo hoặc lập trình viên nắm bắt ngay bối cảnh mà không bị mất dấu vết.

### 2. Cấu trúc tiêu chuẩn của một bản báo cáo
Mỗi lần cập nhật báo cáo trong `docs/WORK_LOG.md` phải tuân theo cấu trúc markdown sau:

```markdown
### [YYYY-MM-DD HH:mm:ss] - Tiêu đề tác vụ
* **Thời gian (Timestamp):** YYYY-MM-DD HH:mm:ss (GMT+7)
* **Trạng thái (Status):** [COMPLETED] | [IN PROGRESS] | [INTERRUPTED / TOKEN LIMIT] | [BLOCKED]
* **Người thực hiện (Author):** <Tên Agent / Role> (ví dụ: Antigravity Tech Lead Agent)
* **Tóm tắt công việc (Summary):** Mô tả ngắn gọn mục tiêu và kết quả.
* **Chi tiết thay đổi (Changes Made):**
  - [NEW/MODIFY/DELETE] `path/to/file` - Mô tả cụ thể thay đổi.
* **Hiện trạng & Rào cản (Current State & Blockers):** Nếu bị đứt đoạn, mô tả chính xác điểm đang dừng lại.
* **Bước tiếp theo (Next Steps):** Những việc cần làm tiếp ngay sau đó.
```

---

## 📐 NGUYÊN TẮC KỸ THUẬT DỰ ÁN (PROJECT PRINCIPLES)

1. **Chi phí Server = 0 VNĐ:**
   * Không sử dụng bất kỳ Cloud AI API trả phí nào (OpenAI, Gemini Vision API, Claude Vision...).
   * Toàn bộ xử lý thị giác (nhận diện vật thể, tìm mép, tính góc xoay, dán sticker) phải chạy **100% On-Device** thông qua Google ML Kit / Apple Vision / thuật toán hình học cục bộ.
2. **Ngân sách Thời gian (Latency < 500ms):**
   * Quá trình từ lúc bấm chụp đến khi meme sticker tự động hít vào mép vật thể không được vượt quá 500ms trên điện thoại tầm trung.
3. **Tối ưu Băng thông Firebase Free Tier:**
   * Ảnh tải lên Firebase Storage phục vụ widget PHẢI được nén sang định dạng WebP (chất lượng 80%, kích thước tối đa 720x720 px, dung lượng <= 150KB). Tuyệt đối không upload ảnh camera gốc 4K/12MP.
4. **Đồng bộ Widget Đa nền tảng:**
   * Sử dụng `home_widget`.
   * iOS: Tích hợp App Groups (`group.com.yourcompany.icnative`) và WidgetKit (SwiftUI).
   * Android: Tích hợp `AppWidgetProvider` và `RemoteViews`.
   * Hỗ trợ Background update qua Silent Push Notification (APNs / FCM data-only payload).
