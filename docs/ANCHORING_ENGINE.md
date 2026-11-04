# Đặc Tả Thuật Toán Neo Sticker (Anchoring Math Engine) - ICNative

## 1. Bài Toán Kỹ Thuật
Khi người dùng chụp ảnh một vật thể (ví dụ: đĩa thức ăn, ly nước, chiếc bánh donut, thú cưng, laptop), hệ thống cần:
1. Xác định vị trí, vùng bao (`boundingBox`) và đường viền thực tế (`SubjectMask` / contour) của vật thể bằng AI On-Device 100% Offline (0 VNĐ).
2. Tự động chọn sticker meme phù hợp ngữ cảnh (ví dụ: meme cắn bánh, meme ôm ly nước, meme mèo gõ phím, hoặc Capybara chill cho phong cảnh).
3. Đặt sticker sao cho điểm tiếp xúc của meme (`bitePoint`: hàm răng, bàn tay, đáy bụng) tiếp xúc tự nhiên với viền hoặc tâm vật thể, co giãn tỷ lệ hợp lý và xoay theo đúng góc tiếp tuyến $\theta$ của mép vật thể.
4. Đồng bộ 1:1 giữa khung xem trước tương tác (`PreviewScreen`) và ảnh bitmap xuất ra cuối cùng (`_burnStickerAndCaptionToImage`).

---

## 2. Kiến Trúc Mô Hình Dữ Liệu (Data & Geometry Schema)

Hệ thống được tách thành 2 module cốt lõi:
- [`lib/services/anchor_math.dart`](../lib/services/anchor_math.dart): Engine toán học thuần túy (Contour Apex, Theil–Sen Tangent Angle, Outward Normal Vector, `CoverMapping`, `StickerGeometry`, `StickerPlacementSolver`).
- [`lib/services/sticker_anchoring_engine.dart`](../lib/services/sticker_anchoring_engine.dart): Pipeline AI On-Device kết hợp `ObjectDetector`, `ImageLabeler`, và `SubjectSegmenter`.

```dart
enum StickerCategory { food, beverage, pet, person, tech, general, scene }
enum AnchorPreference { topEdge, rightEdge, hugCenter }
enum AnchorMode { edge, hug, scene }

class ObjectAnchor {
  final Size imageSize;
  final Rect bounds;
  final Offset apex;          // P_apex = (x0, y_min) trên viền trên vật thể
  final double tangentAngle;  // θ = atan2(dy, dx) (radians, kẹp trong [-0.61, 0.61])
  final Offset centroid;      // Trọng tâm hình học của mask trong ROI
  final bool fromMask;        // true nếu trích xuất từ SubjectMask pixel-level
}

class StickerMetadata {
  final String id;
  final String assetPath;
  final StickerCategory category;
  final AnchorPreference preference;
  final Offset bitePoint;       // Chuẩn hóa [0..1] trong ảnh gốc của sticker
  final double defaultRotation; // Góc xoay mặc định (radians)
  final Offset? detectedAnchorOffset;
  final ObjectAnchor? anchor;
  final Size? stickerPixelSize; // Kích thước pixel thực của PNG (đọc từ header)
}
```

---

## 3. Quy Trình Tính Toán 3 Bước (3-Step Mathematical Pipeline)

### Bước 1: Phát Hiện Vật Thể, Ngữ Cảnh & Mặt Nạ Chủ Thể (Parallel On-Device Vision)
- Chạy song song 3 mô hình Google ML Kit On-Device (100% Offline, 0 VNĐ):
  1. `ObjectDetector` (Custom Local Model `detect.tflite` / Base Detector): Trích xuất `boundingBox` và phân loại sơ bộ.
  2. `ImageLabeler` (`confidenceThreshold: 0.55`): Lấy nhãn ngữ nghĩa chi tiết (400+ lớp: đồ ăn, thức uống, thú cưng, công nghệ, phong cảnh...).
  3. `SubjectSegmenter` (Android On-Device Segmentation): Trích xuất `foregroundConfidenceMask` và danh sách `Subject` ở mức pixel.
