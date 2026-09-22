package com.abom.utas.utas

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ICNativeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val imagePath = widgetData.getString("widget_image_path", null)
                if (imagePath != null) {
                    var bitmap = BitmapFactory.decodeFile(imagePath)
                    
                    // Fix EXIF Rotation
                    try {
                        val exif = ExifInterface(imagePath)
                        val orientation = exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
                        val matrix = Matrix()
                        when (orientation) {
                            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                        }
                        if (!matrix.isIdentity) {
                            bitmap = android.graphics.Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
