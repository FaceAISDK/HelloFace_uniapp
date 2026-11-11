package uts.sdk.modules.HelloFaceVerify

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** 仅保存 1:1 基准；AES 密钥不离开 Android Keystore。
 * 密文格式为版本字节 + 12 字节 IV + GCM 密文/标签；AAD 绑定模型与 faceID，不能跨账号挪用。
 */
internal class ReferenceStore(context: Context) {
    private val preferences = context.getSharedPreferences("helloface.references.v1", Context.MODE_PRIVATE)
    private val alias = "helloface.references.aes.v1"
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
        }.generateKey()
    }
    private fun account(faceID: String) = "jdx-feature-v1:$faceID"
    fun get(faceID: String): String? {
        val encoded = preferences.getString(account(faceID), null) ?: return null
        val data = Base64.decode(encoded, Base64.NO_WRAP)
        require(data.size > 29 && data[0] == 1.toByte()) { "Invalid reference envelope" }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, data.copyOfRange(1, 13)))
        cipher.updateAAD(account(faceID).toByteArray(Charsets.UTF_8))
        val clear = cipher.doFinal(data.copyOfRange(13, data.size))
        return try { String(clear, Charsets.UTF_8) } finally { clear.fill(0) }
    }
    fun save(faceID: String, feature: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(account(faceID).toByteArray(Charsets.UTF_8))
        val clear = feature.toByteArray(Charsets.UTF_8)
        val encrypted = try { cipher.doFinal(clear) } finally { clear.fill(0) }
        check(preferences.edit().putString(account(faceID),
            Base64.encodeToString(byteArrayOf(1) + cipher.iv + encrypted, Base64.NO_WRAP)).commit()) {
            "Unable to save face reference"
        }
    }
    fun delete(faceID: String) {
        check(preferences.edit().remove(account(faceID)).commit()) { "Unable to delete face reference" }
    }
}