- **Đối sánh IoU (Intersection-over-Union):**
  Hệ thống sử dụng `AnchorMath.bestOverlapIndex` để tìm `Subject` có độ chồng lấn IoU cao nhất với `boundingBox` của vật thể chính, tạo ra mặt nạ nhị phân `BinaryMask` (ngưỡng `threshold = 0.5`).
- **Phân biệt Vật thể vs Phong cảnh:**
  Nếu diện tích vật thể lớn nhất $\frac{\text{Area}_{\text{max}}}{\text{Area}_{\text{image}}} \le 8\%$ và không có nhãn vật thể cận cảnh rõ ràng, hệ thống chuyển sang chế độ **Chụp phong cảnh (`StickerCategory.scene`)**.

---

### Bước 2: Trích Xuất Đỉnh Cực Trị (Contour Apex) & Góc Tiếp Tuyến Bền Vững (Theil–Sen Estimator)
Từ `BinaryMask` trong vùng `roi = boundingBox`:

1. **Lọc nhiễu hàng ngang & Tìm điểm đỉnh cao nhất ($P_{\text{apex}}$):**
   - Mỗi hàng ngang $y \in [\text{top}, \text{bottom})$ phải có tối thiểu `minRowPixels` điểm ảnh thuộc chủ thể để loại bỏ các điểm nhiễu đơn lẻ (salt noise).
   - Tìm $y_{\min}$ đầu tiên thỏa điều kiện và lấy trung vị các cột $x$ tại hàng đó làm $x_0$:
     $$P_{\text{apex}} = (x_0, y_{\min}) \quad \text{với} \quad y_{\min} = \min_{y} \{ (x, y) \in \text{Filtered Object Contour} \}$$

2. **Trích xuất đường viền trên $y_{\text{top}}(x)$ & Lọc vách đứng:**
   - Trong cửa sổ lân cận $[x_0 - \Delta x, x_0 + \Delta x]$ (với $\Delta x = \text{clamp}(0.22 \times W_{\text{ROI}}, 6, 48)$), tìm điểm cao nhất $y_{\text{top}}(x) \ge y_{\min}$ cho mỗi cột $x$.
   - Loại bỏ các bước nhảy vách đứng (vertical side walls của vật thể hình hộp nghiêng) bằng điều kiện đạo hàm cục bộ:
     $$\left| \frac{y_{\text{top}}(x_i) - y_{\text{top}}(x_{i-1})}{x_i - x_{i-1}} \right| \le 1.2$$

3. **Ước lượng Góc Tiếp Tuyến $\theta$ bằng Theil–Sen Median Slope & Pháp Tuyến $\vec{N}$:**
   - Thay vì chỉ lấy 2 điểm đầu mút dễ bị lệch bởi góc hộp, hệ thống tính hệ số góc trung vị (Theil–Sen estimator) trên mọi cặp điểm $(x_i, y_i), (x_j, y_j)$ hợp lệ ở hai phía của $x_0$:
     $$m = \text{median}_{i < j} \left( \frac{y_j - y_i}{x_j - x_i} \right), \qquad \theta = \text{clamp}(\arctan2(m, 1), -0.61\text{ rad}, +0.61\text{ rad})$$
   - Vector tiếp tuyến đơn vị và pháp tuyến hướng ra ngoài (trong hệ tọa độ màn hình $+y$ hướng xuống dưới):
     $$\vec{T} = (\cos\theta, \sin\theta), \qquad \vec{N} = (\sin\theta, -\cos\theta)$$

---

### Bước 3: Ánh Xạ Khung Ngắm (`CoverMapping`) & Giải Bài Toán Đặt Sticker (`StickerPlacementSolver`)

1. **Đồng bộ hệ tọa độ `BoxFit.cover` (`CoverMapping`):**
   Khung preview hiển thị ảnh vuông kích thước $F \times F$ (`photoBoxSize`) với chế độ cắt giữa (`BoxFit.cover`). Mọi điểm $(x_{\text{img}}, y_{\text{img}})$ trên ảnh gốc $(W_{\text{img}}, H_{\text{img}})$ được ánh xạ chính xác sang khung hiển thị qua:
   $$s = \max\left(\frac{F}{W_{\text{img}}}, \frac{F}{H_{\text{img}}}\right), \qquad P_{\text{frame}} = P_{\text{img}} \cdot s - \text{cropOffset}$$

