package com.abom.utas.utas

import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Surface
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer

/**
 * Bộ mã hoá video H.264 (MP4) 100% Offline bằng MediaCodec có sẵn của Android.
 * Flutter gửi từng khung hình RGBA của template động -> vẽ lên Surface của encoder -> ghi MP4.
 * Không dùng thư viện ngoài, không Cloud API (0 VNĐ).
 */
class StoryVideoEncoder(
    private val outFile: File,
    private val width: Int,
    private val height: Int,
    private val fps: Int,
) {
    private val codec: MediaCodec
    private val inputSurface: Surface
    private val muxer: MediaMuxer
    private val bufferInfo = MediaCodec.BufferInfo()
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
    private var trackIndex = -1
    private var muxerStarted = false
    private var inFrameCount = 0L
    private var outFrameCount = 0L
    private var frameBitmap: Bitmap? = null

    init {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            throw IllegalStateException("Xuất video động yêu cầu Android 6.0 trở lên")
        }
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 6_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Không dùng B-frame để thứ tự khung hình đầu ra trùng thứ tự đầu vào
                setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            }
        }
        codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        inputSurface = codec.createInputSurface()
        codec.start()
        muxer = MediaMuxer(outFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    }

    /** Thêm 1 khung hình RGBA (premultiplied, đúng định dạng `ImageByteFormat.rawRgba` của Flutter). */
    fun addFrame(rgba: ByteArray, srcW: Int, srcH: Int) {
        // Giải phóng bớt hàng đợi output trước khi lockCanvas để tránh đầy BufferQueue
        drain(false)

        var bmp = frameBitmap
        if (bmp == null || bmp.width != srcW || bmp.height != srcH) {
            bmp?.recycle()
            bmp = Bitmap.createBitmap(srcW, srcH, Bitmap.Config.ARGB_8888)
            frameBitmap = bmp
        }
        val buffer = ByteBuffer.wrap(rgba)
        buffer.rewind()
        bmp!!.copyPixelsFromBuffer(buffer)

        val canvas: Canvas = try {
            inputSurface.lockCanvas(null)
        } catch (_: Exception) {
            inputSurface.lockHardwareCanvas()
        }
        try {
            canvas.drawColor(Color.BLACK)
            // Co giãn giữ tỉ lệ (aspect-fit) vào khung 9:16 của video
            val scale = minOf(width.toFloat() / srcW, height.toFloat() / srcH)
            val dw = srcW * scale
            val dh = srcH * scale
            val left = (width - dw) / 2f
            val top = (height - dh) / 2f
            canvas.drawBitmap(bmp, null, RectF(left, top, left + dw, top + dh), paint)
        } finally {
            inputSurface.unlockCanvasAndPost(canvas)
        }
        inFrameCount++
        drain(false)
    }

    /** Kết thúc mã hoá và đóng file MP4. */
    fun finish(): String {
        try {
            drain(true)
        } finally {
            release()
        }
        return outFile.absolutePath
    }

    fun cancel() {
        try { release() } catch (_: Exception) {}
        try { outFile.delete() } catch (_: Exception) {}
    }

    private fun drain(endOfStream: Boolean) {
        if (endOfStream) codec.signalEndOfInputStream()
        var idleLoops = 0
        while (true) {
            // Khi đang có nhiều hơn 1 khung hình chờ trong hàng đợi encoder, đợi tối đa 10ms
            // để hút hết khung hình ra, tránh làm đầy BufferQueue của Surface gây treo lockCanvas.
            val timeoutUs = when {
                endOfStream -> 10_000L
                inFrameCount - outFrameCount >= 2 -> 10_000L
                else -> 2_000L
            }
            val index = codec.dequeueOutputBuffer(bufferInfo, timeoutUs)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream && inFrameCount - outFrameCount < 2) return
                    idleLoops++
                    val maxLoops = if (endOfStream) 300 else 10
                    if (idleLoops > maxLoops) return
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    if (!muxerStarted) {
                        trackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                }
                index >= 0 -> {
                    idleLoops = 0
                    val encodedData = codec.getOutputBuffer(index)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
                        bufferInfo.size = 0
                    }
                    if (encodedData != null && bufferInfo.size > 0 && muxerStarted) {
                        // Gán mốc thời gian đều theo FPS (vì Flutter dựng khung hình theo từng bước)
                        bufferInfo.presentationTimeUs = outFrameCount * 1_000_000L / fps
                        outFrameCount++
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, encodedData, bufferInfo)
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }

    private fun release() {
        try { codec.stop() } catch (_: Exception) {}
        try { codec.release() } catch (_: Exception) {}
        try { inputSurface.release() } catch (_: Exception) {}
        try { if (muxerStarted) muxer.stop() } catch (_: Exception) {}
        try { muxer.release() } catch (_: Exception) {}
        frameBitmap?.recycle()
        frameBitmap = null
    }
}

