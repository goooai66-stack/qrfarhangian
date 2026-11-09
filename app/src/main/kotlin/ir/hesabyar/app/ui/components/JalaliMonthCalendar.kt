package ir.hesabyar.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.text.PersianText

private val WEEK_HEADER = listOf("ش", "ی", "د", "س", "چ", "پ", "ج")

/**
 * Interactive Jalali month grid. Saturday is the first column (rightmost, thanks to RTL),
 * Friday is tinted as the weekly holiday, [markers] draws up to three coloured dots per day.
 */
@Composable
fun JalaliMonthCalendar(
    year: Int,
    month: Int,
    today: JalaliDate,
    selected: JalaliDate?,
    markers: Map<Long, List<Color>>,
    onSelect: (JalaliDate) -> Unit,
    onPrevMonth: () -> Unit,
    onNextMonth: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val first = JalaliDate(year, month, 1)
    val leading = first.dayOfWeek.ordinal // SATURDAY = 0
    val days = JalaliDate.monthLength(year, month)
    val cells = leading + days
    val rows = (cells + 6) / 7

    Column(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // In RTL the start (right) arrow goes back in time, the end (left) arrow forward.
            IconButton(onClick = onPrevMonth) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = "ماه قبل") }
            Text(
                PersianText.toPersianDigits("${JalaliDate.MONTH_NAMES[month - 1]} $year"),
                style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center, modifier = Modifier.weight(1f),
            )
            IconButton(onClick = onNextMonth) { Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = "ماه بعد") }
        }
        Row(Modifier.fillMaxWidth()) {
            WEEK_HEADER.forEachIndexed { i, d ->
                Text(
                    d, textAlign = TextAlign.Center, style = MaterialTheme.typography.labelMedium,
                    color = if (i == 6) AppTheme.money.expense else AppTheme.money.muted, modifier = Modifier.weight(1f),
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        for (r in 0 until rows) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                for (c in 0 until 7) {
                    val dayNum = r * 7 + c - leading + 1
                    if (dayNum !in 1..days) {
                        Spacer(Modifier.weight(1f).aspectRatio(1f))
                    } else {
                        val date = JalaliDate(year, month, dayNum)
                        DayCell(
                            day = dayNum,
                            isToday = date == today,
                            isSelected = date == selected,
                            isFriday = c == 6,
                            dots = markers[date.toEpochDay()].orEmpty(),
                            onClick = { onSelect(date) },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(day: Int, isToday: Boolean, isSelected: Boolean, isFriday: Boolean, dots: List<Color>, onClick: () -> Unit, modifier: Modifier) {
    val textColor = when {
        isSelected -> Color.White
        isFriday -> AppTheme.money.expense
        else -> MaterialTheme.colorScheme.onSurface
    }
    Column(
        modifier.aspectRatio(1f).clip(MaterialTheme.shapes.small)
            .background(if (isSelected) Navy else Color.Transparent)
            .then(if (isToday && !isSelected) Modifier.border(1.5.dp, Gold, MaterialTheme.shapes.small) else Modifier)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(PersianText.toPersianDigits(day.toString()), color = textColor, style = MaterialTheme.typography.bodyMedium)
        Row(Modifier.height(6.dp).padding(top = 1.dp), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            dots.distinct().take(3).forEach { Box(Modifier.size(5.dp).clip(CircleShape).background(if (isSelected) Color.White else it)) }
        }
    }
}
