import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Toán neo sticker (Anchoring Math Engine) - xem docs/ANCHORING_ENGINE.md.
///
/// File này CỐ Ý không phụ thuộc ML Kit / plugin nào để unit test được bằng
/// `flutter test`. Engine (sticker_anchoring_engine.dart) lo phần thị giác
/// (Bước 1 + trích mặt nạ), file này lo Bước 2 (apex/tiếp tuyến) và Bước 3
/// (biến đổi affine đưa `bitePoint` của sticker trùng điểm neo).
///
/// Hệ toạ độ: gốc ở góc trên-trái, trục y hướng XUỐNG (giống Flutter/ảnh).
/// Góc dương = xoay theo chiều kim đồng hồ trên màn hình.

/// Chế độ neo. Rút gọn từ `AnchorPreference` của engine.
enum AnchorMode {
  /// Đặt sticker lên đỉnh vật thể, xoay theo tiếp tuyến mép trên.
  topEdge,

  /// Ôm giữa vật thể (ly nước...): bitePoint trùng tâm vật thể.
  hug,

  /// Không có vật thể rõ ràng (chụp phong cảnh): đặt giữa-đáy khung.
  scene,
}

/// Mặt nạ nhị phân (1 = thuộc vật thể) của vùng ROI, hàng trước cột sau.
class BinaryMask {
  BinaryMask(this.width, this.height, this.data)
      : assert(width > 0 && height > 0),
        assert(data.length == width * height);

  /// Chuyển mặt nạ độ tin cậy của ML Kit (0..1) sang nhị phân.
  factory BinaryMask.fromConfidence(
    List<double> confidence,
    int width,
    int height, {
    double threshold = 0.5,
  }) {
    final data = Uint8List(width * height);
    for (var i = 0; i < data.length; i++) {
      data[i] = confidence[i] > threshold ? 1 : 0;
    }
    return BinaryMask(width, height, data);
  }

  final int width;
  final int height;
  final Uint8List data;

  bool at(int x, int y) => data[y * width + x] != 0;
}

/// Kết quả Bước 2 trên mép trên của vật thể (toạ độ cục bộ của mặt nạ).
class TopEdge {
  const TopEdge({required this.apex, required this.angle});

  /// Điểm đỉnh P_apex.
  final Offset apex;

  /// Góc tiếp tuyến θ = atan2(dy, dx), đã kẹp trong ±maxAngle.
  final double angle;

  /// Vector tiếp tuyến đơn vị T.
  Offset get tangent => Offset(math.cos(angle), math.sin(angle));

  /// Pháp tuyến đơn vị hướng RA NGOÀI vật thể.
  ///
  /// Lưu ý dấu: tài liệu gốc ghi N = (-dy, dx), đúng với trục y hướng LÊN.
  /// Trên màn hình y hướng XUỐNG nên pháp tuyến hướng ra ngoài ở mép trên
  /// là (dy, -dx) / |T| = (sinθ, -cosθ). Mép phẳng (θ=0) cho N = (0, -1).
  Offset get outwardNormal => Offset(math.sin(angle), -math.cos(angle));
}

/// Hình học vật thể trong toạ độ ẢNH GỐC (pixel), đầu ra của engine.
class ObjectAnchor {
  const ObjectAnchor({
    required this.imageSize,
    required this.bounds,
    required this.apex,
    required this.tangentAngle,
    required this.centroid,
    required this.fromMask,
  });

  /// Dự phòng khi không có mặt nạ (iOS, hoặc ML Kit không trả mask):
  /// đỉnh = giữa cạnh trên bbox, mép phẳng.
  factory ObjectAnchor.fromBounds(Size imageSize, Rect bounds) {
    return ObjectAnchor(
      imageSize: imageSize,
      bounds: bounds,
      apex: bounds.topCenter,
      tangentAngle: 0,
      centroid: bounds.center,
      fromMask: false,
    );
  }

