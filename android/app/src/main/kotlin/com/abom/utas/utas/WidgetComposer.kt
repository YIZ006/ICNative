package com.abom.utas.utas

import android.content.Context
import android.graphics.*
import kotlin.math.cos
import kotlin.math.sin

object WidgetComposer {

    // ==========================================
    // THIÊN HÀ VỆ TINH NỔI (GALAXY ORBIT WIDGET) - RỰC SÁNG & CHUYỂN ĐỘNG QUỸ ĐẠO
    // ==========================================
    fun composeGalaxyWidget(baseBitmap: Bitmap, rotationDegrees: Float = 0f, drawSatellites: Boolean = true): Bitmap {
        val size = 512
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val cx = size / 2f
        val cy = size / 2f

        // BƯỚC 1: VẼ CÁC VÒNG QUỸ ĐẠO VÀ VỆ TINH (CÓ XOAY ĐỘNG THEO GÓC rotationDegrees)
        canvas.save()
        canvas.rotate(rotationDegrees, cx, cy)

        // 0. Lớp hào quang tỏa sáng (Luminous Golden Aura) - Tách biệt nổi bật, nhẹ nhàng dễ nhìn
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 10f
            color = Color.parseColor("#4DFFE082") // Hào quang vàng hoàng kim dịu mắt
            maskFilter = BlurMaskFilter(8f, BlurMaskFilter.Blur.NORMAL)
        }
        val orbitRadius = 180f
        canvas.drawCircle(cx, cy, orbitRadius, glowPaint)

        // 1. Quỹ đạo tinh gọn, thanh thoát (Single Crisp Orbit - R = 180) - Nét đứt Vàng Kim Sáng Rực
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 4.5f
        paint.color = Color.parseColor("#FFFFE082") // Vàng kim sáng rực, thanh thoát
        paint.pathEffect = DashPathEffect(floatArrayOf(16f, 12f), 0f)
        paint.setShadowLayer(8f, 0f, 0f, Color.parseColor("#B3FFD54F"))
        canvas.drawCircle(cx, cy, orbitRadius, paint)
        paint.pathEffect = null

        // 2. Vệ tinh bạn bè (Chỉ vẽ khi có dữ liệu bạn bè hoặc ở bản Demo)
        if (drawSatellites) {
            val satR = 24f
            drawGlowingSatellite(canvas, cx + orbitRadius * 0.707f, cy - orbitRadius * 0.707f, satR, Color.parseColor("#FF7043"), "A", Color.parseColor("#FFE082"))
            drawGlowingSatellite(canvas, cx - orbitRadius * 0.707f, cy - orbitRadius * 0.707f, satR, Color.parseColor("#FFCA28"), "B", Color.parseColor("#FFFFFF"))
            drawGlowingSatellite(canvas, cx - orbitRadius * 0.707f, cy + orbitRadius * 0.707f, satR, Color.parseColor("#66BB6A"), "C", Color.parseColor("#FFE082"))
            drawGlowingSatellite(canvas, cx + orbitRadius * 0.707f, cy + orbitRadius * 0.707f, satR, Color.parseColor("#4DD0E1"), "D", Color.parseColor("#FFFFFF"))
        }

        // Khôi phục góc xoay về 0 để ảnh chụp trung tâm luôn ĐỨNG THẲNG, KHÔNG BỊ NGHIÊNG!
        canvas.restore()

        // BƯỚC 2: VẼ ẢNH CHỤP VÀ VIỀN ỐNG KÍNH TRUNG TÂM (RỘNG RÃI, THOÁNG ĐÃNG)
        val coreRadius = 118f
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#66000000")
            maskFilter = BlurMaskFilter(16f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawCircle(cx, cy + 5f, coreRadius, shadowPaint)

        // Lõi ảnh trung tâm
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

        // Viền kép ống kính: Lớp ngoài Vàng hoàng kim sáng chói dày 9f, lớp trong Trắng ngọc trai dày 3.5f
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 9.0f
        paint.color = Color.parseColor("#FFFFD54F")
        paint.setShadowLayer(10f, 0f, 0f, Color.parseColor("#99FFD54F"))
        canvas.drawCircle(cx, cy, coreRadius, paint)

        paint.clearShadowLayer()
        paint.strokeWidth = 3.5f
        paint.color = Color.parseColor("#FFFFFF")
        canvas.drawCircle(cx, cy, coreRadius - 3.5f, paint)

        return output
    }

