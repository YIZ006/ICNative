# Đặc Tả Thuật Toán Neo Sticker (Anchoring Math Engine) - ICNative

## 1. Bài Toán Kỹ Thuật
Khi người dùng chụp ảnh một vật thể (ví dụ: đĩa thức ăn, ly nước, chiếc bánh donut), hệ thống cần:
1. Xác định vị trí và đường bao thực tế của vật thể.
2. Tự động chọn sticker meme phù hợp ngữ cảnh (ví dụ: meme cắn bánh, meme ôm ly nước).
3. Đặt sticker sao cho điểm tiếp xúc của meme (hàm răng, bàn tay) tiếp xúc tự nhiên với viền vật thể, xoay theo góc tiếp tuyến của mép.

---

## 2. Mô Hình Dữ Liệu Sticker (Sticker Metadata Schema)

Mỗi meme sticker (PNG trong suốt) được định nghĩa metadata cụ thể:

```dart
enum StickerCategory { food, beverage, pet, general }
enum AnchorPreference { topEdge, rightEdge, hugCenter }

class StickerMetadata {
  final String id;
  final String assetPath;
  final StickerCategory category;
  final AnchorPreference preference;
  
  /// Tọa độ chuẩn hóa (0.0 đến 1.0) của điểm tương tác trên sticker
  /// Ví dụ: hàm răng của meme nằm ở đáy giữa thì bitePoint = Offset(0.5, 0.92)
  final Offset bitePoint;
  
  /// Góc xoay mặc định (radians)
  final double defaultRotation;

  const StickerMetadata({
    required this.id,
    required this.assetPath,
    required this.category,
    required this.preference,
    required this.bitePoint,
    this.defaultRotation = 0.0,
  });
}
```

---

## 3. Quy Trình Tính Toán 3 Bước (3-Step Pipeline)

### Bước 1: Phát hiện Bounding Box & Label (Google ML Kit)
- Mô hình: `google_mlkit_object_detection` (Chạy On-Device, offline 100%).
- Đầu vào: Ảnh chụp từ camera (được scale trước về độ phân giải 720p để giảm latency).
- Đầu ra: Danh sách `DetectedObject` gồm:
  - `boundingBox`: `Rect.fromLTRB(left, top, right, bottom)`
  - `labels`: Danh sách nhãn (vd: `Food`, `Drink`, `Goods`) kèm độ tin cậy (`confidence >= 0.6`).

### Bước 2: Trích Xuất Mép & Điểm Cực Trị Trong Vùng Quan Tâm (ROI)
Lấy vùng ảnh con tương ứng với `boundingBox` để tính toán tọa độ mép chính xác:
1. **Lấy điểm đỉnh cao nhất (Apex Point):**
   $$P_{\text{apex}} = (x_0, y_{\min}) \quad \text{với} \quad y_{\min} = \min_{y} \{ (x, y) \in \text{Object Contour} \}$$
2. **Tính toán Vector Tiếp Tuyến & Pháp Tuyến:**
   Lấy 2 điểm lân cận trên viền mép $P_1 = (x_0 - \Delta x, y_1)$ và $P_2 = (x_0 + \Delta x, y_2)$.
   Vector tiếp tuyến:
   $$\vec{T} = P_2 - P_1 = (dx, dy)$$
   Góc tiếp tuyến $\theta$:
   $$\theta = \arctan2(dy, dx)$$
   Vector pháp tuyến hướng ra ngoài:
   $$\vec{N} = (-dy, dx)$$

### Bước 3: Ánh Xạ Biến Đổi Affine (Affine Transformation)
Để điểm `bitePoint` của Sticker trùng khớp với tọa độ neo $P_{\text{target}}$ trên ảnh:
1. **Tỷ lệ co giãn (Scale):**
   $$\text{Scale}_{\text{sticker}} = \frac{\text{Width}_{\text{boundingBox}} \times 0.45}{\text{Width}_{\text{sticker}}}$$
2. **Tọa độ vị trí Sticker (Position):**
   $$P_{\text{sticker}} = P_{\text{target}} - R(\theta) \cdot (\text{bitePoint} \odot \text{Size}_{\text{scaled}})$$
   Trong đó $R(\theta)$ là ma trận xoay góc $\theta$.

---

## 4. Benchmark Mục Tiêu Hiệu Năng
* **Google ML Kit Inference:** ~35 - 50ms.
* **Extremum & Normal Vector Math:** ~10 - 20ms.
* **Transform Matrix & UI Snap:** < 5ms.
* **👉 Tổng thời gian phản hồi:** **~60 - 75ms** (Rất mượt mà, nhỏ hơn rất nhiều so với ngân sách 500ms).