  final Size imageSize;
  final Rect bounds;
  final Offset apex;
  final double tangentAngle;
  final Offset centroid;
  final bool fromMask;
}

/// Ánh xạ ảnh gốc -> khung preview vuông theo `BoxFit.cover` (cắt giữa).
/// Đây chính là cách `Image.file(fit: BoxFit.cover)` trong preview hiển thị.
class CoverMapping {
  CoverMapping({required this.imageSize, required this.frameSide})
      : scale = frameSide / math.min(imageSize.width, imageSize.height),
        cropOrigin = Offset(
          (imageSize.width - math.min(imageSize.width, imageSize.height)) / 2,
          (imageSize.height - math.min(imageSize.width, imageSize.height)) / 2,
        );

  final Size imageSize;
  final double frameSide;

  /// Số pixel khung trên mỗi pixel ảnh.
  final double scale;

  /// Góc trên-trái của vùng vuông được giữ lại, tính bằng pixel ảnh.
  final Offset cropOrigin;

  Offset toFrame(Offset imagePoint) => Offset(
        (imagePoint.dx - cropOrigin.dx) * scale,
        (imagePoint.dy - cropOrigin.dy) * scale,
      );

  Offset toImage(Offset framePoint) => Offset(
        framePoint.dx / scale + cropOrigin.dx,
        framePoint.dy / scale + cropOrigin.dy,
      );

  Rect rectToFrame(Rect r) =>
      Rect.fromPoints(toFrame(r.topLeft), toFrame(r.bottomRight));
}

/// Hình học sticker dùng CHUNG cho preview và lúc khắc ảnh để hai nơi không
/// bao giờ lệch nhau. Các hằng số khớp đúng widget sticker trong preview.dart.
class StickerGeometry {
  const StickerGeometry({required this.photoBoxSize, required this.scale});

  /// Cạnh ô ảnh preview (ngoài viền). Công thức vị trí cũ dùng giá trị này.
  final double photoBoxSize;
  final double scale;

  static const double baseSize = 135.0;
  static const double innerPadding = 4.0;

  /// Vùng đáy chừa cho ô nhập ghi chú, sticker không được đè lên.
  static const double reservedBottom = 65.0;

  /// Bề dày viền ô ảnh preview.
  static const double frameBorder = 3.5;
  static const double minScale = 0.5;
  static const double maxScale = 2.5;

  /// Cạnh vùng hiển thị ảnh thực tế (đã trừ viền 2 phía).
  static double frameSide(double photoBoxSize) => photoBoxSize - 2 * frameBorder;

  double get size => baseSize * scale;
  double get maxLeft => photoBoxSize - size;
  double get maxTop => photoBoxSize - size - reservedBottom;

  /// `stickerPosition` (0..1) -> góc trên-trái (px, hệ toạ độ Stack).
  /// Giữ nguyên công thức đang chạy trong preview.
  Offset topLeftFor(Offset position) {
    final ml = maxLeft;
    final mt = maxTop;
    final left = (position.dx * (ml > 0 ? ml : 1)).clamp(0.0, ml > 0 ? ml : 0.0);
    final top = (position.dy * (mt > 0 ? mt : 1)).clamp(0.0, mt > 0 ? mt : 0.0);
    return Offset(left.toDouble(), top.toDouble());
  }

  /// Nghịch đảo của [topLeftFor].
  Offset positionFor(Offset topLeft) {
    final ml = maxLeft;
    final mt = maxTop;
    final dx = ml > 0 ? topLeft.dx / ml : 0.0;
    final dy = mt > 0 ? topLeft.dy / mt : 0.0;
    return Offset(dx.clamp(0.0, 1.0).toDouble(), dy.clamp(0.0, 1.0).toDouble());
  }

