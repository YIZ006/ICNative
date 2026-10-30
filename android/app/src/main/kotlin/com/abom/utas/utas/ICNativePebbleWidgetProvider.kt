package com.abom.utas.utas

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

class ICNativePebbleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
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

                        // 3. Render Kiểu 3: Đá Cuội Gợn Sóng (Concentric Ripple Pebble)
                        val composed = WidgetComposer.composePebbleWidget(bitmap)
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
    }

    private fun showEmptyState(views: RemoteViews) {
        views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder_bg)
        views.setViewVisibility(R.id.widget_empty_text, View.VISIBLE)
        views.setViewVisibility(R.id.widget_sender_name, View.GONE)
    }
}
