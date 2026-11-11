package com.abom.utas.utas

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val UPDATER_CHANNEL = "com.abom.utas.utas/app_updater"
    private val WIDGET_PIN_CHANNEL = "com.abom.utas.utas/widget_pin"
    private val SCRATCH_SFX_CHANNEL = "com.abom.utas.utas/scratch_sfx"
    private val STORY_SHARE_CHANNEL = "com.abom.utas.utas/story_share"
    private val DEEP_LINK_CHANNEL = "com.abom.utas.utas/deep_link"
    private val storyExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var storyEncoder: StoryVideoEncoder? = null
    private var soundPool: SoundPool? = null
    private var scratchSoundId: Int = 0
    private var lastPlayTime = 0L
    private var pendingInviteLink: String? = null
    private var deepLinkMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractInviteLink(intent)?.let { link ->
            pendingInviteLink = link
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractInviteLink(intent)?.let { link ->
            pendingInviteLink = link
            mainHandler.post {
                try {
                    deepLinkMethodChannel?.invokeMethod("onDeepLink", link)
                } catch (_: Exception) {}
            }
        }
    }

    private fun extractInviteLink(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action == Intent.ACTION_VIEW) {
            val dataUri = intent.dataString
            if (!dataUri.isNullOrBlank()) {
                return dataUri
            }
        }
        return null
    }

    private fun initScratchSound() {
        if (soundPool != null) return
        try {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            soundPool = SoundPool.Builder()
                .setMaxStreams(4)
                .setAudioAttributes(audioAttributes)
                .build()

            scratchSoundId = soundPool!!.load(this, R.raw.scratch, 1)
        } catch (e: Exception) {
            soundPool = null
        }
    }

    private fun playScratchSound() {
        try {
            if (soundPool == null || scratchSoundId == 0) {
                initScratchSound()
            }
            val now = System.currentTimeMillis()
            // Giới hạn tần suất tối thiểu 70ms: Loại bỏ hoàn toàn tiếng ù/rè liên tục như điện giật
            if (now - lastPlayTime < 70) return
            lastPlayTime = now

            soundPool?.let { pool ->
                if (scratchSoundId != 0) {
                    // Biến thiên độ cao (pitch) và âm lượng ngẫu nhiên nhẹ: Tạo cảm giác cào ma sát thẻ cào thật 100%
                    val pitch = 0.92f + (Math.random().toFloat() * 0.22f)
                    val volume = 0.65f + (Math.random().toFloat() * 0.20f)
                    pool.play(scratchSoundId, volume, volume, 1, 0, pitch)
                }
            }
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            soundPool?.release()
            soundPool = null
        } catch (e: Exception) {}
        try {
            storyEncoder?.cancel()
            storyEncoder = null
            storyExecutor.shutdown()
        } catch (e: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Kênh cập nhật APK & Mở liên kết GitHub Releases
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
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
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_ERROR", "Lỗi mở liên kết: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL null", null)
                    }
                }
                "getAppVersion" -> {
                    try {
                        val pInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            context.packageManager.getPackageInfo(context.packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
                        } else {
                            @Suppress("DEPRECATION")
                            context.packageManager.getPackageInfo(context.packageName, 0)
                        }
                        result.success(pInfo.versionName ?: "1.4.0")
                    } catch (e: Exception) {
                        result.success("1.4.0")
                    }
                }
                else -> result.notImplemented()
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

        // 3. Kênh âm thanh xé / cào lớp bạc (100% Offline 0 VNĐ PCM Synthesis)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCRATCH_SFX_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playScratch" -> {
                    playScratchSound()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 4. Kênh xuất Story động (MP4) + Lưu Thư viện + Chia sẻ thẳng lên Instagram Story
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORY_SHARE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVideo" -> runInBackground(result) {
                    storyEncoder?.cancel()
                    storyEncoder = StoryVideoEncoder(
                        File(call.argument<String>("path")!!),
                        call.argument<Int>("width")!!,
                        call.argument<Int>("height")!!,
                        call.argument<Int>("fps")!!,
                    )
                    true
                }
                "addFrame" -> runInBackground(result) {
                    val encoder = storyEncoder ?: throw IllegalStateException("Encoder chưa khởi tạo")
                    encoder.addFrame(
                        call.argument<ByteArray>("bytes")!!,
                        call.argument<Int>("width")!!,
                        call.argument<Int>("height")!!,
                    )
                    true
                }
                "finishVideo" -> runInBackground(result) {
                    val encoder = storyEncoder ?: throw IllegalStateException("Encoder chưa khởi tạo")
                    storyEncoder = null
                    encoder.finish()
                }
                "cancelVideo" -> runInBackground(result) {
                    storyEncoder?.cancel()
                    storyEncoder = null
                    true
                }
                "saveToGallery" -> runInBackground(result) {
                    StoryShareHelper.saveToGallery(
                        this,
                        File(call.argument<String>("path")!!),
                        call.argument<String>("mime")!!,
                    )
                }
                "isInstagramInstalled" -> result.success(StoryShareHelper.isInstagramInstalled(this))
                "shareToInstagramStory" -> {
                    try {
                        result.success(
                            StoryShareHelper.shareToInstagramStory(
                                this,
                                File(call.argument<String>("path")!!),
                                call.argument<String>("mime")!!,
                            )
                        )
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                "shareGeneric" -> {
                    try {
                        StoryShareHelper.shareGeneric(
                            this,
                            File(call.argument<String>("path")!!),
                            call.argument<String>("mime")!!,
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 5. Kênh Deep Link Kết Bạn & Chia sẻ liên kết (100% Native, 0 VNĐ)
        deepLinkMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL)
        deepLinkMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    val link = pendingInviteLink
                    pendingInviteLink = null
                    result.success(link)
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    val title = call.argument<String>("title") ?: "Chia sẻ liên kết kết bạn Orbit"
                    if (!text.isNullOrBlank()) {
                        try {
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            val chooser = Intent.createChooser(sendIntent, title)
                            startActivity(chooser)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_TEXT_ERROR", e.message, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Chạy tác vụ nặng (mã hoá video, ghi file) trên luồng nền, trả kết quả về luồng chính. */
    private fun runInBackground(result: MethodChannel.Result, block: () -> Any?) {
        storyExecutor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("STORY_ERROR", e.message, null) }
            }
        }
    }
}
