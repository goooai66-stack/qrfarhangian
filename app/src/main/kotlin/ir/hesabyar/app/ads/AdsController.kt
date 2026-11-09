package ir.hesabyar.app.ads

import android.app.Activity
import ir.hesabyar.app.data.prefs.AppPreferences
import ir.hesabyar.domain.ads.AppSurface
import ir.hesabyar.domain.ads.Entitlements
import ir.hesabyar.domain.ads.RewardedFeature
import kotlinx.coroutines.flow.StateFlow

/** Glue between the rewarded flow and persisted entitlements. */
class AdsController(
    val provider: PolicedAdProvider,
    private val prefs: AppPreferences,
    /** Goodwill: if the network has no ad to show, unlock anyway — never punish the user for no fill. */
    private val grantOnNoFill: Boolean = true,
) {
    val entitlements: StateFlow<Entitlements> = prefs.entitlements

    fun isUnlocked(feature: RewardedFeature, now: Long = System.currentTimeMillis()) =
        entitlements.value.isActive(feature, now)

    fun watchToUnlock(activity: Activity, feature: RewardedFeature, surface: AppSurface, onDone: (Boolean) -> Unit) {
        provider.showRewarded(activity, surface) { outcome ->
            val granted = outcome == RewardOutcome.REWARDED || (grantOnNoFill && outcome == RewardOutcome.NO_FILL)
            if (granted) prefs.saveEntitlements(entitlements.value.grant(feature, System.currentTimeMillis()))
            onDone(granted)
        }
    }

    /** For credit-based features (Excel/PDF export): call right before performing the export. */
    fun consume(feature: RewardedFeature): Boolean {
        val next = entitlements.value.consume(feature) ?: return false
        prefs.saveEntitlements(next)
        return true
    }
}
