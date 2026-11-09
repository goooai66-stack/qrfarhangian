package ir.hesabyar.app.ui.tools

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.app.ui.components.AmountInputField
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.Segmented
import ir.hesabyar.app.ui.components.TextInput
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.calc.GoldCalculator
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText
import java.math.BigDecimal

private enum class WageMode(val label: String) { PERCENT("درصد"), TOTAL("مبلغ کل"), PER_GRAM("هر گرم") }

/** «ماشین‌حساب طلافروشی». Banner only at the very bottom (AdSlot.BANNER_GOLD_CALC_BOTTOM). */
@Composable
fun GoldCalculatorScreen(s: ToolsState, contentPadding: PaddingValues, onBack: () -> Unit) {
    val rateGold = s.rates[RateKey.GOLD_18K_GRAM]?.priceRial ?: 0L
    var weight by rememberSaveable { mutableStateOf("") }
    var price by rememberSaveable { mutableLongStateOf(rateGold) }
    var wageMode by rememberSaveable { mutableStateOf(WageMode.PERCENT) }
    var wagePct by rememberSaveable { mutableStateOf("18") }
    var wageRial by rememberSaveable { mutableLongStateOf(0L) }
    var profit by rememberSaveable { mutableStateOf("7") }
    var vat by rememberSaveable { mutableStateOf("9") }
    var budget by rememberSaveable { mutableLongStateOf(0L) }
    var openField by rememberSaveable { mutableStateOf(0) } // 1 price, 2 wage, 3 budget

    LaunchedEffect(rateGold) { if (price == 0L && rateGold > 0) price = rateGold }

    val w = PersianText.parseDecimal(weight) ?: BigDecimal.ZERO
    val profitPct = PersianText.parseDecimal(profit) ?: BigDecimal.ZERO
    val vatPct = PersianText.parseDecimal(vat) ?: BigDecimal.ZERO
    val wage = when (wageMode) {
        WageMode.PERCENT -> GoldCalculator.Wage.Percent(PersianText.parseDecimal(wagePct) ?: BigDecimal.ZERO)
        WageMode.TOTAL -> GoldCalculator.Wage.Fixed(wageRial)
        WageMode.PER_GRAM -> GoldCalculator.Wage.PerGram(wageRial)
    }
    val quote = GoldCalculator.quote(GoldCalculator.Input(w, price, wage, profitPct, vatPct))

    ToolPageScaffold("ماشین‌حساب طلای ۱۸ عیار", onBack, contentPadding, AdSlot.BANNER_GOLD_CALC_BOTTOM) {
        TextInput("وزن (گرم)", weight, { weight = it.take(8) }, placeholder = "مثلاً ۴٫۸۵", decimal = true)
        AmountInputField("نرخ روز هر گرم طلای ۱۸ عیار", price, { price = it }, openField == 1, { openField = if (it) 1 else 0 })
        if (rateGold > 0 && price != rateGold) {
            Text(
                "نرخ بازار: ${Money.formatToman(rateGold)} تومان", style = MaterialTheme.typography.labelSmall, color = AppTheme.money.gold,
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        Text("اجرت ساخت", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted, modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
        Segmented(WageMode.entries.map { it to it.label }, wageMode, { wageMode = it })
        if (wageMode == WageMode.PERCENT) TextInput("درصد اجرت", wagePct, { wagePct = it.take(5) }, decimal = true)
        else AmountInputField(if (wageMode == WageMode.TOTAL) "اجرت کل" else "اجرت هر گرم", wageRial, { wageRial = it }, openField == 2, { openField = if (it) 2 else 0 })

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f)) { TextInput("سود فروشنده ٪ (حداکثر ۷)", profit, { profit = it.take(4) }, decimal = true) }
            Column(Modifier.weight(1f)) { TextInput("مالیات ارزش افزوده ٪", vat, { vat = it.take(4) }, decimal = true) }
        }
        if (profitPct > GoldCalculator.MAX_PROFIT_PERCENT) {
            Text("سود فروشنده طبق ضوابط صنف حداکثر ۷٪ محاسبه شد.", style = MaterialTheme.typography.labelSmall, color = AppTheme.money.expense)
        }

        Spacer(Modifier.height(12.dp))
        AppCard {
            Text("فاکتور", style = MaterialTheme.typography.titleMedium)
            Line("ارزش طلا", quote.goldValueRial)
            Line("اجرت ساخت", quote.wageRial)
            Line("سود فروشنده (${PersianText.toPersianDigits(quote.profitPercentApplied.stripTrailingZeros().toPlainString())}٪)", quote.profitRial)
            Line("مالیات (روی اجرت و سود)", quote.taxRial)
            HorizontalDivider(Modifier.padding(vertical = 6.dp), color = AppTheme.money.hairline)
            Row(Modifier.fillMaxWidth()) {
                Text("قیمت نهایی", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Text(Money.formatTomanWithUnit(quote.totalRial), style = MaterialTheme.typography.titleLarge, color = AppTheme.money.gold)
            }
            if (w.signum() > 0) {
                Text(
                    "هر گرم با همه‌ی هزینه‌ها: ${Money.formatToman(quote.effectivePerGramRial(w))} تومان • ارزش فروش به طلافروش (بدون اجرت): ${Money.formatToman(GoldCalculator.buyBackValueRial(w, price))} تومان",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 6.dp),
                )
            }
        }

        if (wageMode == WageMode.PERCENT) {
            Spacer(Modifier.height(8.dp))
            AppCard {
                Text("با این بودجه چند گرم طلا می‌شود؟", style = MaterialTheme.typography.titleSmall)
                AmountInputField("بودجه", budget, { budget = it }, openField == 3, { openField = if (it) 3 else 0 })
                val grams = GoldCalculator.gramsForBudget(budget, price, PersianText.parseDecimal(wagePct) ?: BigDecimal.ZERO, profitPct, vatPct)
                if (grams.signum() > 0) {
                    Text(
                        PersianText.toPersianDigits(grams.stripTrailingZeros().toPlainString()).replace('.', '٫') + " گرم",
                        style = MaterialTheme.typography.titleLarge, color = AppTheme.money.gold, modifier = Modifier.padding(top = 8.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun Line(label: String, rial: Long, color: Color = MaterialTheme.colorScheme.onSurface) {
    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = AppTheme.money.muted, modifier = Modifier.weight(1f))
        Text(Money.formatToman(rial), style = MaterialTheme.typography.bodyMedium, color = color)
    }
}
