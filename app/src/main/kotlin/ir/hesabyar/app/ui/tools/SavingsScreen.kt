package ir.hesabyar.app.ui.tools

import android.widget.Toast
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.appContainer
import ir.hesabyar.app.data.local.entity.SavingsUnit
import ir.hesabyar.app.ui.common.formatWhen
import ir.hesabyar.app.ui.components.AccountPicker
import ir.hesabyar.app.ui.components.AmountInputField
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.DateInput
import ir.hesabyar.app.ui.components.FormSheet
import ir.hesabyar.app.ui.components.RewardedUnlockDialog
import ir.hesabyar.app.ui.components.Segmented
import ir.hesabyar.app.ui.components.TextInput
import ir.hesabyar.app.ui.components.findActivity
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.ads.AppSurface
import ir.hesabyar.domain.ads.RewardedFeature
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText

/**
 * «سپر ضدتورم». Goals, deposits and real progress are free; the comparison analysis and chart
 * (asset vs. cash) is the rewarded feature — unlocked for 24h by one user-initiated video.
 * No banner here: this is a planning screen with frequent inputs.
 */
@Composable
fun SavingsScreen(s: ToolsState, vm: ToolsViewModel, contentPadding: PaddingValues, onBack: () -> Unit) {
    val context = LocalContext.current
    val ads = context.appContainer.ads
    val entitlements by ads.entitlements.collectAsState()
    val analysisUnlocked = entitlements.isActive(RewardedFeature.INFLATION_SHIELD, System.currentTimeMillis())
    var newGoal by remember { mutableStateOf(false) }
    var depositFor by remember { mutableStateOf<GoalUi?>(null) }
    var askUnlock by remember { mutableStateOf(false) }

    ToolPageScaffold("هدف پس‌انداز ضدتورم", onBack, contentPadding, banner = null) {
        Text(
            "تومان هر سال ارزش خود را از دست می‌دهد. هدف را به گرم طلا یا دلار تعریف کنید؛ هر واریز با نرخ همان روز به واحد هدف تبدیل می‌شود و پیشرفت واقعی را می‌بینید.",
            style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
        )
        Spacer(Modifier.height(8.dp))
        Button(onClick = { newGoal = true }, colors = ButtonDefaults.buttonColors(containerColor = Navy), modifier = Modifier.fillMaxWidth()) {
            Text("+ هدف جدید")
        }
        if (s.goals.isEmpty()) {
            Text("هنوز هدفی تعریف نشده. مثال: «۵۰ گرم طلا برای جهیزیه تا اسفند».", style = MaterialTheme.typography.bodyMedium, color = AppTheme.money.muted, modifier = Modifier.padding(vertical = 16.dp))
        }
        s.goals.forEach { g ->
            Spacer(Modifier.height(8.dp))
            GoalCard(
                g, analysisUnlocked,
                onDeposit = { depositFor = g },
                onUnlock = { askUnlock = true },
                onArchive = { vm.archiveGoal(g.goal.id) },
                onDeleteDeposit = vm::deleteDeposit,
            )
        }
    }

    if (newGoal) NewGoalSheet(vm) { newGoal = false }
    depositFor?.let { g -> DepositSheet(s, vm, g) { depositFor = null } }
    if (askUnlock) {
        RewardedUnlockDialog(
            RewardedFeature.INFLATION_SHIELD,
            onWatch = {
                askUnlock = false
                context.findActivity()?.let { a ->
                    ads.watchToUnlock(a, RewardedFeature.INFLATION_SHIELD, AppSurface.TOOLS_HOME) { ok ->
                        if (ok) Toast.makeText(context, "تحلیل سپر ضدتورم برای ۲۴ ساعت فعال شد", Toast.LENGTH_SHORT).show()
                    }
                }
            },
            onDismiss = { askUnlock = false },
        )
    }
}

