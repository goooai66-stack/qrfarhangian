package ir.hesabyar.app.ui.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.ui.common.formatToday
import ir.hesabyar.app.ui.common.formatWhen
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.AppIcons
import ir.hesabyar.app.ui.components.SectionHeader
import ir.hesabyar.app.ui.components.TransactionListItem
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.app.ui.theme.NavyLight
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.rates.Coin
import ir.hesabyar.domain.rates.CoinMath
import ir.hesabyar.domain.sms.TxChannel
import ir.hesabyar.domain.text.PersianText

data class DashboardActions(
    val onSelectLedger: (Long) -> Unit,
    val onAdd: (DraftKind) -> Unit,
    val onVoice: () -> Unit,
    val onConfirmSms: (smsId: Long, categoryId: Long?) -> Unit,
    val onDismissSms: (Long) -> Unit,
    val onNotATransfer: (Long) -> Unit,
    val onSeeAllTransactions: () -> Unit,
    val onOpenTools: () -> Unit,
    val onRefreshRates: () -> Unit,
)

/**
 * Home. Ad-free by policy (AdPolicy: DASHBOARD allows only user-initiated rewarded unlocks),
 * so it stays calm and «luxurious»; the add buttons are the first interactive element.
 */
@Composable
fun DashboardScreen(state: DashboardState, actions: DashboardActions, contentPadding: PaddingValues) {
    LazyColumn(
        modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(bottom = contentPadding.calculateBottomPadding() + 88.dp),
    ) {
        item { HeroHeader(state, actions) }

        if (state.pending.isNotEmpty()) {
            item { SectionHeader("تایید تراکنش‌های پیامکی (${PersianText.toPersianDigits(state.pending.size.toString())})", modifier = Modifier.padding(horizontal = 16.dp)) }
            items(state.pending, key = { "sms-${it.sms.id}" }) { p ->
                PendingSmsCard(p, actions, Modifier.padding(horizontal = 16.dp, vertical = 6.dp))
            }
        }

        item {
            RatesCard(state.rates, onOpen = actions.onOpenTools, onRefresh = actions.onRefreshRates, modifier = Modifier.padding(16.dp))
        }

        item {
            SectionHeader("تراکنش‌های اخیر", action = "مشاهده همه", onAction = actions.onSeeAllTransactions, modifier = Modifier.padding(horizontal = 16.dp))
        }
        if (state.recent.isEmpty()) {
            item {
                AppCard(Modifier.padding(horizontal = 16.dp)) {
                    Text("هنوز تراکنشی ثبت نشده است.", style = MaterialTheme.typography.bodyMedium)
                    Text(
                        "با دکمه‌های بالا اولین هزینه یا درآمد را ثبت کنید، یا ثبت خودکار پیامک بانکی را روشن بگذارید.",
                        style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
                    )
                }
            }
        } else {
            item {
                AppCard(Modifier.padding(horizontal = 16.dp)) {
                    state.recent.forEachIndexed { i, row ->
                        if (i > 0) HorizontalDivider(color = AppTheme.money.hairline)
                        TransactionListItem(row)
                    }
                }
            }
        }
    }
}

// ============================================================== hero: ledger switch, balance, quick add

