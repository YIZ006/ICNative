// ignore_for_file: avoid_print, prefer_const_declarations
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = r'C:\Users\Chien\.gemini\antigravity\brain\22b093e2-69a8-4b71-9f52-fb8d1e2173c7\derpy_dog_selfie_meme_1793211005150.jpg';
  final outputPath = r'C:\Users\Chien\.gemini\antigravity\brain\22b093e2-69a8-4b71-9f52-fb8d1e2173c7\derpy_dog_blurry_phone_meme.jpg';

  final bytes = File(inputPath).readAsBytesSync();
  var image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // 1. Resize to typical mobile front-cam / Messenger meme resolution (~480x480)
  image = img.copyResize(image, width: 480, height: 480, interpolation: img.Interpolation.linear);

  // 2. Add realistic subtle Gaussian blur / soft focus
  image = img.gaussianBlur(image, radius: 2);

  // 3. Add directional motion blur (simulating hand or pet shake)
  // Shift pixels slightly horizontally/vertically
  final motionBlured = img.Image(width: image.width, height: image.height);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      // average with 2 neighboring pixels for motion blur effect
      int r = 0, g = 0, b = 0;
      int count = 0;
      for (int dx = -2; dx <= 2; dx++) {
        final nx = (x + dx).clamp(0, image.width - 1);
        final ny = (y + (dx > 0 ? 1 : 0)).clamp(0, image.height - 1);
        final p = image.getPixel(nx, ny);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        count++;
      }
      motionBlured.setPixelRgb(x, y, (r / count).round(), (g / count).round(), (b / count).round());
    }
  }

  // 4. Encode as realistic compressed JPEG (~35-45KB, authentic phone camera JPEG artifact)
  final jpgBytes = img.encodeJpg(motionBlured, quality: 62);
  File(outputPath).writeAsBytesSync(jpgBytes);

  print('Success! Created realistic blurry phone photo: ${jpgBytes.length} bytes at $outputPath');
}
