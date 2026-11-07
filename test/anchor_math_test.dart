import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icnative/services/anchor_math.dart';
import 'package:icnative/services/sticker_anchoring_engine.dart';

/// Dựng mặt nạ từ cột -> y cao nhất của vật thể (phần dưới đó đều đặc).
BinaryMask maskFromTopProfile(List<int?> topY, int height) {
  final width = topY.length;
  final data = Uint8List(width * height);
  for (var x = 0; x < width; x++) {
    final top = topY[x];
    if (top == null) continue;
    for (var y = top; y < height; y++) {
      data[y * width + x] = 1;
    }
  }
  return BinaryMask(width, height, data);
}

/// Rasterize hình chữ nhật (hoặc elip nếu [round]) xoay [phi] rad quanh (cx, cy).
BinaryMask maskFromRotatedRect({
  required int w,
  required int h,
  required double cx,
  required double cy,
  required double hw,
  required double hh,
  required double phi,
  bool round = false,
}) {
  final data = Uint8List(w * h);
  final c = math.cos(phi);
  final s = math.sin(phi);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Đưa điểm về hệ của hình đã xoay ngược lại.
      final dx = x - cx;
      final dy = y - cy;
      final lx = dx * c + dy * s;
      final ly = -dx * s + dy * c;
      final inside = round
          ? (lx * lx) / (hw * hw) + (ly * ly) / (hh * hh) <= 1
          : lx.abs() <= hw && ly.abs() <= hh;
      if (inside) data[y * w + x] = 1;
    }
  }
  return BinaryMask(w, h, data);
}

BinaryMask mirror(BinaryMask m) {
  final data = Uint8List(m.data.length);
  for (var y = 0; y < m.height; y++) {
    for (var x = 0; x < m.width; x++) {
      data[y * m.width + (m.width - 1 - x)] = m.data[y * m.width + x];
    }
  }
  return BinaryMask(m.width, m.height, data);
}

