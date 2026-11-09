package ir.hesabyar.app.ads

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.TextView
import ir.hesabyar.domain.ads.AdSlot

/** Debug-only stand-in so designers can see every placement without an SDK or network. */
class FakeAdProvider : AdProvider {

    override suspend fun loadNative(slot: AdSlot): NativeAd = when (slot) {
        AdSlot.NATIVE_TOOLS_UNDER_RATES -> NativeAd(
            headline = "خرید طلای آب‌شده از ۱۰۰ هزار تومان",
            body = "نمونه تبلیغ همسان — جایگاه زیر جدول نرخ طلا و سکه",
            callToAction = "مشاهده",
            advertiser = "تبلیغ نمونه",
        )
        else -> NativeAd(
            headline = "نمونه تبلیغ همسان",
            body = "این کارت هر ۱۰ تراکنش یک بار و هم‌رنگ لیست نمایش داده می‌شود",
            callToAction = "بیشتر",
            advertiser = "تبلیغ نمونه",
        )
    }

    override fun showRewarded(activity: Activity, onResult: (RewardOutcome) -> Unit) {
        AlertDialog.Builder(activity)
            .setTitle("ویدیوی جایزه‌دار (نمونه)")
            .setMessage("در نسخه نهایی اینجا ویدیوی ۱۵ تا ۳۰ ثانیه‌ای پخش می‌شود.")
            .setPositiveButton("دیدم") { _, _ -> onResult(RewardOutcome.REWARDED) }
            .setNegativeButton("بستن") { _, _ -> onResult(RewardOutcome.CLOSED_EARLY) }
            .setOnCancelListener { onResult(RewardOutcome.CLOSED_EARLY) }
            .show()
    }

    override fun createBanner(context: Context, slot: AdSlot): View = TextView(context).apply {
        text = "بنر نمونه ۳۲۰×۵۰"
        gravity = Gravity.CENTER
        setTextColor(Color.parseColor("#6B7280"))
        setBackgroundColor(Color.parseColor("#EFEAE0"))
    }
}
