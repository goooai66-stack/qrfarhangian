package ir.hesabyar.domain.ads

/**
 * Single source of truth for *where* ads may appear. UI code never decides on its own: it asks
 * [AdPolicy.isAllowed]. The rules encode the product promise — the user reaches "add
 * transaction" in under a second and is never ambushed while handling money.
 */
enum class AdFormat { NATIVE, REWARDED, BANNER, INTERSTITIAL, APP_OPEN }

enum class AppSurface {
    // ---- ad-free zones
    APP_START, LOCK_SCREEN, TRANSACTION_FORM, SMS_CONFIRMATION, CALCULATOR_KEYBOARD, DUE_REMINDER_ALERT,
    ONBOARDING,
    // ---- dashboard: luxurious & clean — only user-initiated rewarded unlocks
    DASHBOARD,
    // ---- monetized
    TRANSACTIONS_LIST, DUE_DATES, TOOLS_HOME, GOLD_CALCULATOR, LOAN_CALCULATOR, REPORTS, SETTINGS,
}

/** Concrete ad units. Each maps to one SDK zone id in the ad adapter. */
enum class AdSlot(val surface: AppSurface, val format: AdFormat) {
    NATIVE_TRANSACTIONS_FEED(AppSurface.TRANSACTIONS_LIST, AdFormat.NATIVE),
    NATIVE_TOOLS_UNDER_RATES(AppSurface.TOOLS_HOME, AdFormat.NATIVE),
    BANNER_REPORTS_BOTTOM(AppSurface.REPORTS, AdFormat.BANNER),
    BANNER_GOLD_CALC_BOTTOM(AppSurface.GOLD_CALCULATOR, AdFormat.BANNER),
    BANNER_LOAN_CALC_BOTTOM(AppSurface.LOAN_CALCULATOR, AdFormat.BANNER),
    REWARDED_UNLOCK(AppSurface.DASHBOARD, AdFormat.REWARDED), // surface = where the dialog opens
}

object AdPolicy {

    const val NATIVE_EVERY_N_ROWS = 10

    private val adFree = setOf(
        AppSurface.APP_START, AppSurface.LOCK_SCREEN, AppSurface.TRANSACTION_FORM,
        AppSurface.SMS_CONFIRMATION, AppSurface.CALCULATOR_KEYBOARD, AppSurface.DUE_REMINDER_ALERT,
        AppSurface.ONBOARDING,
    )

    private val allowed: Map<AppSurface, Set<AdFormat>> = mapOf(
        AppSurface.DASHBOARD to setOf(AdFormat.REWARDED),
        AppSurface.TRANSACTIONS_LIST to setOf(AdFormat.NATIVE, AdFormat.REWARDED),
        AppSurface.TOOLS_HOME to setOf(AdFormat.NATIVE, AdFormat.REWARDED),
        AppSurface.GOLD_CALCULATOR to setOf(AdFormat.BANNER),
        AppSurface.LOAN_CALCULATOR to setOf(AdFormat.BANNER),
        AppSurface.REPORTS to setOf(AdFormat.BANNER, AdFormat.REWARDED),
        AppSurface.DUE_DATES to setOf(AdFormat.REWARDED),
        AppSurface.SETTINGS to setOf(AdFormat.REWARDED),
    )

    /**
     * @param userInitiated rewarded ads are only legal after the user tapped an explicit
     *   «تماشای ویدیو» button. Interstitial and app-open formats are never allowed anywhere.
     */
    fun isAllowed(surface: AppSurface, format: AdFormat, userInitiated: Boolean = false): Boolean {
        if (format == AdFormat.INTERSTITIAL || format == AdFormat.APP_OPEN) return false
        if (surface in adFree) return false
        if (format == AdFormat.REWARDED && !userInitiated) return false
        return format in allowed[surface].orEmpty()
    }

    fun isAllowed(slot: AdSlot): Boolean = isAllowed(slot.surface, slot.format, userInitiated = slot.format == AdFormat.REWARDED)

    /**
     * Interleaves one ad after every [every] content rows: 10 rows, ad, 10 rows, ad …
     * No ad is appended after a short tail, and lists shorter than [every] get none — an ad
     * must never be the most prominent thing on a near-empty screen.
     */
    fun <T, R> interleave(items: List<T>, every: Int = NATIVE_EVERY_N_ROWS, row: (T) -> R, ad: (adIndex: Int) -> R): List<R> {
        require(every > 0)
        val out = ArrayList<R>(items.size + items.size / every)
        var adIndex = 0
        items.forEachIndexed { i, item ->
            out += row(item)
            if ((i + 1) % every == 0 && i != items.lastIndex) out += ad(adIndex++)
        }
        return out
    }
}
