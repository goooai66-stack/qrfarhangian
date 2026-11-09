package ir.hesabyar.domain.security

import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

private val random = SecureRandom()

/**
 * PBKDF2WithHmacSHA256 only exists on Android 26+; minSdk is 23. HMAC-SHA1 is available
 * everywhere and, used as the PRF inside PBKDF2 (not as a plain hash), is still sound.
 * Same algorithm on the JVM tests and on every device.
 */
private fun pbkdf2(password: CharArray, salt: ByteArray, iterations: Int, bits: Int = 256): ByteArray =
    SecretKeyFactory.getInstance("PBKDF2WithHmacSHA1").generateSecret(PBEKeySpec(password, salt, iterations, bits)).encoded

/** Hex instead of java.util.Base64 (API 26+). */
internal fun ByteArray.toHex(): String = joinToString("") { "%02x".format(it) }
internal fun String.fromHex(): ByteArray = chunked(2).map { it.toInt(16).toByte() }.toByteArray()

/**
 * App-lock PIN: salted PBKDF2, never stored in clear. A 4-digit PIN has only 10⁴ values, so the
 * real protection is [PinAttemptPolicy] + Android's app sandbox; hashing just keeps the PIN out of
 * plain sight in a rooted device's prefs file or a stray backup.
 */
object PinHasher {
    private const val ITERATIONS = 20_000
    data class Hashed(val saltHex: String, val hashHex: String, val iterations: Int = ITERATIONS)

    fun hash(pin: String): Hashed {
        require(isValidFormat(pin))
        val salt = ByteArray(16).also(random::nextBytes)
        return Hashed(salt.toHex(), pbkdf2(pin.toCharArray(), salt, ITERATIONS).toHex())
    }

    fun verify(pin: String, stored: Hashed): Boolean {
        if (!isValidFormat(pin)) return false
        val actual = runCatching { pbkdf2(pin.toCharArray(), stored.saltHex.fromHex(), stored.iterations) }.getOrNull() ?: return false
        return MessageDigest.isEqual(actual, stored.hashHex.fromHex())
    }

    fun isValidFormat(pin: String) = pin.length == 4 && pin.all { it in '0'..'9' }
}

/**
 * Wrong-PIN throttling: 5 free attempts, then 30 s, doubling per further failure up to 5 min.
 * State is persisted by the app so killing the app does not reset the counter.
 */
data class PinAttemptPolicy(val failures: Int = 0, val lockedUntilMillis: Long = 0) {
    fun isLocked(now: Long) = now < lockedUntilMillis
    fun remainingMillis(now: Long) = (lockedUntilMillis - now).coerceAtLeast(0)

    fun onFailure(now: Long): PinAttemptPolicy {
        val f = failures + 1
        if (f < FREE_ATTEMPTS) return copy(failures = f)
        val delay = (BASE_DELAY_MS shl (f - FREE_ATTEMPTS).coerceAtMost(10)).coerceAtMost(MAX_DELAY_MS)
        return PinAttemptPolicy(f, now + delay)
    }

    fun onSuccess() = PinAttemptPolicy()

    companion object {
        const val FREE_ATTEMPTS = 5
        const val BASE_DELAY_MS = 30_000L
        const val MAX_DELAY_MS = 5 * 60_000L
    }
}

/**
 * Encrypted backup container: AES-256-GCM, key = PBKDF2(password, random salt).
 * Layout: "HSBK" | version(1) | iterations(int) | salt(16) | iv(12) | ciphertext+tag.
 * GCM authenticates, so a wrong password and a corrupted file are both detected — never a
 * silent restore of garbage into someone's books.
 */
object BackupCrypto {
    private val MAGIC = "HSBK".toByteArray(Charsets.US_ASCII)
    private const val VERSION: Byte = 1
    private const val ITERATIONS = 120_000

    class WrongPasswordOrCorrupt : Exception("wrong password or corrupt backup")
    class NotEncrypted : Exception("not an encrypted backup")

    fun isEncrypted(data: ByteArray) = data.size > MAGIC.size && data.copyOfRange(0, MAGIC.size).contentEquals(MAGIC)

    fun encrypt(plain: ByteArray, password: CharArray, iterations: Int = ITERATIONS): ByteArray {
        require(password.size >= 4) { "password too short" }
        val salt = ByteArray(16).also(random::nextBytes)
        val iv = ByteArray(12).also(random::nextBytes)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(Cipher.ENCRYPT_MODE, SecretKeySpec(pbkdf2(password, salt, iterations), "AES"), GCMParameterSpec(128, iv))
            updateAAD(MAGIC)
        }
        val ct = cipher.doFinal(plain)
        return ByteBuffer.allocate(MAGIC.size + 1 + 4 + salt.size + iv.size + ct.size)
            .put(MAGIC).put(VERSION).putInt(iterations).put(salt).put(iv).put(ct).array()
    }

    fun decrypt(data: ByteArray, password: CharArray): ByteArray {
        if (!isEncrypted(data)) throw NotEncrypted()
        val buf = ByteBuffer.wrap(data)
        buf.position(MAGIC.size)
        if (buf.get() != VERSION) throw WrongPasswordOrCorrupt()
        val iterations = buf.int
        if (iterations !in 1_000..10_000_000 || buf.remaining() < 16 + 12 + 16) throw WrongPasswordOrCorrupt()
        val salt = ByteArray(16).also { buf.get(it) }
        val iv = ByteArray(12).also { buf.get(it) }
        val ct = ByteArray(buf.remaining()).also { buf.get(it) }
        return try {
            Cipher.getInstance("AES/GCM/NoPadding").apply {
                init(Cipher.DECRYPT_MODE, SecretKeySpec(pbkdf2(password, salt, iterations), "AES"), GCMParameterSpec(128, iv))
                updateAAD(MAGIC)
            }.doFinal(ct)
        } catch (_: AEADBadTagException) {
            throw WrongPasswordOrCorrupt()
        }
    }
}