@Composable
private fun HeroHeader(state: DashboardState, actions: DashboardActions) {
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(bottomStart = 28.dp, bottomEnd = 28.dp))
            .background(Brush.verticalGradient(listOf(Navy, NavyLight)))
            .statusBarsPadding()
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 20.dp),
    ) {
        Column {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LedgerSwitcher(state.ledgers, state.activeLedger, actions.onSelectLedger, Modifier.weight(1f))
                Icon(Icons.Filled.Lock, contentDescription = "داده‌ها فقط روی گوشی", tint = Gold, modifier = Modifier.size(18.dp))
            }
            Spacer(Modifier.height(18.dp))
            Text(formatToday(), color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.bodySmall)
            Text("موجودی کل", color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.titleSmall)
            Row(verticalAlignment = Alignment.Bottom) {
                Text(Money.formatToman(state.totalBalanceRial), color = Color.White, style = MaterialTheme.typography.displaySmall)
                Spacer(Modifier.width(6.dp))
                Text("تومان", color = Gold, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(bottom = 8.dp))
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                MonthStat("درآمد این ماه", state.month.incomeRial, Mint, Modifier.weight(1f))
                MonthStat("هزینه این ماه", state.month.expenseRial, Coral, Modifier.weight(1f))
            }
            if (state.accounts.size > 1) {
                Spacer(Modifier.height(12.dp))
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    state.accounts.forEach { a ->
                        Surface(shape = MaterialTheme.shapes.small, color = Color.White.copy(alpha = 0.08f)) {
                            Column(Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
                                Text(a.name, color = Color.White.copy(alpha = 0.75f), style = MaterialTheme.typography.labelSmall, maxLines = 1)
                                Text(Money.formatToman(a.currentBalanceRial), color = Color.White, style = MaterialTheme.typography.labelLarge)
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            QuickActions(actions)
        }
    }
}

@Composable
private fun LedgerSwitcher(ledgers: List<LedgerEntity>, active: LedgerEntity?, onSelect: (Long) -> Unit, modifier: Modifier) {
    Row(modifier) {
        Row(
            Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.10f)).padding(3.dp),
        ) {
            ledgers.take(4).forEach { l ->
                val selected = l.id == active?.id
                Text(
                    l.name,
                    color = if (selected) Navy else Color.White.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (selected) Gold else Color.Transparent)
                        .clickable { onSelect(l.id) }
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                )
            }
        }
    }
}

@Composable
private fun MonthStat(label: String, rial: Long, accent: Color, modifier: Modifier) {
    Row(modifier.clip(MaterialTheme.shapes.small).background(Color.White.copy(alpha = 0.06f)).padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(accent))
        Spacer(Modifier.width(8.dp))
        Column {
            Text(label, color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.labelSmall)
            Text(Money.formatToman(rial), color = Color.White, style = MaterialTheme.typography.labelLarge)
        }
    }
}

@Composable
private fun QuickActions(actions: DashboardActions) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        QuickAction("هزینه", "−", Coral, Modifier.weight(1f)) { actions.onAdd(DraftKind.EXPENSE) }
        QuickAction("درآمد", "+", Mint, Modifier.weight(1f)) { actions.onAdd(DraftKind.INCOME) }
        QuickAction("انتقال", null, Color.White, Modifier.weight(1f), icon = AppIcons.Transfer) { actions.onAdd(DraftKind.TRANSFER) }
        QuickAction("صوتی", null, Gold, Modifier.weight(1f), icon = AppIcons.Mic, onClick = actions.onVoice)
    }
}

@Composable
private fun QuickAction(label: String, glyph: String?, accent: Color, modifier: Modifier, icon: ImageVector? = null, onClick: () -> Unit) {
    Column(
        modifier.clip(MaterialTheme.shapes.medium).background(Color.White.copy(alpha = 0.08f)).clickable(onClick = onClick).padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(Modifier.size(36.dp).clip(CircleShape).background(accent.copy(alpha = 0.22f)), contentAlignment = Alignment.Center) {
            if (icon != null) Icon(icon, contentDescription = null, tint = accent, modifier = Modifier.size(20.dp))
            else Text(glyph.orEmpty(), color = accent, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(4.dp))
        Text(label, color = Color.White, style = MaterialTheme.typography.labelMedium)
    }
}

// ============================================================== one-tap SMS confirmation

@Composable
private fun PendingSmsCard(p: PendingSmsUi, actions: DashboardActions, modifier: Modifier) {
    val money = AppTheme.money
    val sms = p.sms
    AppCard(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(AppIcons.Sms, contentDescription = null, tint = money.gold, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                "${sms.bank.persianName} • ${formatWhen(sms.occurredAt)}",
                style = MaterialTheme.typography.labelMedium, color = money.muted, modifier = Modifier.weight(1f),
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
            if (sms.confidence < 0.7f) Text("نیاز به بررسی", style = MaterialTheme.typography.labelSmall, color = money.expense)
        }
        Spacer(Modifier.height(6.dp))

        if (p.isSelfTransfer) {
            Text("انتقال بین حساب‌های خودتان", style = MaterialTheme.typography.titleSmall)
            Text(Money.formatTomanWithUnit(sms.amountRial), style = MaterialTheme.typography.titleLarge, color = money.transfer)
            val (from, to) = if (sms.isDebit) p.accountName to p.pairAccountName else p.pairAccountName to p.accountName
            Text("$from ← $to", style = MaterialTheme.typography.bodySmall, color = money.muted)
            Text("به‌عنوان هزینه یا درآمد حساب نمی‌شود.", style = MaterialTheme.typography.bodySmall, color = money.muted)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AssistChip(
                    onClick = { actions.onConfirmSms(sms.id, null) },
                    label = { Text("تایید انتقال") },
                    colors = AssistChipDefaults.assistChipColors(containerColor = Navy, labelColor = Color.White),
                    border = null,
                )
                TextButton(onClick = { actions.onNotATransfer(sms.id) }) { Text("انتقال نیست") }
            }
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    (if (sms.isDebit) "برداشت " else "واریز ") + Money.formatTomanWithUnit(sms.amountRial),
                    style = MaterialTheme.typography.titleMedium,
                    color = if (sms.isDebit) money.expense else money.income,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = { actions.onDismissSms(sms.id) }) { Text("نادیده", color = money.muted) }
            }
            Text(
                p.accountName + (sms.balanceRial?.let { " • مانده ${Money.formatToman(it)}" } ?: "") + channelLabel(sms.channel),
                style = MaterialTheme.typography.bodySmall, color = money.muted,
            )
            Spacer(Modifier.height(8.dp))
            Text("دسته‌بندی را لمس کنید تا ثبت شود:", style = MaterialTheme.typography.labelSmall, color = money.muted)
            Spacer(Modifier.height(4.dp))
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                p.suggestions.forEach { cat ->
                    AssistChip(
                        onClick = { actions.onConfirmSms(sms.id, cat.id) },
                        label = { Text("${cat.icon} ${cat.name}") },
                        colors = AssistChipDefaults.assistChipColors(containerColor = money.chipBg),
                        border = null,
                    )
                }
            }
        }
    }
}

