package ir.hesabyar.app.ui.tools

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.appContainer
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.BannerSlot
import ir.hesabyar.app.ui.components.RewardedUnlockDialog
import ir.hesabyar.app.ui.components.findActivity
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.ads.AppSurface
import ir.hesabyar.domain.ads.RewardedFeature

/** Reports & settings. Monetized with one bottom banner + the rewarded Excel/PDF export gate. */
@Composable
fun ReportsScreen(contentPadding: PaddingValues) {
    val context = LocalContext.current
    val ads = context.appContainer.ads
    var askExport by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(bottom = contentPadding.calculateBottomPadding())) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("گزارش‌ها و تنظیمات", style = MaterialTheme.typography.titleLarge)
            AppCard { Text("نمودار دخل و خرج ماهانه (گام ۵)", style = MaterialTheme.typography.titleSmall) }
            AppCard(onClick = {
                if (ads.isUnlocked(RewardedFeature.EXPORT_EXCEL_PDF)) Toast.makeText(context, "خروجی Excel/PDF در گام ۵ پیاده‌سازی می‌شود", Toast.LENGTH_SHORT).show()
                else askExport = true
            }) {
                Text("خروجی Excel و PDF", style = MaterialTheme.typography.titleSmall)
                Text("رایگان با تماشای یک ویدیوی کوتاه", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.gold)
            }
            AppCard { Text("پشتیبان‌گیری رمزنگاری‌شده و بازیابی (گام ۵)", style = MaterialTheme.typography.titleSmall) }
            AppCard { Text("قفل اثر انگشت / رمز ۴ رقمی (گام ۵)", style = MaterialTheme.typography.titleSmall) }
            AppCard { Text("شروع سال مالی جدید (گام ۵)", style = MaterialTheme.typography.titleSmall) }
        }
        BannerSlot(AdSlot.BANNER_REPORTS_BOTTOM)
    }

    if (askExport) {
        RewardedUnlockDialog(
            RewardedFeature.EXPORT_EXCEL_PDF,
            onWatch = {
                askExport = false
                context.findActivity()?.let { activity ->
                    ads.watchToUnlock(activity, RewardedFeature.EXPORT_EXCEL_PDF, AppSurface.REPORTS) { ok ->
                        if (ok) Toast.makeText(context, "یک خروجی رایگان فعال شد", Toast.LENGTH_SHORT).show()
                    }
                }
            },
            onDismiss = { askExport = false },
        )
    }
}