2. **Tỷ lệ co giãn động (`Scale`):**
   - Với `AnchorMode.edge` (`topEdge`, `rightEdge`):
     $$\text{TargetWidth} = \text{clamp}(W_{\text{bbox, frame}} \times 0.45, \; 0.22 F, \; 0.36 F)$$
   - Với `AnchorMode.hug` (`hugCenter`):
     $$\text{TargetWidth} = \text{clamp}(W_{\text{bbox, frame}} \times 0.65, \; 0.22 F, \; 0.36 F)$$
   - Bù trừ tỷ lệ khung hình thực của PNG (`BoxFit.contain` bên trong hộp sticker cơ sở $135\text{ px}$ với `innerPadding = 4.0`):
     $$\text{Scale}_{\text{sticker}} = \frac{\text{TargetWidth} + 2 \times \text{innerPadding} \times \text{ scale}}{135.0 \times \text{widthRatio}_{\text{PNG}}}$$

3. **Giải tọa độ Affine với Tâm Xoay Giữa Widget (`solveByBite`):**
   Trong Flutter, `Transform.rotate(angle: θ)` xoay hộp sticker quanh **tâm hình học** $\vec{C}_{\text{local}} = \left(\frac{S}{2}, \frac{S}{2}\right)$ với $S = 135 \times \text{Scale}_{\text{sticker}}$.
   - Tọa độ cục bộ của `bitePoint` bên trong hộp sticker (đã tính `innerPadding` và letterboxing `BoxFit.contain`):
     $$\vec{B}_{\text{local}} = \text{imageRect.topLeft} + (\text{bite}_x \cdot W_{\text{content}}, \; \text{bite}_y \cdot H_{\text{content}})$$
   - Để sau khi xoay góc $\theta$ quanh tâm $\vec{C}_{\text{local}}$, điểm $\vec{B}_{\text{local}}$ trùng khít hoàn toàn với điểm neo mục tiêu $P_{\text{target}}$ trên viền vật thể, tâm và góc trái-trên của hộp sticker phải thỏa phương trình:
     $$\vec{C}_{\text{world}} = P_{\text{target}} - R(\theta) \cdot (\vec{B}_{\text{local}} - \vec{C}_{\text{local}})$$
     $$\text{TopLeft}_{\text{sticker}} = \vec{C}_{\text{world}} - \vec{C}_{\text{local}}$$
     với ma trận xoay 2D:
     $$R(\theta) = \begin{bmatrix} \cos\theta & -\sin\theta \\ \sin\theta & \cos\theta \end{bmatrix}$$

4. **Chống tràn viền & Fallback góc thông minh (`_cornerFallback`):**
   - Nếu vật thể nằm sát mép trên khung ảnh khiến khoảng trống phía trên đỉnh vật thể không đủ đặt sticker (`topLeft.dy < minCoord`), thuật toán tự động chuyển sang neo góc trên-phải hoặc trên-trái của vật thể.
   - Đáy sticker luôn được giới hạn phía trên vùng thanh ghi chú (`reservedBottom = 65.0`).

---

## 4. Kiểm Chứng Toán Học & Hiệu Năng Thực Tế
- **Kiểm thử tự động (`test/anchor_math_test.dart`):** 28 bài kiểm thử đơn vị và Widget Test kiểm chứng trực tiếp bằng `RenderBox.localToGlobal` của Flutter, sai số vị trí `bitePoint` sau phép xoay `Transform.rotate` đạt $< 10^{-3}\text{ px}$.
- **Đọc kích thước PNG siêu tốc:** Sử dụng `ui.ImageDescriptor.encoded` chỉ đọc header của file asset kèm bộ nhớ đệm (`_stickerSizeCache`), thời gian đọc $< 1\text{ ms}$.
- **Tổng thời gian phản hồi End-to-End:** **~60 - 95ms** trên thiết bị thực tế, hoàn toàn mượt mà và 100% On-Device.