  /// Vùng ảnh sticker thực sự hiển thị trong ô vuông (toạ độ cục bộ của ô):
  /// padding 4px rồi `BoxFit.contain` căn giữa, đúng như `Image.asset` ở preview.
  Rect imageRectInBox(Size stickerPixelSize) {
    final inner = Rect.fromLTWH(
      innerPadding,
      innerPadding,
      size - 2 * innerPadding,
      size - 2 * innerPadding,
    );
    if (stickerPixelSize.isEmpty) return inner;
    final fitted = applyBoxFit(BoxFit.contain, stickerPixelSize, inner.size);
    return Alignment.center.inscribe(fitted.destination, inner);
  }

  /// Toạ độ cục bộ (trong ô vuông, chưa xoay) của `bitePoint` chuẩn hoá.
  Offset biteLocal(Offset bitePoint, Size stickerPixelSize) {
    final r = imageRectInBox(stickerPixelSize);
    return Offset(r.left + bitePoint.dx * r.width, r.top + bitePoint.dy * r.height);
  }
}

enum PlacementKind { topEdge, hug, scene, corner }

class StickerPlacement {
  const StickerPlacement({
    required this.kind,
    required this.position,
    required this.scale,
    required this.rotation,
  });

  final PlacementKind kind;

  /// Giá trị gán thẳng cho `stickerPosition` của preview.
  final Offset position;
  final double scale;

  /// Radian, gán cho `stickerRotation`.
  final double rotation;
}

class AnchorMath {
  const AnchorMath._();

  /// Bước 2: tìm đỉnh + tiếp tuyến mép trên của mặt nạ.
  ///
  /// - Đỉnh: hàng cao nhất có đủ điểm (bỏ qua điểm nhiễu lẻ loi), x0 = trọng
  ///   tâm các điểm trong dải mỏng ngay dưới hàng đó.
  /// - Tiếp tuyến: đặc tả gốc lấy 2 điểm P1, P2 ở x0 ∓ Δx. Cách đó sai dấu ở
  ///   đỉnh nhọn (hộp nghiêng: một bên là cạnh dựng đứng kéo góc lệch), nên ở
  ///   đây dùng ước lượng Theil–Sen: trung vị độ dốc của mọi cặp điểm trên
  ///   đường viền trong cửa sổ x0 ± [windowFraction]·rộng, sau khi bỏ các cột
  ///   có độ dốc cục bộ > [maxLocalSlope] (sườn dựng đứng, không phải cạnh trên).
  ///   θ = atan(độ dốc), tương đương atan2(dy, dx) với dx > 0.
  /// - Tại đỉnh nhọn (hình nón) tiếp tuyến không xác định; kết quả chỉ là một
  ///   góc nghiêng nhỏ, bị kẹp trong ±[maxAngle] nên không gây hại.
  /// - θ bị kẹp trong ±[maxAngle] để viền nhiễu không làm meme nghiêng quá đà.
  static TopEdge? findTopEdge(
    BinaryMask mask, {
    double windowFraction = 0.2,
    double minRowFraction = 0.02,
    double maxLocalSlope = 1.2,
    double maxAngle = 0.61, // ~35 độ
  }) {
    final w = mask.width;
    final h = mask.height;
    final minPixels = math.max(2, (w * minRowFraction).ceil());

    var yMin = -1;
    for (var y = 0; y < h && yMin < 0; y++) {
      var count = 0;
      for (var x = 0; x < w; x++) {
        if (mask.at(x, y)) count++;
      }
      if (count >= minPixels) yMin = y;
    }
    if (yMin < 0) return null;

    final band = math.max(1, (h * 0.03).ceil());
    var sumX = 0.0;
    var n = 0;
    for (var y = yMin; y < math.min(h, yMin + band); y++) {
      for (var x = 0; x < w; x++) {
        if (mask.at(x, y)) {
          sumX += x;
          n++;
        }
      }
    }
    final x0 = (sumX / n).round().clamp(0, w - 1);

    // Đường viền trên, quét từ yMin để điểm nhiễu phía trên không lọt vào.
    int topAt(int x) {
      for (var y = yMin; y < h; y++) {
        if (mask.at(x, y)) return y;
      }
      return -1;
    }

    final halfWindow = math.max(4, (w * windowFraction).round());
    final xs = <int>[];
    final ys = <int>[];
    for (var x = math.max(0, x0 - halfWindow); x <= math.min(w - 1, x0 + halfWindow); x++) {
      final y = topAt(x);
      if (y >= 0) {
        xs.add(x);
        ys.add(y);
      }
    }

    // Loại các cột thuộc sườn dốc đứng (cạnh dựng đứng của hộp nghiêng...):
    // chúng không phải "cạnh trên" và nếu để lại sẽ kéo trung vị lệch đi
    // (Theil–Sen chỉ chịu được ~29% điểm ngoại lai).
    final contour = <Offset>[];
    for (var i = 0; i < xs.length; i++) {
      final hasPrev = i > 0 && xs[i - 1] == xs[i] - 1;
      final hasNext = i < xs.length - 1 && xs[i + 1] == xs[i] + 1;
      final localSlope = (hasPrev && hasNext)
          ? (ys[i + 1] - ys[i - 1]) / 2
          : hasNext
              ? (ys[i + 1] - ys[i]).toDouble()
              : hasPrev
                  ? (ys[i] - ys[i - 1]).toDouble()
                  : 0.0;
      if (localSlope.abs() <= maxLocalSlope) {
        contour.add(Offset(xs[i].toDouble(), ys[i].toDouble()));
      }
    }

    var angle = 0.0;
    if (contour.length >= 3) {
      // Giới hạn ~48 điểm để số cặp luôn nhỏ (≈1100) bất kể độ phân giải.
      final step = math.max(1, (contour.length / 48).ceil());
      final pts = <Offset>[for (var i = 0; i < contour.length; i += step) contour[i]];
      final slopes = <double>[];
      for (var i = 0; i < pts.length; i++) {
        for (var j = i + 1; j < pts.length; j++) {
          final dx = pts[j].dx - pts[i].dx;
          if (dx.abs() >= 1) slopes.add((pts[j].dy - pts[i].dy) / dx);
        }
      }
      if (slopes.length >= 3) {
        slopes.sort();
        final mid = slopes.length ~/ 2;
        final median = slopes.length.isOdd ? slopes[mid] : (slopes[mid - 1] + slopes[mid]) / 2;
        angle = math.atan(median);
      }
    }

    final apexY = topAt(x0);
    return TopEdge(
      apex: Offset(x0.toDouble(), (apexY >= 0 ? apexY : yMin).toDouble()),
      angle: angle.clamp(-maxAngle, maxAngle).toDouble(),
    );
  }