    // ==========================================
    // ĐÁ CUỘI GỢN SÓNG (CONCENTRIC RIPPLE PEBBLE WIDGET) - RỰC SÁNG & ĐỔ BÓNG NỔI
    // ==========================================
    fun composePebbleWidget(baseBitmap: Bitmap, rotationDegrees: Float = 0f): Bitmap {
        val size = 512
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        val cx = size / 2f
        val cy = size / 2f

        canvas.save()
        canvas.rotate(rotationDegrees, cx, cy)

        // 1. Lớp hào quang gợn sóng lan tỏa
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 14f
            color = Color.parseColor("#4DFFE082")
            maskFilter = BlurMaskFilter(12f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawCircle(cx, cy, 230f, glowPaint)
        canvas.drawCircle(cx, cy, 195f, glowPaint)

        // 2. Gợn sóng ngoài: Vàng Kim Sáng Rực #FFE082
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 5.5f
        paint.color = Color.parseColor("#FFFFE082")
        paint.pathEffect = DashPathEffect(floatArrayOf(18f, 14f), 0f)
        paint.setShadowLayer(8f, 0f, 0f, Color.parseColor("#B3FFD54F"))
        canvas.drawCircle(cx, cy, 230f, paint)

        // 3. Gợn sóng giữa: Hổ phách sáng #FFB74D
        paint.strokeWidth = 6.5f
        paint.color = Color.parseColor("#FFFFB74D")
        paint.pathEffect = null
        paint.setShadowLayer(10f, 0f, 0f, Color.parseColor("#B3FFA726"))
        canvas.drawCircle(cx, cy, 195f, paint)

        canvas.restore()

        // 4. Đường cong viên đá cuội hữu cơ mềm mại (Zen Pebble Blob)
        val pebblePath = Path().apply {
            moveTo(cx, cy - 165f)
            cubicTo(cx + 170f, cy - 160f, cx + 195f, cy + 130f, cx + 20f, cy + 175f)
            cubicTo(cx - 160f, cy + 185f, cx - 185f, cy + 80f, cx - 170f, cy - 70f)
            cubicTo(cx - 150f, cy - 165f, cx - 70f, cy - 170f, cx, cy - 165f)
            close()
        }

        // Đổ bóng hình khối đá cuội
        val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = Color.parseColor("#55000000")
            maskFilter = BlurMaskFilter(16f, BlurMaskFilter.Blur.NORMAL)
        }
        val shadowMatrix = Matrix().apply { postTranslate(0f, 6f) }
        val shadowPath = Path(pebblePath)
        shadowPath.transform(shadowMatrix)
        canvas.drawPath(shadowPath, shadowPaint)

        // Khối đá cuội chứa ảnh
        val scaled = Bitmap.createScaledBitmap(baseBitmap, size, size, true)
        val shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        paint.clearShadowLayer()
        paint.style = Paint.Style.FILL
        paint.shader = shader
        canvas.drawPath(pebblePath, paint)
        paint.shader = null

        // Viền đá cuội kép sáng rực: Lớp ngoài #FFD54F dày 9.5f, lớp trong trắng ngọc #FFFFFF
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 9.5f
        paint.color = Color.parseColor("#FFFFD54F")
        paint.setShadowLayer(8f, 0f, 0f, Color.parseColor("#80FFD54F"))
        canvas.drawPath(pebblePath, paint)

        paint.clearShadowLayer()
        paint.strokeWidth = 3.5f
        paint.color = Color.parseColor("#FFFFFF")
        canvas.drawPath(pebblePath, paint)

        return output
    }

    private fun drawGlowingSatellite(
        canvas: Canvas,
        x: Float,
        y: Float,
        radius: Float,
        color: Int,
        initial: String,
        borderColor: Int
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Hào quang vàng tỏa sáng cho từng vệ tinh
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            this.color = Color.parseColor("#66FFE082")
            maskFilter = BlurMaskFilter(8f, BlurMaskFilter.Blur.NORMAL)
        }
        canvas.drawCircle(x, y, radius + 4f, glowPaint)

        // Thân vệ tinh màu tươi sáng
        paint.style = Paint.Style.FILL
        paint.color = color
        paint.setShadowLayer(6f, 0f, 2f, Color.parseColor("#4D000000"))
        canvas.drawCircle(x, y, radius, paint)

        // Viền kép sáng bóng
        paint.clearShadowLayer()
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 3.5f
        paint.color = borderColor
        canvas.drawCircle(x, y, radius, paint)

        // Chữ cái đại diện vệ tinh
        paint.style = Paint.Style.FILL
        paint.color = Color.parseColor("#FFFFFF")
        paint.textSize = radius * 1.0f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        paint.textAlign = Paint.Align.CENTER

        val textBounds = Rect()
        paint.getTextBounds(initial, 0, initial.length, textBounds)
        val textY = y + (textBounds.height() / 2f)
        canvas.drawText(initial, x, textY, paint)
    }
}