void main() {
  group('Bước 2 - findTopEdge', () {
    test('mép trên phẳng: đỉnh ở giữa, θ = 0, pháp tuyến hướng lên', () {
      final mask = maskFromTopProfile(List<int?>.filled(20, 2), 10);
      final edge = AnchorMath.findTopEdge(mask)!;

      expect(edge.apex.dy, 2);
      expect(edge.apex.dx, closeTo(9.5, 1));
      expect(edge.angle, 0);
      expect(edge.outwardNormal.dx, closeTo(0, 1e-9));
      expect(edge.outwardNormal.dy, closeTo(-1, 1e-9));
    });

    test('mặt nạ rỗng -> null', () {
      final mask = BinaryMask(10, 10, Uint8List(100));
      expect(AnchorMath.findTopEdge(mask), isNull);
    });

    test('bỏ qua điểm nhiễu lẻ loi phía trên vật thể', () {
      final profile = List<int?>.filled(40, 5);
      final mask = maskFromTopProfile(profile, 20);
      mask.data[0 * 40 + 20] = 1; // 1 pixel nhiễu ở hàng 0

      final edge = AnchorMath.findTopEdge(mask)!;
      expect(edge.apex.dy, 5);
    });

    test('dốc đi xuống về bên phải -> θ dương (xoay thuận chiều kim đồng hồ)', () {
      // y = 10 + x/2: đỉnh ở mép trái, mép xuống dần sang phải.
      final profile = List<int?>.generate(40, (x) => 10 + (x * 0.5).round());
      final edge = AnchorMath.findTopEdge(maskFromTopProfile(profile, 50))!;

      expect(edge.angle, closeTo(math.atan(0.5), 0.12));
    });

    test('đỉnh nhọn bất đối xứng (tiếp tuyến không xác định): chỉ nghiêng nhẹ, không văng', () {
      // Sườn trái dốc đứng, sườn phải thoải, đỉnh ở x = 30.
      final profile = List<int?>.generate(60, (x) {
        return x <= 30 ? 10 + (30 - x) : 10 + ((x - 30) * 0.2).round();
      });
      final mask = maskFromTopProfile(profile, 50);

      expect(AnchorMath.findTopEdge(mask)!.angle.abs(), lessThan(0.35));
      expect(AnchorMath.findTopEdge(mirror(mask))!.angle.abs(), lessThan(0.35));
    });

    test('hộp nghiêng 0.3 rad (laptop/hộp): θ bám theo cạnh trên, đúng dấu', () {
      // Cạnh trên hạ dần về bên phải -> xoay thuận chiều kim đồng hồ (θ > 0).
      // Đây là ca đặc tả gốc (2 điểm đối xứng) dễ sai dấu vì cạnh trái dựng đứng.
      final clockwise = maskFromRotatedRect(w: 160, h: 140, cx: 80, cy: 70, hw: 50, hh: 28, phi: 0.3);
      expect(AnchorMath.findTopEdge(clockwise)!.angle, closeTo(0.3, 0.09));

      final counter = maskFromRotatedRect(w: 160, h: 140, cx: 80, cy: 70, hw: 50, hh: 28, phi: -0.3);
      expect(AnchorMath.findTopEdge(counter)!.angle, closeTo(-0.3, 0.09));
    });

    test('hình tròn/đồi đối xứng: tiếp tuyến tại đỉnh nằm ngang (θ ≈ 0)', () {
      final circle = maskFromRotatedRect(w: 100, h: 100, cx: 50, cy: 50, hw: 30, hh: 30, phi: 0, round: true);
      final edge = AnchorMath.findTopEdge(circle)!;
      expect(edge.angle.abs(), lessThan(0.06));
      expect(edge.apex.dx, closeTo(50, 2));
      expect(edge.apex.dy, closeTo(20, 1.5));
    });

    test('mép quá dốc bị kẹp ở ±maxAngle', () {
      final profile = List<int?>.generate(40, (x) => 5 + x);
      final edge = AnchorMath.findTopEdge(maskFromTopProfile(profile, 60), maxAngle: 0.4)!;
      expect(edge.angle, closeTo(0.4, 1e-9));
    });

    test('pháp tuyến luôn vuông góc với tiếp tuyến', () {
      final profile = List<int?>.generate(40, (x) => 10 + (x * 0.5).round());
      final edge = AnchorMath.findTopEdge(maskFromTopProfile(profile, 50))!;
      final dot = edge.tangent.dx * edge.outwardNormal.dx + edge.tangent.dy * edge.outwardNormal.dy;
      expect(dot, closeTo(0, 1e-9));
    });
  });

  group('tiện ích mặt nạ', () {
    test('centroid của khối chữ nhật', () {
      final data = Uint8List(10 * 10);
      for (var y = 2; y < 6; y++) {
        for (var x = 4; x < 8; x++) {
          data[y * 10 + x] = 1;
        }
      }
      final c = AnchorMath.centroid(BinaryMask(10, 10, data))!;
      expect(c.dx, closeTo(5.5, 1e-9));
      expect(c.dy, closeTo(3.5, 1e-9));
    });

    test('fromConfidence dùng ngưỡng 0.5', () {
      final m = BinaryMask.fromConfidence([0.9, 0.5, 0.51, 0.1], 2, 2);
      expect(m.data, [1, 0, 1, 0]);
    });

    test('bestOverlapIndex chọn mặt nạ cùng vật thể, từ chối khi lệch quá', () {
      const target = Rect.fromLTWH(100, 100, 200, 200);
      final idx = AnchorMath.bestOverlapIndex(target, const [
        Rect.fromLTWH(0, 0, 50, 50),
        Rect.fromLTWH(110, 105, 190, 195),
      ]);
      expect(idx, 1);
      expect(AnchorMath.bestOverlapIndex(target, const [Rect.fromLTWH(0, 0, 50, 50)]), -1);
    });

    test('anchorFromMask đổi toạ độ cục bộ sang toạ độ ảnh', () {
      final mask = maskFromTopProfile(List<int?>.filled(20, 3), 10);
      final anchor = AnchorMath.anchorFromMask(
        imageSize: const Size(640, 480),
        bounds: const Rect.fromLTWH(100, 200, 20, 10),
        mask: mask,
      );
      expect(anchor.fromMask, isTrue);
      expect(anchor.apex.dy, 203);
      expect(anchor.apex.dx, closeTo(109.5, 1.1));
    });

    test('anchorFromMask với mặt nạ rỗng quay về bbox', () {
      final anchor = AnchorMath.anchorFromMask(
        imageSize: const Size(640, 480),
        bounds: const Rect.fromLTWH(100, 200, 20, 10),
        mask: BinaryMask(5, 5, Uint8List(25)),
      );
      expect(anchor.fromMask, isFalse);
      expect(anchor.apex, const Offset(110, 200));
      expect(anchor.tangentAngle, 0);
    });
  });

  group('CoverMapping (BoxFit.cover vuông, cắt giữa)', () {
    test('ảnh dọc 480x640 vào khung 353', () {
      final m = CoverMapping(imageSize: const Size(480, 640), frameSide: 353);
      expect(m.toFrame(const Offset(0, 80)), const Offset(0, 0));
      expect(m.toFrame(const Offset(480, 560)).dx, closeTo(353, 1e-9));
      expect(m.toFrame(const Offset(480, 560)).dy, closeTo(353, 1e-9));
      expect(m.toFrame(const Offset(240, 320)).dx, closeTo(176.5, 1e-9));
      expect(m.toFrame(const Offset(240, 320)).dy, closeTo(176.5, 1e-9));
    });

    test('toImage là nghịch đảo của toFrame', () {
      final m = CoverMapping(imageSize: const Size(800, 600), frameSide: 300);
      const p = Offset(123, 456);
      final back = m.toImage(m.toFrame(p));
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    });
  });

  group('StickerGeometry', () {
    test('positionFor là nghịch đảo của topLeftFor', () {
      const geo = StickerGeometry(photoBoxSize: 360, scale: 0.9);
      const p = Offset(0.3, 0.6);
      final back = geo.positionFor(geo.topLeftFor(p));
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    });

    test('topLeftFor luôn chừa vùng đáy cho ô ghi chú', () {
      const geo = StickerGeometry(photoBoxSize: 360, scale: 1.0);
      final tl = geo.topLeftFor(const Offset(1, 1));
      expect(tl.dy + geo.size, lessThanOrEqualTo(360 - StickerGeometry.reservedBottom + 1e-9));
    });

    test('ảnh ngang được căn giữa theo chiều dọc trong ô', () {
      const geo = StickerGeometry(photoBoxSize: 360, scale: 1.0);
      final r = geo.imageRectInBox(const Size(400, 200));
      expect(r.width, closeTo(135 - 8, 1e-9));
      expect(r.height, closeTo((135 - 8) / 2, 1e-9));
      expect(r.center.dx, closeTo(135 / 2, 1e-9));
      expect(r.center.dy, closeTo(135 / 2, 1e-9));
    });
  });

  group('Bước 3 - solver', () {
    const photoBox = 360.0;
    final side = StickerGeometry.frameSide(photoBox);

    test('mép phẳng giữa khung: sticker ngồi chính giữa phía trên đỉnh', () {
      // Vật thể 200px rộng, đỉnh ở (240, 300) trong ảnh vuông 480.
      const anchor = ObjectAnchor(
        imageSize: Size(480, 480),
        bounds: Rect.fromLTWH(140, 300, 200, 150),
        apex: Offset(240, 300),
        tangentAngle: 0,
        centroid: Offset(240, 375),
        fromMask: true,
      );
      final p = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: anchor,
        bitePoint: const Offset(0.5, 0.85),
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: photoBox,
      );

      expect(p.kind, PlacementKind.topEdge);
      expect(p.rotation, 0);

      final geo = StickerGeometry(photoBoxSize: photoBox, scale: p.scale);
      final tl = geo.topLeftFor(p.position);
      final bite = tl + geo.biteLocal(const Offset(0.5, 0.85), const Size(512, 512));
      final target = CoverMapping(imageSize: anchor.imageSize, frameSide: side).toFrame(anchor.apex);
      expect(bite.dx, closeTo(target.dx, 1.0));
      expect(bite.dy, closeTo(target.dy, 1.0));
    });

    test('sticker rộng ≈ 45% vật thể nhưng bị kẹp trong [22%, 36%] khung', () {
      final small = StickerPlacementSolver.scaleForDisplayWidth(side * 0.05, const Size(500, 500));
      final big = StickerPlacementSolver.scaleForDisplayWidth(side * 5, const Size(500, 500));
      expect(small, StickerGeometry.minScale);
      expect(big, StickerGeometry.maxScale);

      final anchor = ObjectAnchor.fromBounds(const Size(480, 480), const Rect.fromLTWH(10, 200, 20, 20));
      final p = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: anchor,
        bitePoint: const Offset(0.5, 0.85),
        stickerPixelSize: const Size(500, 500),
        photoBoxSize: photoBox,
      );
      final displayed = (StickerGeometry.baseSize * p.scale - 8);
      expect(displayed, closeTo(side * StickerPlacementSolver.minDisplayFraction, 1.0));
    });

    test('vật thể sát mép trên -> hết chỗ -> rơi vào góc khung', () {
      final anchor = ObjectAnchor.fromBounds(const Size(480, 480), const Rect.fromLTWH(60, 0, 200, 300));
      final p = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: anchor,
        bitePoint: const Offset(0.5, 0.85),
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: photoBox,
      );
      expect(p.kind, PlacementKind.corner);
      // Vật thể lệch trái -> góc trống nhiều nhất là bên phải.
      expect(p.position.dx, greaterThan(0.8));
    });

    test('không có vật thể (hoặc anchor ngoài khung) -> cảnh, giữa-đáy', () {
      final p = StickerPlacementSolver.solve(
        mode: AnchorMode.scene,
        anchor: null,
        bitePoint: const Offset(0.5, 1.0),
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: photoBox,
      );
      expect(p.kind, PlacementKind.scene);
      expect(p.position.dx, closeTo(0.5, 0.03));
      expect(p.rotation, 0);

      // Vật thể nằm hoàn toàn trong phần bị cắt của ảnh dọc -> cũng là cảnh.
      final cropped = ObjectAnchor.fromBounds(const Size(480, 640), const Rect.fromLTWH(100, 0, 200, 60));
      final q = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: cropped,
        bitePoint: const Offset(0.5, 0.85),
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: photoBox,
      );
      expect(q.kind, PlacementKind.scene);
    });

    test('ôm giữa: tâm sticker trùng trọng tâm vật thể', () {
      const anchor = ObjectAnchor(
        imageSize: Size(480, 480),
        bounds: Rect.fromLTWH(160, 200, 160, 200),
        apex: Offset(240, 200),
        tangentAngle: 0,
        centroid: Offset(240, 300),
        fromMask: true,
      );
      final p = StickerPlacementSolver.solve(
        mode: AnchorMode.hug,
        anchor: anchor,
        bitePoint: const Offset(0.5, 0.5),
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: photoBox,
      );
      expect(p.kind, PlacementKind.hug);
      final geo = StickerGeometry(photoBoxSize: photoBox, scale: p.scale);
      final center = geo.topLeftFor(p.position) + Offset(geo.size / 2, geo.size / 2);
      final target = CoverMapping(imageSize: anchor.imageSize, frameSide: side).toFrame(anchor.centroid);
      expect(center.dx, closeTo(target.dx, 1.0));
      expect(center.dy, closeTo(target.dy, 1.0));
    });
  });

  group('Bước 3 - khớp với Transform.rotate thật của Flutter', () {
    // Dựng đúng cấu trúc widget sticker trong preview (Positioned > Transform.rotate
    // > ô vuông) rồi hỏi RenderBox.localToGlobal xem bitePoint có rơi đúng đích.
    final cases = <({double angle, Offset bite, Size px, double scale})>[
      (angle: 0.0, bite: const Offset(0.5, 0.85), px: const Size(512, 512), scale: 0.9),
      (angle: 0.4, bite: const Offset(0.5, 0.85), px: const Size(400, 600), scale: 0.8),
      (angle: -0.5, bite: const Offset(0.3, 0.9), px: const Size(700, 300), scale: 1.2),
      (angle: 0.61, bite: const Offset(0.5, 0.5), px: const Size(512, 512), scale: 1.0),
    ];

    for (final c in cases) {
      testWidgets('angle=${c.angle} bite=${c.bite} px=${c.px}', (tester) async {
        const target = Offset(170, 160);
        final geo = StickerGeometry(photoBoxSize: 360, scale: c.scale);
        final topLeft = StickerPlacementSolver.solveByBite(
          geometry: geo,
          target: target,
          angle: c.angle,
          bitePoint: c.bite,
          stickerPixelSize: c.px,
        );

        final boxKey = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 353,
                height: 353,
                child: Stack(
                  children: [
                    Positioned(
                      left: topLeft.dx,
                      top: topLeft.dy,
                      child: Transform.rotate(
                        angle: c.angle,
                        child: SizedBox(key: boxKey, width: geo.size, height: geo.size),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final box = tester.renderObject<RenderBox>(find.byKey(boxKey));
        final onScreen = box.localToGlobal(geo.biteLocal(c.bite, c.px));
        expect(onScreen, offsetMoreOrLessEquals(target, epsilon: 1e-3));
      });
    }
  });

  group('Bite Snapping - rotateMask & findEdge', () {
    test('mặt nạ hình chữ nhật: apex đúng cạnh, pháp tuyến hướng ra ngoài, sai số góc < 0.05', () {
      const w = 90;
      const h = 110;
      final data = Uint8List(w * h);
      for (var y = 20; y <= 80; y++) {
        for (var x = 15; x <= 64; x++) {
          data[y * w + x] = 1;
        }
      }
      final mask = BinaryMask(w, h, data);

      final top = AnchorMath.findEdge(mask, EdgeSide.top)!;
      expect(top.apex.dy, closeTo(20, 1.0));
      expect(top.apex.dx, closeTo(39.5, 1.5));
      expect(top.angle, closeTo(0.0, 0.05));
      expect(top.outwardNormal.dx, closeTo(0.0, 0.05));
      expect(top.outwardNormal.dy, closeTo(-1.0, 0.05));

      final right = AnchorMath.findEdge(mask, EdgeSide.right)!;
      expect(right.apex.dx, closeTo(64, 1.0));
      expect(right.apex.dy, closeTo(50, 1.5));
      expect(right.angle, closeTo(math.pi / 2, 0.05));
      expect(right.outwardNormal.dx, closeTo(1.0, 0.05));
      expect(right.outwardNormal.dy, closeTo(0.0, 0.05));

      final left = AnchorMath.findEdge(mask, EdgeSide.left)!;
      expect(left.apex.dx, closeTo(15, 1.0));
      expect(left.apex.dy, closeTo(50, 1.5));
      expect(left.angle, closeTo(-math.pi / 2, 0.05));
      expect(left.outwardNormal.dx, closeTo(-1.0, 0.05));
      expect(left.outwardNormal.dy, closeTo(0.0, 0.05));
    });

    test('mặt nạ hình thang nghiêng: tiếp tuyến & pháp tuyến hai cạnh bên chính xác (< 0.05 rad)', () {
      const w = 140;
      const h = 140;
      final data = Uint8List(w * h);
      // Cạnh phải nghiêng: xRight(y) = 115 - 0.25*y; cạnh trái nghiêng: xLeft(y) = 25 + 0.20*y
      for (var y = 0; y < h; y++) {
        final xLeft = (25 + 0.20 * y).round();
        final xRight = (115 - 0.25 * y).round();
        for (var x = xLeft; x <= xRight; x++) {
          data[y * w + x] = 1;
        }
      }
      final mask = BinaryMask(w, h, data);

      final right = AnchorMath.findEdge(mask, EdgeSide.right)!;
      final expectedRightAngle = math.pi / 2 + math.atan(0.25);
      expect(right.angle, closeTo(expectedRightAngle, 0.05));
      expect(right.apex.dx, closeTo(115, 2.0));
      // Pháp tuyến hướng sang phải và hơi chếch xuống (ra ngoài hình thang thu đáy)
      expect(right.outwardNormal.dx, greaterThan(0.9));
      expect(right.outwardNormal.dy, greaterThan(0.18));

      final left = AnchorMath.findEdge(mask, EdgeSide.left)!;
      final expectedLeftAngle = -math.pi / 2 - math.atan(0.20);
      expect(left.angle, closeTo(expectedLeftAngle, 0.05));
      expect(left.apex.dx, closeTo(25, 2.0));
      // Pháp tuyến hướng sang trái và hơi chếch xuống
      expect(left.outwardNormal.dx, lessThan(-0.9));
      expect(left.outwardNormal.dy, greaterThan(0.14));
    });
  });

  group('Bite Snapping - BiteMeta & chọn cạnh cắn (top -> right -> left)', () {
    test('BiteMeta đọc JSON và trả fallback khi không khai báo', () {
      final map = BiteMeta.parseJsonMap({
        'bite_hachi_01.png': {
          'bite': [0.50, 0.82],
          'dir': [0.0, 2.0],
          'width': 0.40,
        },
      });
      final found = BiteMeta.lookup(map, 'assets/memes/bite/bite_hachi_01.png');
      expect(found.bite, const Offset(0.50, 0.82));
      expect(found.dir.dx, closeTo(0.0, 1e-9));
      expect(found.dir.dy, closeTo(1.0, 1e-9));
      expect(found.width, closeTo(0.40, 1e-9));

      final fallback = BiteMeta.lookup(map, 'assets/memes/meme_cat_01.png');
      expect(fallback.bite, BiteMeta.defaultBite);
      expect(fallback.dir, BiteMeta.defaultDir);
      expect(fallback.width, BiteMeta.defaultWidth);
    });

    test('hết chỗ mép trên -> tự chuyển sang cắn mép phải; hết cả phải -> cắn mép trái', () {
      const w = 160;
      const h = 220;
      final solid = BinaryMask(w, h, Uint8List(w * h)..fillRange(0, w * h, 1));

      // 1. Vật thể sát mép trên, nằm lệch trái -> mép trên hết chỗ, mép phải đủ chỗ
      final anchorRightRoom = AnchorMath.anchorFromMask(
        imageSize: const Size(480, 480),
        bounds: const Rect.fromLTWH(60, 0, 160, 220),
        mask: solid,
      );
      final pRight = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: anchorRightRoom,
        bitePoint: const Offset(0.5, 0.82),
        biteDirection: const Offset(0, 1),
        widthFactor: 0.40,
        biteDepthFraction: StickerPlacementSolver.defaultBiteDepthFraction,
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: 360,
      );
      expect(pRight.kind, PlacementKind.sideEdge);
      expect(pRight.side, EdgeSide.right);
      expect(pRight.rotation, greaterThan(0.5));

      // 2. Vật thể sát cả mép trên lẫn mép phải -> mép trên & phải hết chỗ, cắn mép trái
      final anchorLeftRoom = AnchorMath.anchorFromMask(
        imageSize: const Size(480, 480),
        bounds: const Rect.fromLTWH(290, 0, 160, 220),
        mask: solid,
      );
      final pLeft = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: anchorLeftRoom,
        bitePoint: const Offset(0.5, 0.82),
        biteDirection: const Offset(0, 1),
        widthFactor: 0.40,
        biteDepthFraction: StickerPlacementSolver.defaultBiteDepthFraction,
        stickerPixelSize: const Size(512, 512),
        photoBoxSize: 360,
      );
      expect(pLeft.kind, PlacementKind.sideEdge);
      expect(pLeft.side, EdgeSide.left);
      expect(pLeft.rotation, lessThan(-0.5));
    });

    testWidgets('RenderBox.localToGlobal: mặt nạ có mép phải nghiêng -> bitePoint trùng điểm neo (< 1px) và dir hướng vào vật thể', (tester) async {
      const maskW = 160;
      const maskH = 220;
      final data = Uint8List(maskW * maskH);
      for (var y = 0; y < maskH; y++) {
        final xRight = (150 - 0.22 * y).round().clamp(10, maskW - 1);
        for (var x = 0; x <= xRight; x++) {
          data[y * maskW + x] = 1;
        }
      }
      final mask = BinaryMask(maskW, maskH, data);
      final anchor = AnchorMath.anchorFromMask(
        imageSize: const Size(480, 480),
        bounds: const Rect.fromLTWH(60, 0, 160, 220), // Sát đỉnh để chọn cạnh phải
        mask: mask,
      );

      const photoBoxSize = 360.0;
      final side = StickerGeometry.frameSide(photoBoxSize);
      const bite = Offset(0.50, 0.82);
      const dir = Offset(0.0, 1.0);
      const stickerPx = Size(512, 512);

      final placement = StickerPlacementSolver.solve(
        mode: AnchorMode.topEdge,
        anchor: anchor,
        bitePoint: bite,
        biteDirection: dir,
        widthFactor: 0.40,
        biteDepthFraction: StickerPlacementSolver.defaultBiteDepthFraction,
        stickerPixelSize: stickerPx,
        photoBoxSize: photoBoxSize,
      );

      expect(placement.kind, PlacementKind.sideEdge);
      expect(placement.side, EdgeSide.right);
      expect(placement.targetInFrame, isNotNull);

      final geo = StickerGeometry(photoBoxSize: photoBoxSize, scale: placement.scale);
      final topLeft = geo.topLeftFor(placement.position);
      final boxKey = GlobalKey();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  Positioned(
                    left: topLeft.dx,
                    top: topLeft.dy,
                    child: Transform.rotate(
                      angle: placement.rotation,
                      child: SizedBox(key: boxKey, width: geo.size, height: geo.size),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final box = tester.renderObject<RenderBox>(find.byKey(boxKey));
      final onScreenBite = box.localToGlobal(geo.biteLocal(bite, stickerPx));
      expect((onScreenBite - placement.targetInFrame!).distance, lessThan(1.0));

      // Kiểm tra vector hướng miệng `dir` sau khi xoay góc `placement.rotation` hướng VÀO TRONG vật thể
      final cosA = math.cos(placement.rotation);
      final sinA = math.sin(placement.rotation);
      final rotatedDir = Offset(dir.dx * cosA - dir.dy * sinA, dir.dx * sinA + dir.dy * cosA);
      final outward = anchor.rightEdge!.outwardNormal;
      final inward = Offset(-outward.dx, -outward.dy);
      final dot = rotatedDir.dx * inward.dx + rotatedDir.dy * inward.dy;
      expect(dot, greaterThan(0.5));
    });

    test('StickerAnchoringEngine: có pool bite -> beverage đổi sang topEdge & lấy BiteMeta; rỗng -> fallback cũ', () {
      final metaMap = BiteMeta.parseJsonMap({
        'bite_hachi_01.png': {
          'bite': [0.50, 0.82],
          'dir': [-1.0, 0.0],
          'width': 0.40,
        },
      });
      const pool = ['assets/memes/bite/bite_hachi_01.png'];

      // Khi có pool bite: đồ uống cũng cắn mép ly (topEdge) thay vì hug
      final drinkBite = StickerAnchoringEngine.pickStickerForCategory(
        StickerCategory.beverage,
        bitePool: pool,
        biteMetaMap: metaMap,
      );
      expect(drinkBite.assetPath, 'assets/memes/bite/bite_hachi_01.png');
      expect(drinkBite.anchorMode, AnchorMode.topEdge);
      expect(drinkBite.bitePoint, const Offset(0.50, 0.82));
      expect(drinkBite.biteDirection, const Offset(-1.0, 0.0));
      expect(drinkBite.widthFactor, closeTo(0.40, 1e-9));

      // Phong cảnh vẫn giữ nguyên Capybara scene (không cắn)
      final scene = StickerAnchoringEngine.pickStickerForCategory(
        StickerCategory.scene,
        bitePool: pool,
        biteMetaMap: metaMap,
      );
      expect(scene.anchorMode, AnchorMode.scene);

      // Khi pool bite rỗng: fallback về hành vi cũ, không lỗi
      final drinkFallback = StickerAnchoringEngine.pickStickerForCategory(
        StickerCategory.beverage,
      );
      expect(drinkFallback.anchorMode, AnchorMode.hug);
    });

    testWidgets('Thư mục assets/memes/bite/ chưa có ảnh PNG -> getAvailableBiteAssets không crash', (tester) async {
      final available = await StickerAnchoringEngine.getAvailableBiteAssets();
      expect(available, isA<List<String>>());
    });
  });
}
