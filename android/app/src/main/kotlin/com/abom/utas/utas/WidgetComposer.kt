package com.abom.utas.utas

import android.content.Context
import android.graphics.*
import kotlin.math.cos
import kotlin.math.sin

object WidgetComposer {

    // ==========================================
    // KIỂU 10: THIÊN HÀ VỆ TINH NỔI (GALAXY ORBIT WIDGET) - ĐẬM NÉT & TƯƠNG PHẢN CAO
    // ==========================================
    fun composeGalaxyWidget(baseBitmap: Bitmap): Bitmap {
        val size = 512
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val cx = size / 2f
        val cy = size / 2f

        // Bật đổ bóng phần cứng cho viền để nổi bật trên mọi nền màn hình sáng/trắng
        paint.setShadowLayer(6f, 0f, 3f, Color.parseColor("#4D000000"))

        // 1. Quỹ đạo ngoài cùng (Far Orbit - R = 215) - Nét đứt đậm màu Rêu đậm #283618
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 4.5f
        paint.color = Color.parseColor("#CC283618") // Đậm nét, không mờ nhạt
        paint.pathEffect = DashPathEffect(floatArrayOf(16f, 12f), 0f)
        canvas.drawCircle(cx, cy, 215f, paint)

        // 2. Quỹ đạo giữa (Outer Orbit - R = 160) - Nét liền đậm màu Đất Nung #BC6C25
        paint.color = Color.parseColor("#E6BC6C25")
        paint.strokeWidth = 5.5f
        paint.pathEffect = null
        canvas.drawCircle(cx, cy, 160f, paint)

        // 3. Quỹ đạo phụ trong (Inner Ripple - R = 126) - Nét vàng cát đậm #DDA15E
        paint.color = Color.parseColor("#CC606C38")
        paint.strokeWidth = 3.5f
        paint.pathEffect = DashPathEffect(floatArrayOf(8f, 8f), 0f)
        canvas.drawCircle(cx, cy, 126f, paint)
        paint.pathEffect = null

        // 4. Các vệ tinh bạn bè quay quanh (Đậm, viền sáng tương phản)
        drawBoldSatellite(canvas, cx + 160f * 0.85f, cy - 160f * 0.52f, 25f, Color.parseColor("#283618"), "A")
        drawBoldSatellite(canvas, cx - 160f * 0.70f, cy + 160f * 0.71f, 23f, Color.parseColor("#BC6C25"), "B")
        drawBoldSatellite(canvas, cx - 215f * 0.35f, cy - 215f * 0.93f, 22f, Color.parseColor("#606C38"), "C")
        drawBoldSatellite(canvas, cx + 215f * 0.60f, cy + 215f * 0.80f, 22f, Color.parseColor("#283618"), "D")

        // 5. Đổ bóng lõi ống kính trung tâm
        val coreRadius = 110f
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#33000000")
            maskFilter = BlurMaskFilter(12f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawCircle(cx, cy + 4f, coreRadius, shadowPaint)

        // 6. Lõi ảnh trung tâm
        val scaled = Bitmap.createScaledBitmap(baseBitmap, (coreRadius * 2).toInt(), (coreRadius * 2).toInt(), true)
        val shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        val matrix = Matrix()
        matrix.setTranslate(cx - coreRadius, cy - coreRadius)
        shader.setLocalMatrix(matrix)

        paint.clearShadowLayer()
        paint.style = Paint.Style.FILL
        paint.shader = shader
        canvas.drawCircle(cx, cy, coreRadius, paint)
        paint.shader = null

        // 7. Viền kép ống kính đậm sắc nét: Lớp ngoài #283618 dày 8f, lớp trong #DDA15E vàng óng
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 8.5f
        paint.color = Color.parseColor("#283618")
        canvas.drawCircle(cx, cy, coreRadius, paint)

        paint.strokeWidth = 3f
        paint.color = Color.parseColor("#FEFAE0")
        canvas.drawCircle(cx, cy, coreRadius - 3.5f, paint)

        return output
    }

    // ==========================================
    // KIỂU 3: ĐÁ CUỘI GỢN SÓNG (CONCENTRIC RIPPLE PEBBLE WIDGET) - ĐẬM NÉT & ĐỔ BÓNG NỔI
    // ==========================================
    fun composePebbleWidget(baseBitmap: Bitmap): Bitmap {
        val size = 512
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val cx = size / 2f
        val cy = size / 2f

        // 1. Đường cong viên đá cuội hữu cơ mềm mại (Zen Pebble Blob)
        val pebblePath = Path().apply {
            moveTo(cx, cy - 165f)
            cubicTo(cx + 170f, cy - 160f, cx + 195f, cy + 130f, cx + 20f, cy + 175f)
            cubicTo(cx - 160f, cy + 185f, cx - 185f, cy + 80f, cx - 170f, cy - 70f)
            cubicTo(cx - 150f, cy - 165f, cx - 70f, cy - 170f, cx, cy - 165f)
            close()
        }

        // 2. Các gợn sóng đồng tâm lan tỏa (Ripples) - Đậm nét, không mờ nhạt
        paint.setShadowLayer(6f, 0f, 3f, Color.parseColor("#4D000000"))
        paint.style = Paint.Style.STROKE

        // Gợn sóng ngoài: Màu Rêu đậm #283618
        paint.strokeWidth = 5f
        paint.color = Color.parseColor("#B3283618")
        paint.pathEffect = DashPathEffect(floatArrayOf(18f, 14f), 0f)
        canvas.drawCircle(cx, cy, 230f, paint)

        // Gợn sóng giữa: Màu Đất nung #BC6C25
        paint.strokeWidth = 6f
        paint.color = Color.parseColor("#E6BC6C25")
        paint.pathEffect = null
        canvas.drawCircle(cx, cy, 195f, paint)

        // 3. Đổ bóng hình khối đá cuội
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#40000000")
            maskFilter = BlurMaskFilter(14f, BlurMaskFilter.Blur.NORMAL)
        }
        val shadowMatrix = Matrix().apply { postTranslate(0f, 6f) }
        val shadowPath = Path(pebblePath)
        shadowPath.transform(shadowMatrix)
        canvas.drawPath(shadowPath, shadowPaint)

        // 4. Khối đá cuội chứa ảnh
        val scaled = Bitmap.createScaledBitmap(baseBitmap, size, size, true)
        val shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        paint.clearShadowLayer()
        paint.style = Paint.Style.FILL
        paint.shader = shader
        canvas.drawPath(pebblePath, paint)
        paint.shader = null

        // 5. Viền đá cuội kép đậm sắc nét: Viền ngoài #283618 dày 9f, viền trong #FEFAE0
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 9f
        paint.color = Color.parseColor("#283618")
        canvas.drawPath(pebblePath, paint)

        paint.strokeWidth = 3f
        paint.color = Color.parseColor("#FEFAE0")
        canvas.drawPath(pebblePath, paint)

        return output
    }

    private fun drawBoldSatellite(canvas: Canvas, x: Float, y: Float, radius: Float, color: Int, initial: String) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Đổ bóng vệ tinh
        paint.setShadowLayer(5f, 0f, 2f, Color.parseColor("#55000000"))
        paint.style = Paint.Style.FILL
        paint.color = color
        canvas.drawCircle(x, y, radius, paint)

        // Viền kép nổi bật: Viền trắng sáng giúp tách biệt hoàn hảo trên nền sáng lẫn tối
        paint.clearShadowLayer()
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 3f
        paint.color = Color.parseColor("#FEFAE0")
        canvas.drawCircle(x, y, radius, paint)

        // Chữ cái đại diện vệ tinh
        paint.style = Paint.Style.FILL
        paint.color = Color.parseColor("#FEFAE0")
        paint.textSize = radius * 0.95f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        paint.textAlign = Paint.Align.CENTER

        val textBounds = Rect()
        paint.getTextBounds(initial, 0, initial.length, textBounds)
        val textY = y + (textBounds.height() / 2f)
        canvas.drawText(initial, x, textY, paint)
    }
}