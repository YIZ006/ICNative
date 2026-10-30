package com.abom.utas.utas

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val UPDATER_CHANNEL = "com.abom.utas.utas/app_updater"
    private val WIDGET_PIN_CHANNEL = "com.abom.utas.utas/widget_pin"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Kênh tự động cập nhật APK từ GitHub
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        val file = File(filePath)
                        if (file.exists()) {
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                                val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    FileProvider.getUriForFile(
                                        context,
                                        "${context.packageName}.fileprovider",
                                        file
                                    )
                                } else {
                                    Uri.fromFile(file)
                                }
                                setDataAndType(uri, "application/vnd.android.package-archive")
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } else {
                            result.error("FILE_NOT_FOUND", "Tệp APK không tồn tại tại $filePath", null)
                        }
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", "Lỗi cài đặt APK: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_PATH", "Đường dẫn APK null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Kênh ghim Widget nhanh 1-chạm (Android 8.0+ requestPinAppWidget)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_PIN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPinSupported" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        result.success(appWidgetManager.isRequestPinAppWidgetSupported)
                    } else {
                        result.success(false)
                    }
                }
                "requestPinWidget" -> {
                    val widgetType = call.argument<String>("type") ?: "galaxy"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val appWidgetManager = AppWidgetManager.getInstance(this)
                            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                                val providerClass = if (widgetType == "pebble") {
                                    ICNativePebbleWidgetProvider::class.java
                                } else {
                                    ICNativeWidgetProvider::class.java
                                }
                                val provider = ComponentName(this, providerClass)
                                val success = appWidgetManager.requestPinAppWidget(provider, null, null)
                                result.success(success)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("PIN_ERROR", "Lỗi khi ghim widget: ${e.message}", null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