@Composable
private fun GoalCard(g: GoalUi, unlocked: Boolean, onDeposit: () -> Unit, onUnlock: () -> Unit, onArchive: () -> Unit, onDeleteDeposit: (Long) -> Unit) {
    val r = g.report
    val unit = g.goal.unit
    var menu by remember { mutableStateOf(false) }
    var showDeposits by remember { mutableStateOf(false) }
    AppCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(g.goal.title, style = MaterialTheme.typography.titleSmall)
                Text("هدف: " + formatUnits(r.targetMilli, unit), style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
            }
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, contentDescription = "گزینه‌ها") }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text(if (showDeposits) "پنهان کردن واریزها" else "نمایش واریزها") }, onClick = { menu = false; showDeposits = !showDeposits })
                    DropdownMenuItem(text = { Text("بایگانی هدف") }, onClick = { menu = false; onArchive() })
                }
            }
        }
        Spacer(Modifier.height(6.dp))
        LinearProgressIndicator(progress = { r.progress }, color = Gold, trackColor = AppTheme.money.chipBg, modifier = Modifier.fillMaxWidth().height(10.dp).clip(CircleShape))
        Spacer(Modifier.height(6.dp))
        Text(
            formatUnits(r.ownedMilli, unit) + " از " + formatUnits(r.targetMilli, unit) +
                PersianText.toPersianDigits(" (${(r.progress * 100).toInt()}٪)") + if (r.reached) " 🎉" else "",
            style = MaterialTheme.typography.bodyMedium,
        )
        if (g.currentPriceRial == null) {
            Text("نرخ روز «${unit.label()}» در دسترس نیست؛ در صفحه ابزارها ثبت دستی کنید.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.expense)
        } else {
            Text("ارزش امروز: ${Money.formatTomanWithUnit(r.currentValueRial)} • واریزی: ${Money.formatToman(r.totalDepositedRial)}", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
            if (!r.reached) {
                Text(
                    "باقیمانده با نرخ امروز: ${Money.formatToman(r.remainingRialAtCurrentPrice)} تومان" +
                        (r.monthlyNeededRial?.let { " • ماهانه ${Money.formatToman(it)}" } ?: ""),
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
                )
            }
        }
        g.goal.deadlineEpochDay?.let { Text("موعد: " + JalaliDate.fromEpochDay(it).formatLong(), style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted) }

        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = onDeposit, colors = ButtonDefaults.buttonColors(containerColor = Gold, contentColor = Navy)) { Text("واریز") }
            if (!unlocked && g.deposits.isNotEmpty()) OutlinedButton(onClick = onUnlock) { Text("🔓 تحلیل سپر ضدتورم") }
        }

        if (unlocked && g.deposits.isNotEmpty() && g.currentPriceRial != null) ShieldAnalysis(g)

        if (showDeposits) {
            g.deposits.sortedByDescending { it.depositedAt }.forEach { d ->
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(Money.formatTomanWithUnit(d.amountRial) + " → " + formatUnits(d.milliUnitsAcquired, unit), style = MaterialTheme.typography.bodySmall)
                        Text(formatWhen(d.depositedAt) + " • نرخ " + Money.formatToman(d.unitPriceRialAtDeposit), style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted)
                    }
                    TextButton(onClick = { onDeleteDeposit(d.id) }) { Text("حذف", color = AppTheme.money.muted) }
                }
            }
        }
    }
}

/** The rewarded analysis: what the shield saved, plus the asset-vs-cash curve. */
@Composable
private fun ShieldAnalysis(g: GoalUi) {
    val r = g.report
    val unit = g.goal.unit
    val won = r.inflationGainRial >= 0
    Spacer(Modifier.height(10.dp))
    Text("تحلیل سپر ضدتورم", style = MaterialTheme.typography.titleSmall)
    Text(
        if (won) "نگه‌داشتن دارایی به‌جای تومان ${Money.formatTomanWithUnit(r.inflationGainRial)} (" +
            PersianText.toPersianDigits("%.1f".format(java.util.Locale.US, r.inflationGainPercent)) + "٪) سود تورمی داشته است."
        else "ارزش دارایی فعلاً ${Money.formatTomanWithUnit(-r.inflationGainRial)} کمتر از مبلغ واریزی است.",
        style = MaterialTheme.typography.bodySmall, color = if (won) AppTheme.money.income else AppTheme.money.expense,
    )
    Text(
        "اگر همین مبلغ را تومان نگه داشته بودید، امروز فقط ${formatUnits(r.cashEquivalentMilli, unit)} می‌خرید؛ " +
            "شما ${formatUnits(r.ownedMilli, unit)} دارید.",
        style = MaterialTheme.typography.bodySmall,
    )
    if (g.curve.size >= 2) {
        Spacer(Modifier.height(8.dp))
        ShieldChart(g.curve.map { it.ownedMilli }, g.curve.map { it.cashEquivalentMilli })
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top = 4.dp)) {
            Legend(Gold, "دارایی شما"); Legend(Coral, "اگر تومان نگه می‌داشتید")
        }
    }
}

