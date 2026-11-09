package ir.hesabyar.app.ui.tools

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.app.ui.common.formatWhen
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.BannerSlot
import ir.hesabyar.app.ui.components.NativeAdCard
import ir.hesabyar.app.ui.components.TextInput
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.rates.Coin
import ir.hesabyar.domain.rates.CoinMath
import ir.hesabyar.domain.rates.RateSanity
import ir.hesabyar.domain.text.PersianText

enum class ToolPage { HOME, GOLD, LOAN, SAVINGS }

@Composable
fun ToolsScreen(vm: ToolsViewModel, contentPadding: PaddingValues, onOpenSplitBill: () -> Unit) {
    val s by vm.state.collectAsStateWithLifecycle()
    var page by rememberSaveable { mutableStateOf(ToolPage.HOME) }
    // A sub-tool's Back returns to the tools home, never out of the tab or the app.
    BackHandler(enabled = page != ToolPage.HOME) { page = ToolPage.HOME }

    when (page) {
        ToolPage.HOME -> ToolsHome(s, vm, contentPadding, onOpen = { page = it }, onOpenSplitBill = onOpenSplitBill)
        ToolPage.GOLD -> GoldCalculatorScreen(s, contentPadding, onBack = { page = ToolPage.HOME })
        ToolPage.LOAN -> LoanCalculatorScreen(contentPadding, onBack = { page = ToolPage.HOME })
        ToolPage.SAVINGS -> SavingsScreen(s, vm, contentPadding, onBack = { page = ToolPage.HOME })
    }
}

@Composable
private fun ToolsHome(s: ToolsState, vm: ToolsViewModel, contentPadding: PaddingValues, onOpen: (ToolPage) -> Unit, onOpenSplitBill: () -> Unit) {
    var manual by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState())
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = contentPadding.calculateBottomPadding() + 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("ابزارهای مالی و طلا", style = MaterialTheme.typography.titleLarge)
        RatesTable(s, onRefresh = vm::refresh, onManual = { manual = true })
        // Native ad directly under the gold/coin table: the highest-intent spot for gold & exchange advertisers.
        NativeAdCard(AdSlot.NATIVE_TOOLS_UNDER_RATES)
        ToolEntry("🪙 ماشین‌حساب طلای ۱۸ عیار", "وزن، اجرت، سود فروشنده تا ۷٪ و مالیات ۹٪ — با بودجه چند گرم می‌شود؟") { onOpen(ToolPage.GOLD) }
        ToolEntry("🏦 ماشین‌حساب وام و اقساط", "فرمول جدید (بانکی) و قدیم، مقایسه و جدول بازپرداخت") { onOpen(ToolPage.LOAN) }
        ToolEntry("🛡️ هدف پس‌انداز ضدتورم", "هدف را به گرم طلا یا دلار تعریف کنید، نه تومانی که آب می‌رود") { onOpen(ToolPage.SAVINGS) }
        ToolEntry("➗ ماشین‌حساب دنگ", "تقسیم هزینه‌ی سفر و دورهمی و ثبت در طلب و بدهی", onOpenSplitBill)
    }
    if (manual) ManualRateDialog(s.rates, onSave = { k, rial -> vm.setManualRate(k, rial) }, onDismiss = { manual = false })
}

@Composable
private fun RatesTable(s: ToolsState, onRefresh: () -> Unit, onManual: () -> Unit) {
    val money = AppTheme.money
    val now = System.currentTimeMillis()
    val newest = s.rates.values.maxOfOrNull { it.fetchedAt }
    AppCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(Gold))
            Spacer(Modifier.width(8.dp))
            Column(Modifier.weight(1f)) {
                Text("نرخ لحظه‌ای بازار", style = MaterialTheme.typography.titleMedium)
                if (newest != null) {
                    Text(
                        "به‌روزرسانی: ${formatWhen(newest)}" + if (RateSanity.isStale(newest, now)) " • قدیمی" else "",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (RateSanity.isStale(newest, now)) money.expense else money.muted,
                    )
                }
            }
            IconButton(onClick = onManual) { Icon(Icons.Filled.Edit, contentDescription = "ثبت دستی نرخ", tint = money.muted) }
            if (s.hasOnlineSource) {
                if (s.refreshing) CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                else IconButton(onClick = onRefresh) { Icon(Icons.Filled.Refresh, contentDescription = "به‌روزرسانی", tint = money.muted) }
            }
        }
        s.refreshMessage?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = money.muted) }
        if (s.rates.isEmpty()) {
            Text(
                if (s.hasOnlineSource) "هنوز نرخی دریافت نشده. با اتصال به اینترنت دکمه‌ی به‌روزرسانی را بزنید."
                else "منبع نرخ آنلاین تنظیم نشده است. با دکمه‌ی ✎ نرخ روز را دستی ثبت کنید تا ماشین‌حساب‌ها و اهداف پس‌انداز کار کنند.",
                style = MaterialTheme.typography.bodySmall, color = money.muted, modifier = Modifier.padding(top = 6.dp),
            )
            return@AppCard
        }
        val gold = s.rates[RateKey.GOLD_18K_GRAM]?.priceRial
        RateKey.entries.forEachIndexed { i, key ->
            val r = s.rates[key] ?: return@forEachIndexed
            if (i > 0) HorizontalDivider(color = money.hairline)
            RateRow(key, r, gold)
        }
        Text("مبالغ به تومان • حباب = قیمت سکه منهای ارزش طلای آن", style = MaterialTheme.typography.labelSmall, color = money.muted, modifier = Modifier.padding(top = 6.dp))
    }
}

