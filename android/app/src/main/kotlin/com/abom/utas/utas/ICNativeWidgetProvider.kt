package com.abom.utas.utas

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class ICNativeWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_ORBIT_TICK = "com.abom.utas.utas.ACTION_ORBIT_TICK"
        private var currentRotationAngle = 0f
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_ORBIT_TICK || action == Intent.ACTION_USER_PRESENT || action == Intent.ACTION_SCREEN_ON) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, ICNativeWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            if (appWidgetIds.isNotEmpty()) {
                val widgetData = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                // Tiến thêm góc xoay nhẹ mượt mà (+15 độ mỗi chu kỳ)
                currentRotationAngle = (currentRotationAngle + 15f) % 360f
                onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
            }
            scheduleNextTick(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleNextTick(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelNextTick(context)
    }

    private fun scheduleNextTick(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ICNativeWidgetProvider::class.java).apply {
            this.action = ACTION_ORBIT_TICK
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            9991,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Lên lịch cập nhật nhẹ sau mỗi 30 giây khi thiết bị hoạt động
        val triggerAt = System.currentTimeMillis() + 30000L
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC, triggerAt, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC, triggerAt, pendingIntent)
        }
    }

    private fun cancelNextTick(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val intent = Intent(context, ICNativeWidgetProvider::class.java).apply {
            this.action = ACTION_ORBIT_TICK
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            9991,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        // Tự động tính toán góc xoay dựa trên thời gian và currentRotationAngle
        val timeBasedAngle = ((System.currentTimeMillis() / 20000L) % 360).toFloat() * 10f % 360f
        val effectiveAngle = if (currentRotationAngle != 0f) currentRotationAngle else timeBasedAngle

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // 1. Chạm vào bất kỳ vị trí nào trên widget để mở app ngay lập tức (SingleTop không reload lại từ đầu)
                val intent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                setOnClickPendingIntent(R.id.widget_image, pendingIntent)

                // 2. Load ảnh & tên người gửi
                val imagePath = widgetData.getString("widget_image_path", null)
                val senderName = widgetData.getString("widget_sender_name", null)

                if (imagePath != null && File(imagePath).exists()) {
                    var bitmap = BitmapFactory.decodeFile(imagePath)

                    if (bitmap != null) {
                        // Fix góc xoay EXIF
                        try {
                            val exif = ExifInterface(imagePath)
                            val orientation = exif.getAttributeInt(
                                ExifInterface.TAG_ORIENTATION,
                                ExifInterface.ORIENTATION_NORMAL
                            )
                            val matrix = Matrix()
                            when (orientation) {
                                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                            }
                            if (!matrix.isIdentity) {
                                bitmap = android.graphics.Bitmap.createBitmap(
                                    bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true
                                )
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }

                        val isDemoMode = widgetData.getBoolean("flutter.is_demo_mode", false)
                        val friendCount = widgetData.getInt("flutter.friend_count", 0)
                        val shouldDrawSatellites = isDemoMode || friendCount > 0

                        // 3. Render Thiên Hà Vệ Tinh Nổi với chuyển động xoay nhẹ và vòng sáng rực rỡ
                        val composed = WidgetComposer.composeGalaxyWidget(bitmap, effectiveAngle, shouldDrawSatellites)
                        setImageViewBitmap(R.id.widget_image, composed)
                        setViewVisibility(R.id.widget_empty_text, View.GONE)

                        if (!senderName.isNullOrBlank()) {
                            setTextViewText(R.id.widget_sender_name, senderName)
                            setViewVisibility(R.id.widget_sender_name, View.VISIBLE)
                        } else {
                            setViewVisibility(R.id.widget_sender_name, View.GONE)
                        }
                    } else {
                        showEmptyState(this)
                    }
                } else {
                    showEmptyState(this)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
        scheduleNextTick(context)
    }

    private fun showEmptyState(views: RemoteViews) {
        views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder_bg)
        views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
        views.setViewVisibility(R.id.widget_sender_name, View.GONE)
    }
}
