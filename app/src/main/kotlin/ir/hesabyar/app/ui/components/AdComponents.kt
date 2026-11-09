package ir.hesabyar.app.ui.components

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import ir.hesabyar.app.ads.NativeAd
import ir.hesabyar.app.appContainer
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.ads.RewardedFeature

/**
 * Native ad in the exact shape, font and colours of an AppCard, with a small «پیشنهاد ویژه»
 * tag. Renders *nothing* (no placeholder, no gap) when there is no fill.
 */
@Composable
fun NativeAdCard(slot: AdSlot, modifier: Modifier = Modifier, key: Any = Unit) {
    val ads = LocalContext.current.appContainer.ads
    var ad by remember(slot, key) { mutableStateOf<NativeAd?>(null) }
    LaunchedEffect(slot, key) { ad = ads.provider.loadNative(slot) }
    val loaded = ad ?: return
    LaunchedEffect(loaded) { loaded.onImpression() }

    AppCard(modifier = modifier, onClick = loaded.onClick) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                "پیشنهاد ویژه",
                style = MaterialTheme.typography.labelSmall,
                color = Navy,
                modifier = Modifier.clip(MaterialTheme.shapes.extraSmall).background(AppTheme.money.gold.copy(alpha = 0.25f))
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            )
            Spacer(Modifier.weight(1f))
            loaded.advertiser?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted) }
        }
        Spacer(Modifier.height(8.dp))
        Text(loaded.headline, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(loaded.body, style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = loaded.onClick, modifier = Modifier.height(36.dp)) {
            Text(loaded.callToAction, style = MaterialTheme.typography.labelMedium)
        }
    }
}

/** Standard 320×50 banner. Only placed at the very bottom of report / calculator screens. */
@Composable
fun BannerSlot(slot: AdSlot, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val view = remember(slot) { context.appContainer.ads.provider.createBanner(context, slot) } ?: return
    Box(modifier.fillMaxWidth().padding(vertical = 4.dp), contentAlignment = Alignment.Center) {
        AndroidView(factory = { view }, modifier = Modifier.width(320.dp).height(50.dp))
    }
}

/**
 * Consent step before any rewarded video. The ad only starts after an explicit tap on the
 * full-text button; «بعداً» is always available and never penalised.
 */
@Composable
fun RewardedUnlockDialog(
    feature: RewardedFeature,
    onWatch: () -> Unit,
    onDismiss: () -> Unit,
) {
    val detail = when (feature) {
        RewardedFeature.VOICE_ASSISTANT, RewardedFeature.INFLATION_SHIELD -> "به مدت ۲۴ ساعت رایگان فعال می‌شود."
        RewardedFeature.EXPORT_EXCEL_PDF -> "یک خروجی کامل رایگان دریافت می‌کنید."
        RewardedFeature.EXTRA_LEDGER -> "یک دفتر حسابداری جدید برای همیشه اضافه می‌شود."
    }
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(AppIcons.Shield, contentDescription = null, tint = AppTheme.money.gold, modifier = Modifier.size(32.dp)) },
        title = { Text(feature.title, style = MaterialTheme.typography.titleMedium) },
        text = { Text("با تماشای یک ویدیوی کوتاه (۱۵ تا ۳۰ ثانیه) $detail", style = MaterialTheme.typography.bodyMedium) },
        confirmButton = {
            Button(onClick = onWatch, colors = ButtonDefaults.buttonColors(containerColor = Navy)) {
                Text("تماشای ویدیوی کوتاه و فعال‌سازی رایگان")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("بعداً") } },
    )
}

tailrec fun android.content.Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is android.content.ContextWrapper -> baseContext.findActivity()
    else -> null
}
