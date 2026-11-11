import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  const width = 1200;
  const height = 630;

  final image = img.Image(width: width, height: height);

  // Background color #FEFAE0
  final bg = img.ColorRgba8(0xFE, 0xFA, 0xE0, 0xFF);
  img.fill(image, color: bg);

  // Decorative Card container in center
  const cardLeft = 40;
  const cardTop = 30;
  const cardRight = width - 40;
  const cardBottom = height - 30;
  final cardColor = img.ColorRgba8(0xFA, 0xF3, 0xDD, 0xFF);
  final borderColor = img.ColorRgba8(0x60, 0x6C, 0x38, 0xFF);

  // Fill card background
  for (int y = cardTop; y <= cardBottom; y++) {
    for (int x = cardLeft; x <= cardRight; x++) {
      image.setPixel(x, y, cardColor);
    }
  }

  // Draw card border
  for (int w = 0; w < 4; w++) {
    img.drawRect(
      image,
      x1: cardLeft + w,
      y1: cardTop + w,
      x2: cardRight - w,
      y2: cardBottom - w,
      color: borderColor,
    );
  }

  // Load app logo
  final logoFile = File('hosting_invite/orbit_icon.png');
  img.Image? logo;
  if (logoFile.existsSync()) {
    final bytes = logoFile.readAsBytesSync();
    logo = img.decodeImage(bytes);
  }

  // Draw orbital rings around center-left (cx = 320, cy = 315)
  const cx = 320;
  const cy = 315;
  final ringColor1 = img.ColorRgba8(0xDD, 0xA1, 0x5E, 0x99);
  final ringColor2 = img.ColorRgba8(0xBC, 0x6C, 0x25, 0x88);
  final ringColor3 = img.ColorRgba8(0x60, 0x6C, 0x38, 0x77);

  // Draw 3 concentric orbit rings
  img.drawCircle(image, x: cx, y: cy, radius: 210, color: ringColor3);
  img.drawCircle(image, x: cx, y: cy, radius: 160, color: ringColor2);
  img.drawCircle(image, x: cx, y: cy, radius: 110, color: ringColor1);

  // Draw small orbiting satellites
  final satColor1 = img.ColorRgba8(0xFF, 0x70, 0x43, 0xFF);
  final satColor2 = img.ColorRgba8(0xFF, 0xD5, 0x4F, 0xFF);
  final satColor3 = img.ColorRgba8(0x66, 0xBB, 0x6A, 0xFF);

  // Satellite 1 on outer ring
  final s1x = (cx + 210 * math.cos(0.8)).round();
  final s1y = (cy + 210 * math.sin(0.8)).round();
  img.fillCircle(image, x: s1x, y: s1y, radius: 16, color: satColor1);

  // Satellite 2 on middle ring
  final s2x = (cx + 160 * math.cos(-1.2)).round();
  final s2y = (cy + 160 * math.sin(-1.2)).round();
  img.fillCircle(image, x: s2x, y: s2y, radius: 14, color: satColor2);

  // Satellite 3 on inner ring
  final s3x = (cx + 110 * math.cos(2.5)).round();
  final s3y = (cy + 110 * math.sin(2.5)).round();
  img.fillCircle(image, x: s3x, y: s3y, radius: 12, color: satColor3);

  // Place center logo
  if (logo != null) {
    final resizedLogo = img.copyResize(logo, width: 140, height: 140);
    // Draw white / cream circle backing
    img.fillCircle(image, x: cx, y: cy, radius: 76, color: borderColor);
    img.compositeImage(image, resizedLogo, dstX: cx - 70, dstY: cy - 70);
  }

  // Draw text section on the right (x from 560 to 1100)
  // Draw header badge pill
  const badgeLeft = 560;
  const badgeTop = 90;
  const badgeRight = 930;
  const badgeBottom = 136;
  final badgeColor = img.ColorRgba8(0x60, 0x6C, 0x38, 0x26);
  for (int y = badgeTop; y <= badgeBottom; y++) {
    for (int x = badgeLeft; x <= badgeRight; x++) {
      image.setPixel(x, y, badgeColor);
    }
  }

  img.drawString(
    image,
    'ORBIT HOME WIDGET',
    font: img.arial24,
    x: 580,
    y: 100,
    color: borderColor,
  );

  // Big Title
  final deepOlive = img.ColorRgba8(0x28, 0x36, 0x18, 0xFF);
  img.drawString(
    image,
    'KET NOI BAN BE',
    font: img.arial48,
    x: 560,
    y: 170,
    color: deepOlive,
  );

  img.drawString(
    image,
    '& CHIA SE ANH WIDGET',
    font: img.arial48,
    x: 560,
    y: 235,
    color: deepOlive,
  );

  // Subtitle
  final subColor = img.ColorRgba8(0x60, 0x6C, 0x38, 0xEE);
  img.drawString(
    image,
    'Khoanh khac ban be tu dong cap nhat ngay tren man hinh chinh.',
    font: img.arial24,
    x: 560,
    y: 320,
    color: subColor,
  );
  img.drawString(
    image,
    '100% On-Device  -  0 VND Cloud  -  Android & iOS',
    font: img.arial24,
    x: 560,
    y: 360,
    color: subColor,
  );

  // Button pill at bottom right
  const btnLeft = 560;
  const btnTop = 440;
  const btnRight = 980;
  const btnBottom = 515;
  for (int y = btnTop; y <= btnBottom; y++) {
    for (int x = btnLeft; x <= btnRight; x++) {
      image.setPixel(x, y, borderColor);
    }
  }

  img.drawString(
    image,
    'BAM VAO DE KET BAN NGAY ->',
    font: img.arial24,
    x: 600,
    y: 465,
    color: img.ColorRgba8(0xFE, 0xFA, 0xE0, 0xFF),
  );

  final outPath = 'hosting_invite/og_preview.png';
  File(outPath).writeAsBytesSync(img.encodePng(image));
  print('Successfully generated $outPath (${File(outPath).lengthSync()} bytes)');
}
