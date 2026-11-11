package uts.sdk.modules.HelloFaceVerify

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.util.Base64
import androidx.exifinterface.media.ExifInterface
import com.hiface.sdk.HiFaceSdk
import java.io.ByteArrayInputStream

internal class ImageImportError(val code: String, override val message: String) : Exception(message)

/** No camera or aligned-preview dependency; the SDK owns feature extraction. */
internal object FaceImageImporter {
    fun extract(context: Context, encoded: String): String {
        val bitmap = decode(encoded)
        try {
            val sdk = HiFaceSdk.builder(context.applicationContext).build()
            try {
                val result = sdk.capture().extractFeatureBlocking(bitmap)
                if (result.isFailure) {
                    val error = result.requireError()
                    throw ImageImportError(error.code.name, error.message)
                }
                return result.requireValue()
            } finally { sdk.close() }
        } catch (error: ImageImportError) { throw error
        } catch (error: Exception) {
            throw ImageImportError("SDK_ERROR", error.message ?: "Unable to extract face feature")
        } finally { bitmap.recycle() }
    }

    private fun decode(encoded: String): Bitmap {
        try {
            if (encoded.length > 8388608) throw IllegalArgumentException("Image exceeds 6 MiB")
            val bytes = Base64.decode(encoded, Base64.NO_WRAP)
            val png = bytes.size >= 8 && bytes.take(8) == listOf(137, 80, 78, 71, 13, 10, 26, 10).map { it.toByte() }
            val jpeg = bytes.size >= 3 && bytes[0] == 0xff.toByte() && bytes[1] == 0xd8.toByte() && bytes[2] == 0xff.toByte()
            if (!png && !jpeg) throw IllegalArgumentException("Only PNG/JPEG are supported")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            val width = bounds.outWidth; val height = bounds.outHeight
            if (width !in 2..4096 || height !in 2..4096 || width.toLong() * height > 4194304) {
                throw IllegalArgumentException("Image must be 2..4096 px per side and at most 4194304 pixels")
            }
            val orientation = ByteArrayInputStream(bytes).use {
                ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            }
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 })
                ?: throw IllegalArgumentException("Unable to decode image")
            try {
                val matrix = Matrix()
                when (orientation) {
                    2 -> matrix.setScale(-1f, 1f)
                    3 -> matrix.setRotate(180f)
                    4 -> matrix.setScale(1f, -1f)
                    5 -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
                    6 -> matrix.setRotate(90f)
                    7 -> { matrix.setRotate(90f); matrix.postScale(1f, -1f) }
                    8 -> matrix.setRotate(270f)
                }
                val upright = Bitmap.createBitmap(bitmap, 0, 0, width, height, matrix, true)
                if (upright !== bitmap) bitmap.recycle()
                return upright
            } catch (error: Exception) { bitmap.recycle(); throw error }
        } catch (error: Exception) {
            throw ImageImportError("INVALID_IMAGE", error.message ?: "Unable to decode image")
        }
    }
}
