package ir.hesabyar.app.ui.tools

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.NativeAdCard
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdSlot

/**
 * Step-1 shell of the tools tab, wired with its ad slot: the native card sits directly under the
 * gold/coin price table (highest-CTR spot for gold & exchange advertisers). Calculators land in step 3,
 * each with its own bottom banner (BANNER_GOLD_CALC_BOTTOM / BANNER_LOAN_CALC_BOTTOM).
 */
@Composable
fun ToolsScreen(contentPadding: PaddingValues) {
    Column(
        Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = contentPadding.calculateBottomPadding() + 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("ابزارهای مالی و طلا", style = MaterialTheme.typography.titleLarge)
        AppCard {
            Text("جدول نرخ طلا، سکه و ارز", style = MaterialTheme.typography.titleMedium)
            Text("نرخ لحظه‌ای + حباب سکه (گام ۳)", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
        }
        NativeAdCard(AdSlot.NATIVE_TOOLS_UNDER_RATES)
        ToolEntry("ماشین‌حساب طلای ۱۸ عیار", "وزن، اجرت، سود فروشنده تا ۷٪ و مالیات ۹٪")
        ToolEntry("ماشین‌حساب وام و اقساط", "فرمول قدیم و جدید بانکی")
        ToolEntry("هدف پس‌انداز ضدتورم", "هدف‌گذاری با گرم طلا یا دلار به‌جای تومان")
        ToolEntry("ماشین‌حساب دنگ", "تقسیم هزینه و ثبت در طلب و بدهی")
    }
}

@Composable
private fun ToolEntry(title: String, subtitle: String) {
    AppCard {
        Text(title, style = MaterialTheme.typography.titleSmall)
        Text(subtitle, style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
    }
}
