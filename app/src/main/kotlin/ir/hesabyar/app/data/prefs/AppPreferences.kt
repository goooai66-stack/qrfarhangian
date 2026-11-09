package ir.hesabyar.app.data.prefs

import android.content.Context
import ir.hesabyar.domain.ads.Entitlements
import ir.hesabyar.domain.ads.RewardedFeature
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
        const val KEY_ENT_EXPIRES = "ent_expires"
        const val KEY_ENT_CREDITS = "ent_credits"
        const val KEY_ENT_SLOTS = "ent_slots"
    }
}
