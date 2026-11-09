package ir.hesabyar.app.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.report.ReportBuilder
import ir.hesabyar.domain.text.PersianText

/** Grouped income/expense bars per Jalali month; pure Compose layout, no chart library. */
@Composable
fun MonthlyBarChart(buckets: List<ReportBuilder.MonthBucket>, modifier: Modifier = Modifier, barAreaHeight: Int = 140) {
    val max = buckets.maxOfOrNull { maxOf(it.incomeRial, it.expenseRial) }?.coerceAtLeast(1) ?: 1
    Column(modifier) {
        Row(Modifier.fillMaxWidth().height(barAreaHeight.dp), verticalAlignment = Alignment.Bottom) {
            buckets.forEach { b ->
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.Bottom) {
                    Bar(b.incomeRial, max, barAreaHeight, Mint)
                    Spacer(Modifier.width(3.dp))
                    Bar(b.expenseRial, max, barAreaHeight, Coral)
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(top = 4.dp)) {
            buckets.forEach { b ->
                Text(b.label, style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted, textAlign = TextAlign.Center, maxLines = 1, modifier = Modifier.weight(1f))
            }
        }
        Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            LegendDot(Mint, "درآمد"); LegendDot(Coral, "هزینه")
        }
    }
}

@Composable
private fun Bar(value: Long, max: Long, areaHeight: Int, color: Color) {
    val h = (areaHeight * value.toFloat() / max).coerceAtLeast(if (value > 0) 3f else 0f)
    Box(Modifier.width(10.dp).height(h.dp).clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp)).background(color))
}

@Composable
fun LegendDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(color))
        Spacer(Modifier.width(4.dp))
        Text(label, style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted)
    }
}

data class DonutSlice(val label: String, val icon: String, val amountRial: Long, val percent: Double, val color: Color)

/** Expense split by category: ring + legend with amount and share. */
@Composable
fun DonutChart(slices: List<DonutSlice>, totalRial: Long, modifier: Modifier = Modifier) {
    val track = AppTheme.money.chipBg
    Row(modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(132.dp), contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(132.dp)) {
                val stroke = 22.dp.toPx()
                val inset = stroke / 2
                val arcSize = Size(size.width - stroke, size.height - stroke)
                drawArc(track, 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                var start = -90f
                slices.forEach { s ->
                    val sweep = (s.percent / 100.0 * 360.0).toFloat()
                    drawArc(s.color, start, (sweep - 1.2f).coerceAtLeast(0.5f), false, Offset(inset, inset), arcSize, style = Stroke(stroke))
                    start += sweep
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("جمع", style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted)
                Text(Money.formatToman(totalRial), style = MaterialTheme.typography.labelLarge, maxLines = 1)
            }
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            slices.forEach { s ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(10.dp).clip(CircleShape).background(s.color))
                    Spacer(Modifier.width(6.dp))
                    Text("${s.icon} ${s.label}", style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    Text(PersianText.toPersianDigits("%.0f".format(java.util.Locale.US, s.percent)) + "٪", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted)
                }
            }
        }
    }
}
