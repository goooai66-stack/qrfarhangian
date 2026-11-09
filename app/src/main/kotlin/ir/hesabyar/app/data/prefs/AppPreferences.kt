package ir.hesabyar.app.data.prefs

import android.content.Context
import ir.hesabyar.domain.ads.Entitlements
import ir.hesabyar.domain.ads.RewardedFeature
import ir.hesabyar.domain.security.PinAttemptPolicy
import ir.hesabyar.domain.security.PinHasher
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Small key-value settings. SharedPreferences (not DataStore) to keep the APK lean. */
class AppPreferences(context: Context) {

    private val sp = context.getSharedPreferences("hesabyar_prefs", Context.MODE_PRIVATE)

    private val _activeLedgerId = MutableStateFlow(sp.getLong(KEY_LEDGER, 0L))
    /** 0 = "not chosen yet" → the UI falls back to the first ledger. */
    val activeLedgerId: StateFlow<Long> = _activeLedgerId.asStateFlow()

    fun setActiveLedger(id: Long) {
        sp.edit().putLong(KEY_LEDGER, id).apply()
        _activeLedgerId.value = id
    }

    var onboardingDone: Boolean
        get() = sp.getBoolean(KEY_ONBOARDING, false)
        set(v) { sp.edit().putBoolean(KEY_ONBOARDING, v).apply() }

    /** Hour (Tehran) of the single daily due-date check. */
    var reminderHour: Int
        get() = sp.getInt(KEY_REMINDER_HOUR, 9)
        set(v) { sp.edit().putInt(KEY_REMINDER_HOUR, v.coerceIn(0, 23)).apply() }

    /**
     * Reminder de-duplication: "epochDay|key" entries. A reminder fires once per item, due date
     * and offset, no matter how often the check runs (alarm, boot, after editing a cheque).
     */
    fun wasNotified(key: String): Boolean = sp.getStringSet(KEY_NOTIFIED, emptySet())!!.any { it.substringAfter('|') == key }

    fun markNotified(key: String, todayEpochDay: Long) {
        val keep = sp.getStringSet(KEY_NOTIFIED, emptySet())!!.filter { (it.substringBefore('|').toLongOrNull() ?: 0) >= todayEpochDay - 7 }
        sp.edit().putStringSet(KEY_NOTIFIED, (keep + "$todayEpochDay|$key").toSet()).apply()
    }

    // ---------------------------------------------------------------- app lock
    /** Salted PBKDF2 hash of the 4-digit PIN; null = lock disabled. */
    var pinHash: PinHasher.Hashed?
        get() {
            val salt = sp.getString(KEY_PIN_SALT, null) ?: return null
            val hash = sp.getString(KEY_PIN_HASH, null) ?: return null
            return PinHasher.Hashed(salt, hash, sp.getInt(KEY_PIN_ITER, 20_000))
        }
        set(v) {
            sp.edit().apply {
                if (v == null) { remove(KEY_PIN_SALT); remove(KEY_PIN_HASH); remove(KEY_PIN_ITER); putBoolean(KEY_BIOMETRIC, false) }
                else { putString(KEY_PIN_SALT, v.saltHex); putString(KEY_PIN_HASH, v.hashHex); putInt(KEY_PIN_ITER, v.iterations) }
            }.apply()
            _lockEnabled.value = v != null
        }

    private val _lockEnabled = MutableStateFlow(sp.contains(KEY_PIN_HASH))
    val lockEnabled: StateFlow<Boolean> = _lockEnabled.asStateFlow()

    var biometricEnabled: Boolean
        get() = sp.getBoolean(KEY_BIOMETRIC, false) && pinHash != null
        set(v) { sp.edit().putBoolean(KEY_BIOMETRIC, v).apply() }

    /** Seconds in background before re-locking; -1 = only on a cold start. */
    var lockTimeoutSec: Int
        get() = sp.getInt(KEY_LOCK_TIMEOUT, 30)
        set(v) { sp.edit().putInt(KEY_LOCK_TIMEOUT, v).apply() }

    var pinAttempts: PinAttemptPolicy
        get() = PinAttemptPolicy(sp.getInt(KEY_PIN_FAILS, 0), sp.getLong(KEY_PIN_LOCKED_UNTIL, 0))
        set(v) { sp.edit().putInt(KEY_PIN_FAILS, v.failures).putLong(KEY_PIN_LOCKED_UNTIL, v.lockedUntilMillis).apply() }

    private val _secureScreen = MutableStateFlow(sp.getBoolean(KEY_SECURE, false))
    /** FLAG_SECURE: hides balances from the recent-apps switcher and blocks screenshots. */
    val secureScreen: StateFlow<Boolean> = _secureScreen.asStateFlow()
    fun setSecureScreen(v: Boolean) { sp.edit().putBoolean(KEY_SECURE, v).apply(); _secureScreen.value = v }

    private val _entitlements = MutableStateFlow(readEntitlements())
    val entitlements: StateFlow<Entitlements> = _entitlements.asStateFlow()

    fun saveEntitlements(e: Entitlements) {
        sp.edit()
            .putString(KEY_ENT_EXPIRES, encode(e.expiresAt))
            .putString(KEY_ENT_CREDITS, encode(e.credits))
            .putString(KEY_ENT_SLOTS, encode(e.extraSlots))
            .apply()
        _entitlements.value = e
    }

    private fun readEntitlements() = Entitlements(
        expiresAt = decode(sp.getString(KEY_ENT_EXPIRES, null)) { it.toLong() },
        credits = decode(sp.getString(KEY_ENT_CREDITS, null)) { it.toInt() },
        extraSlots = decode(sp.getString(KEY_ENT_SLOTS, null)) { it.toInt() },
    )

    private fun <V> encode(map: Map<RewardedFeature, V>) = map.entries.joinToString(";") { "${it.key.name}=${it.value}" }

    private fun <V> decode(raw: String?, parse: (String) -> V): Map<RewardedFeature, V> =
        raw.orEmpty().split(';').mapNotNull { part ->
            val (k, v) = part.split('=').takeIf { it.size == 2 } ?: return@mapNotNull null
            val feature = RewardedFeature.entries.firstOrNull { it.name == k } ?: return@mapNotNull null
            runCatching { feature to parse(v) }.getOrNull()
        }.toMap()

    private companion object {
        const val KEY_LEDGER = "active_ledger"
        const val KEY_ONBOARDING = "onboarding_done"
        const val KEY_REMINDER_HOUR = "reminder_hour"
        const val KEY_PIN_SALT = "pin_salt"
        const val KEY_PIN_HASH = "pin_hash"
        const val KEY_PIN_ITER = "pin_iter"
        const val KEY_BIOMETRIC = "lock_biometric"
        const val KEY_LOCK_TIMEOUT = "lock_timeout"
        const val KEY_PIN_FAILS = "pin_fails"
        const val KEY_PIN_LOCKED_UNTIL = "pin_locked_until"
        const val KEY_SECURE = "secure_screen"
        const val KEY_NOTIFIED = "reminders_notified"
        const val KEY_ENT_EXPIRES = "ent_expires"
        const val KEY_ENT_CREDITS = "ent_credits"
        const val KEY_ENT_SLOTS = "ent_slots"
    }
}