/** Lưu vào Thư viện ảnh & chia sẻ thẳng lên Instagram Story kèm toàn bộ template đã chọn. */
object StoryShareHelper {
    private const val INSTAGRAM_PKG = "com.instagram.android"

    fun isInstagramInstalled(activity: Activity): Boolean {
        return try {
            activity.packageManager.getPackageInfo(INSTAGRAM_PKG, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Lưu file vào Thư viện (Pictures/Orbit hoặc Movies/Orbit). Trả về true nếu thành công. */
    fun saveToGallery(activity: Activity, file: File, mime: String): Boolean {
        val isVideo = mime.startsWith("video")
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = activity.contentResolver
            val collection = if (isVideo) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    (if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES) + "/Orbit"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(collection, values) ?: return false
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(file).use { it.copyTo(out) }
                } ?: return false
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                true
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                false
            }
        } else {
            // Android 9 trở xuống: cần quyền WRITE_EXTERNAL_STORAGE
            try {
                @Suppress("DEPRECATION")
                val baseDir = Environment.getExternalStoragePublicDirectory(
                    if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES
                )
                val dir = File(baseDir, "Orbit").apply { mkdirs() }
                val dest = File(dir, file.name)
                file.copyTo(dest, overwrite = true)
                MediaScannerConnection.scanFile(activity, arrayOf(dest.absolutePath), arrayOf(mime), null)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun uriFor(activity: Activity, file: File): Uri =
        FileProvider.getUriForFile(activity, "${activity.packageName}.fileprovider", file)

    /**
     * Mở thẳng trình soạn Story của Instagram kèm theo file video/ảnh của template đã chọn.
     * Bắt buộc gắn cả `EXTRA_STREAM`, `ClipData` và `setDataAndType` để Instagram trên Android 10–15+
     * có quyền đọc URI và nạp sẵn template làm nền Story (không bị mở màn hình trống).
     */
    fun shareToInstagramStory(activity: Activity, file: File, mime: String): String {
        val uri = uriFor(activity, file)
        val clip = ClipData.newRawUri("orbit_story", uri)
        val pm = activity.packageManager

        if (isInstagramInstalled(activity)) {
            activity.grantUriPermission(INSTAGRAM_PKG, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

            // 1. Ưu tiên mở trực tiếp StoryShareHandlerActivity với EXTRA_STREAM + ClipData
            // Đây là luồng chuẩn khi chia sẻ từ Bộ sưu tập vào "Tin (Stories)" của Instagram:
            // nạp thẳng video/ảnh template vào trình sửa Story mà không cần Facebook App ID.
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = clip
                setPackage(INSTAGRAM_PKG)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            @Suppress("DEPRECATION")
            val handlers = pm.queryIntentActivities(sendIntent, 0)
            val storyHandler = handlers.firstOrNull {
                it.activityInfo.name.contains("story", ignoreCase = true)
            }
            if (storyHandler != null) {
                try {
                    val direct = Intent(Intent.ACTION_SEND).apply {
                        type = mime
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = clip
                        setClassName(storyHandler.activityInfo.packageName, storyHandler.activityInfo.name)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(direct)
                    return "story"
                } catch (_: Exception) {}
            }

            // 2. Thử Intent chuyên biệt com.instagram.share.ADD_TO_STORY (truyền nền qua setDataAndType)
            try {
                val addToStory = Intent("com.instagram.share.ADD_TO_STORY").apply {
                    setDataAndType(uri, mime)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra("source_application", activity.packageName)
                    clipData = clip
                    setPackage(INSTAGRAM_PKG)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                if (addToStory.resolveActivity(pm) != null) {
                    activity.startActivity(addToStory)
                    return "story"
                }
            } catch (_: Exception) {}

            // 3. Dự phòng: gửi vào Instagram, Instagram tự hiện lựa chọn Story/Feed/Reels kèm sẵn template
            try {
                activity.startActivity(sendIntent)
                return "instagram"
            } catch (_: Exception) {}
        }

        // 4. Chưa cài Instagram: mở bảng chia sẻ hệ thống kèm sẵn file template
        shareGeneric(activity, file, mime)
        return "chooser"
    }

    fun shareGeneric(activity: Activity, file: File, mime: String) {
        val uri = uriFor(activity, file)
        val clip = ClipData.newRawUri("orbit_story", uri)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(intent, "Chia sẻ Story Orbit").apply {
            clipData = clip
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(chooser)
    }
}
