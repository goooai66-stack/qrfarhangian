package ir.hesabyar.app.ui.reports

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.appContainer
import ir.hesabyar.app.export.ExportedFile
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.BannerSlot
import ir.hesabyar.app.ui.components.DonutChart
import ir.hesabyar.app.ui.components.DonutSlice
import ir.hesabyar.app.ui.components.ExportResultDialog
import ir.hesabyar.app.ui.components.MonthlyBarChart
import ir.hesabyar.app.ui.components.RewardedUnlockDialog
import ir.hesabyar.app.ui.components.findActivity
import ir.hesabyar.app.ui.settings.SettingsScreen
import ir.hesabyar.app.ui.settings.SettingsViewModel
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.ads.AppSurface
import ir.hesabyar.domain.ads.RewardedFeature
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.report.ReportBuilder
import ir.hesabyar.domain.text.PersianText
import java.util.Locale

private val PALETTE = listOf(0xFF1B2A4A, 0xFFC5A059, 0xFF3EB489, 0xFFE05A47, 0xFF5B7DB1, 0xFF94A3B8).map { Color(it) }

/** Tab 5: «گزارش‌ها و تنظیمات». Settings is a sub-page (Back returns to the report). */
@Composable
fun ReportsTab(vm: ReportsViewModel, settingsVm: SettingsViewModel, contentPadding: PaddingValues) {
    var settings by rememberSaveable { mutableStateOf(false) }
    BackHandler(enabled = settings) { settings = false }
    if (settings) SettingsScreen(settingsVm, contentPadding, onBack = { settings = false })
    else ReportsScreen(vm, contentPadding, onOpenSettings = { settings = true })
}

@Composable
fun ReportsScreen(vm: ReportsViewModel, contentPadding: PaddingValues, onOpenSettings: () -> Unit) {
    val s by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val ads = context.appContainer.ads
    var file by remember { mutableStateOf<ExportedFile?>(null) }
    var askUnlockFor by remember { mutableStateOf<ExportKind?>(null) }

    val runExport: (ExportKind) -> Unit = { kind ->
        vm.export(kind) { f -> if (f == null) Toast.makeText(context, "ساخت فایل انجام نشد", Toast.LENGTH_SHORT).show() else file = f }
    }
    // One rewarded video = one professional export. A spare credit is used silently.
    val requestExport: (ExportKind) -> Unit = { kind -> if (ads.consume(RewardedFeature.EXPORT_EXCEL_PDF)) runExport(kind) else askUnlockFor = kind }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(bottom = contentPadding.calculateBottomPadding())) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("گزارش‌ها", style = MaterialTheme.typography.titleLarge, modifier = Modifier.weight(1f))
                IconButton(onClick = onOpenSettings) { Icon(Icons.Filled.Settings, contentDescription = "تنظیمات، پشتیبان‌گیری و امنیت") }
            }
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                ReportBuilder.Preset.entries.forEach { p -> FilterChip(selected = s.preset == p, onClick = { vm.setPreset(p) }, label = { Text(p.label) }) }
            }
            val r = s.report
            if (r == null) {
                Text("در حال آماده‌سازی…", color = AppTheme.money.muted)
            } else {
                Text(PersianText.toPersianDigits("${r.from.formatLong()} تا ${r.to.formatLong()}"), style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted)
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Kpi("درآمد", Money.formatToman(r.incomeRial), AppTheme.money.income, Modifier.weight(1f))
                    Kpi("هزینه", Money.formatToman(r.expenseRial), AppTheme.money.expense, Modifier.weight(1f))
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Kpi("خالص", Money.formatToman(r.netRial), if (r.netRial >= 0) AppTheme.money.income else AppTheme.money.expense, Modifier.weight(1f))
                    Kpi("نرخ پس‌انداز", r.savingsRatePercent?.let { pct(it) } ?: "—", AppTheme.money.gold, Modifier.weight(1f))
                }
                AppCard {
                    Text("میانگین هزینه روزانه: ${Money.formatTomanWithUnit(r.dailyAverageExpenseRial)}", style = MaterialTheme.typography.bodyMedium)
                    r.expenseChangePercent?.let {
                        Text(
                            (if (it >= 0) "▲ " else "▼ ") + pct(kotlin.math.abs(it)) + (if (it >= 0) " بیشتر" else " کمتر") + " از دوره‌ی قبل",
                            style = MaterialTheme.typography.bodySmall, color = if (it >= 0) AppTheme.money.expense else AppTheme.money.income,
                        )
                    }
                    Text(PersianText.toPersianDigits("${r.transactionCount} تراکنش (انتقال‌ها شمرده نمی‌شوند)"), style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
                }

                AppCard {
                    Text("روند ۶ ماه اخیر", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(10.dp))
                    MonthlyBarChart(s.months)
                }

                AppCard {
                    Text("هزینه به تفکیک دسته", style = MaterialTheme.typography.titleSmall)
                    Spacer(Modifier.height(10.dp))
                    if (r.expenseSlices.isEmpty()) Text("هزینه‌ای در این بازه ثبت نشده است.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
                    else DonutChart(
                        r.expenseSlices.mapIndexed { i, sl ->
                            val cat = sl.categoryId?.let { s.categories[it] }
                            DonutSlice(
                                label = when { sl.isOther -> "سایر دسته‌ها"; cat != null -> cat.name; else -> "بدون دسته" },
                                icon = cat?.icon ?: "•",
                                amountRial = sl.amountRial, percent = sl.percent,
                                color = cat?.let { Color(it.colorArgb) }?.takeIf { !sl.isOther } ?: PALETTE[i % PALETTE.size],
                            )
                        },
                        r.expenseRial,
                    )
                }

                AppCard {
                    Text("خروجی حرفه‌ای برای چاپ یا حسابدار", style = MaterialTheme.typography.titleSmall)
                    Text("فارسی و راست‌به‌چپ؛ رایگان با تماشای یک ویدیوی کوتاه برای هر خروجی.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
                    Spacer(Modifier.height(8.dp))
                    if (s.exporting) CircularProgressIndicator()
                    else Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { requestExport(ExportKind.EXCEL) }, modifier = Modifier.weight(1f)) { Text("📊 Excel") }
                        OutlinedButton(onClick = { requestExport(ExportKind.PDF) }, modifier = Modifier.weight(1f)) { Text("📄 PDF") }
                    }
                }
            }
        }
        // Standard banner at the very bottom — far from the export buttons.
        BannerSlot(AdSlot.BANNER_REPORTS_BOTTOM)
    }

    askUnlockFor?.let { kind ->
        RewardedUnlockDialog(
            RewardedFeature.EXPORT_EXCEL_PDF,
            onWatch = {
                askUnlockFor = null
                context.findActivity()?.let { a ->
                    ads.watchToUnlock(a, RewardedFeature.EXPORT_EXCEL_PDF, AppSurface.REPORTS) { ok ->
                        if (ok && ads.consume(RewardedFeature.EXPORT_EXCEL_PDF)) runExport(kind)
                    }
                }
            },
            onDismiss = { askUnlockFor = null },
        )
    }
    file?.let { f -> ExportResultDialog(f) { file = null } }
}

@Composable
private fun Kpi(label: String, value: String, color: Color, modifier: Modifier) {
    AppCard(modifier) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted)
        Text(value, style = MaterialTheme.typography.titleMedium, color = color, maxLines = 1)
    }
}

private fun pct(v: Double) = PersianText.toPersianDigits("%.1f".format(Locale.US, v)) + "٪"