  /// Trọng tâm mặt nạ (dùng cho chế độ ôm giữa).
  static Offset? centroid(BinaryMask mask) {
    var sx = 0.0;
    var sy = 0.0;
    var n = 0;
    for (var y = 0; y < mask.height; y++) {
      for (var x = 0; x < mask.width; x++) {
        if (mask.at(x, y)) {
          sx += x;
          sy += y;
          n++;
        }
      }
    }
    if (n == 0) return null;
    return Offset(sx / n, sy / n);
  }

  static double iou(Rect a, Rect b) {
    final inter = a.intersect(b);
    if (inter.width <= 0 || inter.height <= 0) return 0;
    final interArea = inter.width * inter.height;
    final union = a.width * a.height + b.width * b.height - interArea;
    return union <= 0 ? 0 : interArea / union;
  }

  /// Chọn mặt nạ thuộc CÙNG vật thể với bbox của detector (IoU lớn nhất).
  /// Trả -1 nếu không cái nào đạt [minIou].
  static int bestOverlapIndex(Rect target, List<Rect> candidates, {double minIou = 0.3}) {
    var best = -1;
    var bestScore = minIou;
    for (var i = 0; i < candidates.length; i++) {
      final score = iou(target, candidates[i]);
      if (score >= bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  /// Dựng [ObjectAnchor] từ mặt nạ của vật thể có khung [bounds] (toạ độ ảnh).
  /// Mặt nạ rỗng thì quay về [ObjectAnchor.fromBounds].
  static ObjectAnchor anchorFromMask({
    required Size imageSize,
    required Rect bounds,
    required BinaryMask mask,
  }) {
    final edge = findTopEdge(mask);
    final c = centroid(mask);
    if (edge == null || c == null) return ObjectAnchor.fromBounds(imageSize, bounds);
    return ObjectAnchor(
      imageSize: imageSize,
      bounds: bounds,
      apex: bounds.topLeft + edge.apex,
      tangentAngle: edge.angle,
      centroid: bounds.topLeft + c,
      fromMask: true,
    );
  }
}

/// Bước 3: đổi điểm neo + góc tiếp tuyến thành vị trí/scale/góc xoay của sticker
/// theo đúng mô hình hiển thị của preview.
class StickerPlacementSolver {
  const StickerPlacementSolver._();

  /// Sticker hiển thị rộng bao nhiêu so với vật thể (bbox trong khung).
  static const double edgeWidthFactor = 0.45;
  static const double hugWidthFactor = 0.65;
  static const double minDisplayFraction = 0.22;
  static const double maxDisplayFraction = 0.36;

  static StickerPlacement solve({
    required AnchorMode mode,
    required ObjectAnchor? anchor,
    required Offset bitePoint,
    required Size stickerPixelSize,
    required double photoBoxSize,
  }) {
    final side = StickerGeometry.frameSide(photoBoxSize);

    CoverMapping? mapping;
    Rect? visible;
    if (anchor != null && mode != AnchorMode.scene) {
      mapping = CoverMapping(imageSize: anchor.imageSize, frameSide: side);
      final v = mapping
          .rectToFrame(anchor.bounds)
          .intersect(Rect.fromLTWH(0, 0, side, side));
      if (v.width > 1 && v.height > 1) visible = v;
    }

    // Không có vật thể nhìn thấy được trong khung -> cảnh: giữa-đáy.
    if (mapping == null || visible == null || anchor == null) {
      final scale = scaleForDisplayWidth(side * 0.30, stickerPixelSize);
      final geo = StickerGeometry(photoBoxSize: photoBoxSize, scale: scale);
      final target = Offset(side / 2, side - StickerGeometry.reservedBottom - 2);
      final topLeft = solveByBite(
        geometry: geo,
        target: target,
        angle: 0,
        bitePoint: bitePoint,
        stickerPixelSize: stickerPixelSize,
      );
      return StickerPlacement(
        kind: PlacementKind.scene,
        position: geo.positionFor(topLeft),
        scale: scale,
        rotation: 0,
      );
    }

    final factor = mode == AnchorMode.hug ? hugWidthFactor : edgeWidthFactor;
    final displayWidth = (visible.width * factor)
        .clamp(side * minDisplayFraction, side * maxDisplayFraction)
        .toDouble();
    final scale = scaleForDisplayWidth(displayWidth, stickerPixelSize);
    final geo = StickerGeometry(photoBoxSize: photoBoxSize, scale: scale);

    Offset clampToFrame(Offset p) => Offset(
          p.dx.clamp(0.0, side).toDouble(),
          p.dy.clamp(0.0, side).toDouble(),
        );

    if (mode == AnchorMode.hug) {
      final topLeft = solveByBite(
        geometry: geo,
        target: clampToFrame(mapping.toFrame(anchor.centroid)),
        angle: 0,
        bitePoint: bitePoint,
        stickerPixelSize: stickerPixelSize,
      );
      return StickerPlacement(
        kind: PlacementKind.hug,
        position: geo.positionFor(topLeft),
        scale: scale,
        rotation: 0,
      );
    }

    // topEdge: kiểm tra còn chỗ phía trên đỉnh cho phần sticker nhô lên.
    final apex = mapping.toFrame(anchor.apex);
    final imageRect = geo.imageRectInBox(stickerPixelSize);
    final aboveContact = bitePoint.dy * imageRect.height;
    final hasHeadroom = apex.dy - aboveContact >= -0.1 * imageRect.height;

    if (hasHeadroom) {
      final topLeft = solveByBite(
        geometry: geo,
        target: clampToFrame(apex),
        angle: anchor.tangentAngle,
        bitePoint: bitePoint,
        stickerPixelSize: stickerPixelSize,
      );
      return StickerPlacement(
        kind: PlacementKind.topEdge,
        position: geo.positionFor(topLeft),
        scale: scale,
        rotation: anchor.tangentAngle,
      );
    }

    return _cornerFallback(
      geometry: geo,
      visible: visible,
      side: side,
      scale: scale,
    );
  }

  /// Công thức lõi Bước 3, cho trục xoay Ở TÂM ô sticker (đúng với
  /// `Transform.rotate` của Flutter): trả về góc trên-trái của ô để điểm
  /// `bitePoint` rơi đúng [target] sau khi xoay [angle].
  ///
  /// Bản gốc ghi P = P_target − R(θ)·(bite ⊙ Size) là cho trục xoay ở góc
  /// trên-trái. Với trục ở tâm: tâm = P_target − R(θ)·(bite_local − tâm_ô).
  static Offset solveByBite({
    required StickerGeometry geometry,
    required Offset target,
    required double angle,
    required Offset bitePoint,
    required Size stickerPixelSize,
  }) {
    final half = geometry.size / 2;
    final bite = geometry.biteLocal(bitePoint, stickerPixelSize);
    final rx = bite.dx - half;
    final ry = bite.dy - half;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    final rotated = Offset(rx * cosA - ry * sinA, rx * sinA + ry * cosA);
    final center = target - rotated;
    return Offset(center.dx - half, center.dy - half);
  }

  /// scale (hệ số của `StickerGeometry.baseSize`) để phần ảnh sticker hiển
  /// thị rộng [displayWidth] px, đã kẹp trong [minScale, maxScale].
  static double scaleForDisplayWidth(double displayWidth, Size stickerPixelSize) {
    if (stickerPixelSize.isEmpty) return 1.0;
    final aspect = stickerPixelSize.width / stickerPixelSize.height;
    final inner = displayWidth / math.min(1.0, aspect);
    final size = inner + 2 * StickerGeometry.innerPadding;
    return (size / StickerGeometry.baseSize)
        .clamp(StickerGeometry.minScale, StickerGeometry.maxScale)
        .toDouble();
  }

  /// Hết chỗ phía trên (vật thể sát mép trên khung): đặt vào góc khung còn
  /// nhiều khoảng trống nhất, giống cách chấm điểm góc của bản cũ.
  static StickerPlacement _cornerFallback({
    required StickerGeometry geometry,
    required Rect visible,
    required double side,
    required double scale,
  }) {
    final spaceTop = math.max(0.0, visible.top);
    final spaceBottom = math.max(0.0, side - visible.bottom);
    final spaceLeft = math.max(0.0, visible.left);
    final spaceRight = math.max(0.0, side - visible.right);

    final scores = <String, double>{
      'topRight': spaceTop + spaceRight,
      'topLeft': spaceTop + spaceLeft,
      'bottomRight': spaceBottom + spaceRight,
      'bottomLeft': spaceBottom + spaceLeft,
    };
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final margin = side * 0.04;
    final maxLeft = math.max(0.0, geometry.maxLeft);
    final maxTop = math.max(0.0, geometry.maxTop);
    final left = best.endsWith('Right') ? maxLeft - margin : margin;
    final top = best.startsWith('bottom') ? maxTop - margin : margin;

    return StickerPlacement(
      kind: PlacementKind.corner,
      position: geometry.positionFor(Offset(
        left.clamp(0.0, maxLeft).toDouble(),
        top.clamp(0.0, maxTop).toDouble(),
      )),
      scale: scale,
      rotation: 0.04,
    );
  }
}