@Composable
private fun Legend(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(4.dp))
        Text(label, style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted)
    }
}

/** Two cumulative lines, no axes clutter. Drawn left→right in time even inside the RTL app. */
@Composable
private fun ShieldChart(owned: List<Long>, cash: List<Long>) {
    val grid = AppTheme.money.hairline
    Canvas(Modifier.fillMaxWidth().height(140.dp)) {
        val max = (owned + cash).maxOrNull()?.coerceAtLeast(1) ?: 1
        val n = owned.size
        fun pt(i: Int, v: Long) = Offset(x = size.width * i / (n - 1).coerceAtLeast(1), y = size.height - size.height * v / max.toFloat())
        for (k in 1..3) drawLine(grid, Offset(0f, size.height * k / 4), Offset(size.width, size.height * k / 4), strokeWidth = 1f)
        fun path(values: List<Long>) = Path().apply { values.forEachIndexed { i, v -> val p = pt(i, v); if (i == 0) moveTo(p.x, p.y) else lineTo(p.x, p.y) } }
        drawPath(path(cash), Coral, style = Stroke(width = 4f, cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(12f, 10f))))
        drawPath(path(owned), Gold, style = Stroke(width = 6f, cap = StrokeCap.Round))
        owned.forEachIndexed { i, v -> drawCircle(Gold, radius = 6f, center = pt(i, v)) }
    }
}

// ================================================================== sheets

@Composable
private fun NewGoalSheet(vm: ToolsViewModel, onDismiss: () -> Unit) {
    var title by remember { mutableStateOf("") }
    var unit by remember { mutableStateOf(SavingsUnit.GOLD_18K_GRAM) }
    var target by remember { mutableStateOf("") }
    var deadline by remember { mutableStateOf<JalaliDate?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    FormSheet(
        "هدف ضدتورم جدید", "ساخت هدف", error, saving, onDismiss = onDismiss,
        onSave = {
            saving = true
            vm.createGoal(title, unit, PersianText.parseDecimal(target), deadline) { msg -> saving = false; if (msg == null) onDismiss() else error = msg }
        },
    ) {
        TextInput("عنوان", title, { title = it }, placeholder = "جهیزیه، خرید خودرو، صندوق اضطراری")
        Text("واحد هدف", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted, modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
        Segmented(SavingsUnit.entries.map { it to it.label() }, unit, { unit = it }, accent = { Gold })
        TextInput("مقدار هدف (${unit.label()})", target, { target = it.take(10) }, placeholder = if (unit == SavingsUnit.GOLD_18K_GRAM) "مثلاً ۵۰" else "مثلاً ۲۰۰۰", decimal = true)
        DateInput("موعد (اختیاری)", deadline, { deadline = it }, optional = true)
    }
}

@Composable
private fun DepositSheet(s: ToolsState, vm: ToolsViewModel, g: GoalUi, onDismiss: () -> Unit) {
    val unit = g.goal.unit
    var amount by remember { mutableLongStateOf(0L) }
    var price by remember { mutableLongStateOf(s.priceFor(unit) ?: 0L) }
    var open by remember { mutableStateOf(1) }
    var account by remember { mutableStateOf<Long?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (price == 0L) open = 2 }
    FormSheet(
        "واریز به «${g.goal.title}»", "ثبت واریز", error, saving, onDismiss = onDismiss,
        onSave = {
            saving = true
            vm.deposit(g.goal.id, amount, price, account) { msg -> saving = false; if (msg == null) onDismiss() else error = msg }
        },
    ) {
        AmountInputField("مبلغ واریز", amount, { amount = it }, open == 1, { open = if (it) 1 else 0 })
        AmountInputField("قیمت هر واحد (${unit.label()}) در روز خرید", price, { price = it }, open == 2, { open = if (it) 2 else 0 })
        if (amount > 0 && price > 0) {
            Text(
                "معادل " + formatUnits(amount * 1000 / price, unit),
                style = MaterialTheme.typography.titleMedium, color = Mint, modifier = Modifier.padding(top = 8.dp),
            )
        }
        AccountPicker("برداشت از حساب (اختیاری)", s.accounts.filter { it.id != g.goal.accountId }, account, { account = it })
        Text(
            "با انتخاب حساب، مبلغ به‌صورت «انتقال» به حساب این هدف ثبت می‌شود — جزو هزینه‌ها حساب نمی‌شود.",
            style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 6.dp),
        )
    }
}
