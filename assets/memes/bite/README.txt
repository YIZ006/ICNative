HƯỚNG DẪN THÊM MEME "CẮN MÉP" (BITE SNAPPING)
=============================================

1. Chuẩn bị file ảnh:
   - Định dạng: PNG nền trong suốt (transparent background).
   - Tư thế gợi ý: Nhân vật meme có miệng há to hướng xuống dưới (ví dụ Chiikawa, Hachiware, Usagi ngoạm bánh).
   - Đặt các file `.png` trực tiếp vào thư mục này: `assets/memes/bite/`.

2. Khai báo toạ độ miệng trong `assets/memes/bite/bite_meta.json`:
   Mỗi dòng khai báo theo tên file ảnh:
   ```json
   {
     "bite_hachi_01.png": { "bite": [0.50, 0.82], "dir": [0.0, 1.0], "width": 0.40 },
     "bite_usagi_01.png": { "bite": [0.48, 0.78], "dir": [0.0, 1.0], "width": 0.42 }
   }
   ```
   - `bite`: `[x, y]` chuẩn hoá từ `0.0` đến `1.0` chỉ đúng tâm miệng (điểm mà mép bánh / gò má sẽ lọt vào).
   - `dir`: `[dx, dy]` hướng từ miệng ra phía vật thể khi ảnh meme chưa xoay:
     + Miệng há hướng xuống đáy ảnh: `[0.0, 1.0]` (mặc định).
     + Miệng há hướng sang trái ảnh: `[-1.0, 0.0]`.
     + Miệng há hướng sang phải ảnh: `[1.0, 0.0]`.
   - `width`: tỉ lệ chiều rộng meme so với chiều rộng vật thể (mặc định `0.45`).

3. Tinh chỉnh toạ độ miệng trực quan bằng mắt (`kDebugBite`):
   - Mở `lib/services/anchor_math.dart`, đổi `const bool kDebugBite = false;` thành `true`.
   - Chạy app và chụp thử: màn hình Xem trước sẽ vẽ **chấm đỏ** tại `bite` trên meme và **chấm xanh** tại điểm neo trên mép vật thể.
   - Chỉnh `bite` trong `bite_meta.json` sao cho chấm đỏ nằm đúng giữa miệng meme, sau đó trả `kDebugBite = false`.

4. Lưu ý an toàn:
   - Nếu thư mục này chưa có file `.png` nào, ứng dụng tự động dùng kho meme mặc định và không xảy ra lỗi.
