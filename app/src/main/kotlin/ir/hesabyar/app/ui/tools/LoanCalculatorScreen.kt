package ir.hesabyar.app.ui.tools

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.ui.components.AmountInputField
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.Segmented
import ir.hesabyar.app.ui.components.TextInput
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.calc.LoanCalculator
import ir.hesabyar.domain.calc.LoanCalculator.Method
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText
import java.math.BigDecimal

private enum class LoanView(val label: String) { NEW("فرمول جدید"), OLD("فرمول قدیم"), COMPARE("مقایسه") }

/** Banner only at the very bottom (AdSlot.BANNER_LOAN_CALC_BOTTOM). */
@Composable
fun LoanCalculatorScreen(contentPadding: PaddingValues, onBack: () -> Unit) {
    var principal by rememberSaveable { mutableLongStateOf(0L) }
    var rate by rememberSaveable { mutableStateOf("23") }
    var months by rememberSaveable { mutableStateOf("36") }
    var view by rememberSaveable { mutableStateOf(LoanView.NEW) }
    var keyboard by rememberSaveable { mutableStateOf(true) }
    var showAll by rememberSaveable { mutableStateOf(false) }

    val r = PersianText.parseDecimal(rate)
    val n = months.toIntOrNull()
    val valid = principal > 0 && r != null && n != null && n in 1..600
    val newRes = if (valid) LoanCalculator.calculate(principal, r!!, n!!, Method.NEW_ANNUITY) else null
    val oldRes = if (valid) LoanCalculator.calculate(principal, r!!, n!!, Method.OLD_FLAT) else null
    val schedule = remember(principal, rate, months) { if (valid) LoanCalculator.schedule(principal, r!!, n!!) else emptyList() }

    ToolPageScaffold("ماشین‌حساب وام و اقساط", onBack, contentPadding, AdSlot.BANNER_LOAN_CALC_BOTTOM) {
        AmountInputField("مبلغ وام", principal, { principal = it }, keyboard, { keyboard = it })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f)) { TextInput("سود سالانه ٪", rate, { rate = it.take(5) }, decimal = true) }
            Column(Modifier.weight(1f)) { TextInput("تعداد ماه", months, { months = it.take(3) }, numeric = true) }
        }
        Spacer(Modifier.height(12.dp))
        Segmented(LoanView.entries.map { it to it.label }, view, { view = it })
        Spacer(Modifier.height(8.dp))

        if (!valid) {
            Text("مبلغ، نرخ سود و تعداد ماه (۱ تا ۶۰۰) را وارد کنید.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
            return@ToolPageScaffold
        }
        when (view) {
            LoanView.NEW -> ResultCard("فرمول جدید (روش فعلی بانک‌ها)", newRes!!)
            LoanView.OLD -> ResultCard("فرمول قدیم", oldRes!!)
            LoanView.COMPARE -> {
                ResultCard("فرمول جدید", newRes!!)
                Spacer(Modifier.height(8.dp))
                ResultCard("فرمول قدیم", oldRes!!)
                val diff = newRes.totalInterestRial - oldRes.totalInterestRial
                Text(
                    if (diff >= 0) "در فرمول جدید ${Money.formatToman(diff)} تومان سود بیشتری می‌پردازید؛ فرمول قدیم هزینه‌ی واقعی را کمتر نشان می‌دهد."
                    else "در فرمول جدید ${Money.formatToman(-diff)} تومان سود کمتری می‌پردازید.",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 8.dp),
                )
            }
        }

        if (view != LoanView.OLD) {
            Spacer(Modifier.height(12.dp))
            AppCard {
                Text("جدول بازپرداخت (فرمول جدید)", style = MaterialTheme.typography.titleSmall)
                Row(Modifier.fillMaxWidth().padding(top = 6.dp)) {
                    listOf("قسط", "سود", "اصل", "مانده").forEach {
                        Text(it, style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
                    }
                }
                HorizontalDivider(color = AppTheme.money.hairline)
                (if (showAll) schedule else schedule.take(12)).forEach { row ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 3.dp)) {
                        Text(PersianText.toPersianDigits(row.number.toString()), style = MaterialTheme.typography.labelSmall, modifier = Modifier.width(28.dp))
                        listOf(row.interestRial, row.principalRial, row.remainingRial).forEach {
                            Text(Money.formatToman(it), style = MaterialTheme.typography.labelSmall, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
                        }
                    }
                }
                if (schedule.size > 12) {
                    TextButton(onClick = { showAll = !showAll }) {
                        Text(if (showAll) "نمایش کمتر" else PersianText.toPersianDigits("نمایش همه‌ی ${schedule.size} قسط"))
                    }
                }
            }
        }
        Text(
            "برای پیگیری اقساط واقعی، در تب «سررسیدها» دفترچه اقساط بسازید.",
            style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 8.dp),
        )
    }
}

@Composable
private fun ResultCard(title: String, r: LoanCalculator.Result) {
    AppCard {
        Text(title, style = MaterialTheme.typography.titleSmall)
        Row(Modifier.fillMaxWidth().padding(top = 6.dp)) {
            Text("قسط ماهانه", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            Text(Money.formatTomanWithUnit(r.installmentRial), style = MaterialTheme.typography.titleLarge, color = AppTheme.money.gold)
        }
        Row(Modifier.fillMaxWidth()) {
            Text("کل سود", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.weight(1f))
            Text(Money.formatToman(r.totalInterestRial), style = MaterialTheme.typography.bodySmall, color = AppTheme.money.expense)
        }
        Row(Modifier.fillMaxWidth()) {
            Text("کل بازپرداخت", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.weight(1f))
            Text(Money.formatToman(r.totalPaymentRial), style = MaterialTheme.typography.bodySmall)
        }
    }
}