@Composable
private fun RateRow(key: RateKey, r: RateEntity, gold18: Long?) {
    val money = AppTheme.money
    val coin = when (key) { RateKey.COIN_EMAMI -> Coin.EMAMI; RateKey.COIN_HALF -> Coin.HALF; RateKey.COIN_QUARTER -> Coin.QUARTER; else -> null }
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(key.persianName, style = MaterialTheme.typography.bodyMedium)
            if (coin != null && gold18 != null) {
                val bubble = CoinMath.bubbleRial(coin, r.priceRial, gold18)
                val pct = CoinMath.bubblePercent(coin, r.priceRial, gold18)
                Text(
                    "حباب ${Money.formatToman(bubble)} (${PersianText.toPersianDigits("%.1f".format(java.util.Locale.US, pct))}٪)",
                    style = MaterialTheme.typography.labelSmall, color = money.gold,
                )
            }
            if (r.source == "manual") Text("ثبت دستی", style = MaterialTheme.typography.labelSmall, color = money.muted)
        }
        r.changePercent?.let {
            Text(
                PersianText.toPersianDigits("%+.1f".format(java.util.Locale.US, it)) + "٪",
                style = MaterialTheme.typography.labelMedium, color = if (it >= 0) money.income else money.expense,
            )
            Spacer(Modifier.width(10.dp))
        }
        Text(Money.formatToman(r.priceRial), style = MaterialTheme.typography.titleSmall)
    }
}

@Composable
private fun ManualRateDialog(rates: Map<RateKey, RateEntity>, onSave: (RateKey, Long) -> Unit, onDismiss: () -> Unit) {
    var key by remember { mutableStateOf(RateKey.GOLD_18K_GRAM) }
    var text by remember(key) { mutableStateOf(rates[key]?.priceRial?.let { (it / 10).toString() }.orEmpty()) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("ثبت دستی نرخ روز") },
        text = {
            Column {
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    RateKey.entries.forEach { k -> FilterChip(selected = k == key, onClick = { key = k }, label = { Text(k.persianName) }) }
                }
                TextInput("قیمت به تومان", text, { text = it.take(13) }, numeric = true)
                text.toLongOrNull()?.let { Text(Money.formatToman(it * 10) + " تومان", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted) }
            }
        },
        confirmButton = { TextButton(onClick = { text.toLongOrNull()?.let { onSave(key, it * 10) }; onDismiss() }) { Text("ذخیره") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

@Composable
private fun ToolEntry(title: String, subtitle: String, onClick: () -> Unit) {
    AppCard(onClick = onClick) {
        Text(title, style = MaterialTheme.typography.titleSmall)
        Text(subtitle, style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
    }
}

/**
 * Shell for a sub-tool: back row, scrollable body, and the standard 320×50 banner pinned at the
 * very bottom (far from inputs; [banner] null = no ad, e.g. the savings screen).
 */
@Composable
fun ToolPageScaffold(title: String, onBack: () -> Unit, contentPadding: PaddingValues, banner: AdSlot?, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(bottom = contentPadding.calculateBottomPadding())) {
        Row(Modifier.padding(horizontal = 4.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "بازگشت") }
            Text(title, style = MaterialTheme.typography.titleLarge)
        }
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            content = content,
        )
        if (banner != null) {
            Spacer(Modifier.size(8.dp)) // keeps the banner clear of the last input
            BannerSlot(banner)
        }
    }
}
