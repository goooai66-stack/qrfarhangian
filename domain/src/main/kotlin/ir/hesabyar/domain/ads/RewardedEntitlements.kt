package ir.hesabyar.domain.ads

private const val DAY_MS = 24 * 3_600_000L

/** Features unlocked by watching a rewarded video instead of paying. */
enum class RewardedFeature(val title: String, val grant: Grant) {
    EXPORT_EXCEL_PDF("خروجی Excel و PDF حرفه‌ای", Grant.Credits(1)),
    VOICE_ASSISTANT("دستیار صوتی ثبت تراکنش", Grant.Duration(DAY_MS)),
    INFLATION_SHIELD("تحلیل سپر ضدتورم و مقایسه با طلا", Grant.Duration(DAY_MS)),
    EXTRA_LEDGER("ساخت دفتر حسابداری اضافه", Grant.PermanentSlot(1));

    sealed interface Grant {
        /** N uses, consumed one by one. */
        data class Credits(val count: Int) : Grant
        /** Unlimited use until now + millis (stacks when watched again). */
        data class Duration(val millis: Long) : Grant
        /** Permanently raises a quota (e.g. +1 ledger beyond the free 2). */
        data class PermanentSlot(val count: Int) : Grant
    }


}

/**
 * Pure entitlement state; persisted by the app (SharedPreferences) as three maps.
 */
data class Entitlements(
    val expiresAt: Map<RewardedFeature, Long> = emptyMap(),
    val credits: Map<RewardedFeature, Int> = emptyMap(),
    val extraSlots: Map<RewardedFeature, Int> = emptyMap(),
) {
    fun isActive(feature: RewardedFeature, now: Long): Boolean = when (feature.grant) {
        is RewardedFeature.Grant.Credits -> (credits[feature] ?: 0) > 0
        is RewardedFeature.Grant.Duration -> (expiresAt[feature] ?: 0L) > now
        is RewardedFeature.Grant.PermanentSlot -> (extraSlots[feature] ?: 0) > 0
    }

    fun remainingMillis(feature: RewardedFeature, now: Long): Long = ((expiresAt[feature] ?: 0L) - now).coerceAtLeast(0)

    fun grant(feature: RewardedFeature, now: Long): Entitlements = when (val g = feature.grant) {
        is RewardedFeature.Grant.Credits -> copy(credits = credits + (feature to (credits[feature] ?: 0) + g.count))
        is RewardedFeature.Grant.Duration -> {
            val base = maxOf(now, expiresAt[feature] ?: 0L)
            copy(expiresAt = expiresAt + (feature to base + g.millis))
        }
        is RewardedFeature.Grant.PermanentSlot -> copy(extraSlots = extraSlots + (feature to (extraSlots[feature] ?: 0) + g.count))
    }

    /** Consumes one credit (Credits grants only). Returns null if nothing to consume. */
    fun consume(feature: RewardedFeature): Entitlements? {
        if (feature.grant !is RewardedFeature.Grant.Credits) return this
        val left = credits[feature] ?: 0
        if (left <= 0) return null
        return copy(credits = credits + (feature to left - 1))
    }

    fun ledgerQuota(freeLedgers: Int = FREE_LEDGERS): Int = freeLedgers + (extraSlots[RewardedFeature.EXTRA_LEDGER] ?: 0)

    companion object { const val FREE_LEDGERS = 2 }
}
