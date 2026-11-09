package ir.hesabyar.domain.rates

import kotlin.math.abs

/**
 * Guards the cache against a broken feed: a zero price or a 10× unit mistake (Toman sent as
 * Rial) must never overwrite a good cached price that calculators and goals depend on.
 */
object RateSanity {

    enum class Verdict { OK, SUSPICIOUS_JUMP, INVALID }

    /** Plausible Rial bounds per instrument family — wide on purpose (years of inflation headroom). */
    data class Bounds(val minRial: Long, val maxRial: Long)

    fun check(newRial: Long, previousRial: Long?, bounds: Bounds? = null, maxJumpPercent: Double = 40.0): Verdict {
        if (newRial <= 0) return Verdict.INVALID
        if (bounds != null && newRial !in bounds.minRial..bounds.maxRial) return Verdict.INVALID
        if (previousRial != null && previousRial > 0) {
            val change = abs(newRial - previousRial) * 100.0 / previousRial
            if (change > maxJumpPercent) return Verdict.SUSPICIOUS_JUMP
        }
        return Verdict.OK
    }

    fun isStale(fetchedAtMillis: Long, nowMillis: Long, maxAgeMillis: Long = 6 * 3_600_000L): Boolean =
        nowMillis - fetchedAtMillis > maxAgeMillis
}
