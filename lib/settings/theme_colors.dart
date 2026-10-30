import 'package:flutter/material.dart';

/// Bảng màu độc quyền Đất Ấm Quỹ Đạo (Warm Earth Orbit Palette)
/// - Màu chủ đạo (Dominant Canvas Background): #FEFAE0 (Kem bọt sữa ấm)
/// - Màu phụ đi kèm / Nút bấm (Primary Actions): #606C38 (Xanh rêu Olive)
/// - Màu chữ & viền đậm (Deep Forest Olive): #283618
/// - Màu điểm xuyết ấm (Khaki Gold): #DDA15E
/// - Màu đất nung (Terracotta): #BC6C25
class OrbitColors {
  // 1. Nền chủ đạo toàn app
  static const Color background = Color(0xFFFEFAE0);
  
  // 2. Nút bấm & thành phần tương tác chính
  static const Color buttonPrimary = Color(0xFF606C38);
  static const Color buttonPrimaryDark = Color(0xFF4C562B);
  
  // 3. Chữ, viền thẫm & lõi shutter tương phản cao
  static const Color deepOlive = Color(0xFF283618);
  
  // 4. Điểm nhấn vàng cát ấm & thông báo
  static const Color khakiGold = Color(0xFFDDA15E);
  static const Color terracotta = Color(0xFFBC6C25);
  
  // 5. Thẻ nội dung & bề mặt
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceCream = Color(0xFFF6F3DE);
  static const Color borderSubtle = Color(0xFFE5DFC5);
  static const Color borderOlive = Color(0xFF606C38);
  
  // 6. Màu văn bản
  static const Color textDark = Color(0xFF283618);
  static const Color textMuted = Color(0xFF606C38);
  static const Color textLight = Color(0xFFFEFAE0);
}
