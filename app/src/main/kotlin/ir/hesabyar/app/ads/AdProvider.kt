package ir.hesabyar.app.ads

import android.app.Activity
import android.content.Context
import android.view.View
import ir.hesabyar.domain.ads.AdFormat
import ir.hesabyar.domain.ads.AdPolicy
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.ads.AppSurface

/** Content an SDK adapter hands to [NativeAdCard]. The card renders it in the app's own style. */
data class NativeAd(
    val headline: String,
    val body: String,
    val callToAction: String,
    val advertiser: String? = null,
    /** Called once when the card is actually on screen (SDK impression tracking). */
    val onImpression: () -> Unit = {},
    val onClick: () -> Unit = {},
)

enum class RewardOutcome { REWARDED, CLOSED_EARLY, NO_FILL, ERROR }

/**
 * Network-agnostic ad facade. Tapsell Mediation / Adivery / AdMob adapters implement this in
 * step 4; the rest of the app only ever sees this interface.
 */
interface AdProvider {
    suspend fun loadNative(slot: AdSlot): NativeAd?
    fun showRewarded(activity: Activity, onResult: (RewardOutcome) -> Unit)
    fun createBanner(context: Context, slot: AdSlot): View?
}

/**
 * Hard gate in front of every adapter: even a buggy screen cannot show an ad where
 * [AdPolicy] forbids it.
 */
class PolicedAdProvider(private val delegate: AdProvider) {

    suspend fun loadNative(slot: AdSlot): NativeAd? =
        if (slot.format == AdFormat.NATIVE && AdPolicy.isAllowed(slot)) delegate.loadNative(slot) else null

    fun createBanner(context: Context, slot: AdSlot): View? =
        if (slot.format == AdFormat.BANNER && AdPolicy.isAllowed(slot)) delegate.createBanner(context, slot) else null

    /** [surface] = screen the user tapped «تماشای ویدیو» on; always user initiated. */
    fun showRewarded(activity: Activity, surface: AppSurface, onResult: (RewardOutcome) -> Unit) {
        if (!AdPolicy.isAllowed(surface, AdFormat.REWARDED, userInitiated = true)) {
            onResult(RewardOutcome.ERROR); return
        }
        delegate.showRewarded(activity, onResult)
    }
}

/** Release build until a network SDK is wired: no ads at all. */
object NoAdProvider : AdProvider {
    override suspend fun loadNative(slot: AdSlot): NativeAd? = null
    override fun showRewarded(activity: Activity, onResult: (RewardOutcome) -> Unit) = onResult(RewardOutcome.NO_FILL)
    override fun createBanner(context: Context, slot: AdSlot): View? = null
}