private fun channelLabel(channel: String): String = when (runCatching { TxChannel.valueOf(channel) }.getOrNull()) {
    TxChannel.PURCHASE -> " • خرید کارتی"
    TxChannel.ATM -> " • خودپرداز"
    TxChannel.TRANSFER -> " • انتقال"
    TxChannel.BILL -> " • قبض"
    TxChannel.SALARY -> " • حقوق"
    TxChannel.LOAN -> " • قسط"
    else -> ""
}

// ============================================================== market rates

@Composable
private fun RatesCard(rates: Map<RateKey, RateEntity>, onOpen: () -> Unit, onRefresh: () -> Unit, modifier: Modifier) {
    val money = AppTheme.money
    AppCard(modifier, onClick = onOpen) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(Gold))
            Spacer(Modifier.width(8.dp))
            Text("نرخ بازار", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            val last = rates.values.maxOfOrNull { it.fetchedAt }
            if (last != null) Text("به‌روزرسانی: ${formatWhen(last)}", style = MaterialTheme.typography.labelSmall, color = money.muted)
            IconButton(onClick = onRefresh, modifier = Modifier.size(32.dp)) {
                Icon(Icons.Filled.Refresh, contentDescription = "به‌روزرسانی نرخ", tint = money.muted, modifier = Modifier.size(18.dp))
            }
        }
        if (rates.isEmpty()) {
            Text(
                "قیمت طلا، سکه، دلار و تتر پس از اولین اتصال به اینترنت اینجا نمایش داده می‌شود و برای حالت آفلاین ذخیره می‌ماند.",
                style = MaterialTheme.typography.bodySmall, color = money.muted,
            )
            return@AppCard
        }
        val gold = rates[RateKey.GOLD_18K_GRAM]?.priceRial
        listOf(RateKey.GOLD_18K_GRAM, RateKey.COIN_EMAMI, RateKey.USD, RateKey.USDT).forEach { key ->
            val r = rates[key] ?: return@forEach
            Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(key.persianName, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                if (key == RateKey.COIN_EMAMI && gold != null) {
                    val bubble = CoinMath.bubblePercent(Coin.EMAMI, r.priceRial, gold)
                    Text(
                        "حباب ${PersianText.toPersianDigits("%.1f".format(bubble))}٪",
                        style = MaterialTheme.typography.labelSmall, color = money.gold,
                    )
                    Spacer(Modifier.width(8.dp))
                }
                r.changePercent?.let {
                    Text(
                        PersianText.toPersianDigits("%+.1f".format(it)) + "٪",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (it >= 0) money.income else money.expense,
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(Money.formatToman(r.priceRial), style = MaterialTheme.typography.titleSmall)
            }
        }
    }
}
