package ir.hesabyar.app.ui.transaction

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.text.PersianText

/** Compact Jalali picker: day / month / year steppers, clamped to real month lengths (incl. leap Esfand). */
@Composable
fun JalaliDatePickerDialog(initial: JalaliDate, onPick: (JalaliDate) -> Unit, onDismiss: () -> Unit) {
    var y by remember { mutableStateOf(initial.year) }
    var m by remember { mutableStateOf(initial.month) }
    var d by remember { mutableStateOf(initial.day) }
    fun clamp() { d = d.coerceIn(1, JalaliDate.monthLength(y, m)) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("انتخاب تاریخ", style = MaterialTheme.typography.titleMedium) },
        text = {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                Stepper(PersianText.toPersianDigits(d.toString()), { d = if (d >= JalaliDate.monthLength(y, m)) 1 else d + 1 }, { d = if (d <= 1) JalaliDate.monthLength(y, m) else d - 1 })
                Stepper(JalaliDate.MONTH_NAMES[m - 1], { m = if (m == 12) 1 else m + 1; clamp() }, { m = if (m == 1) 12 else m - 1; clamp() })
                Stepper(PersianText.toPersianDigits(y.toString()), { y += 1; clamp() }, { y -= 1; clamp() })
            }
        },
        confirmButton = { TextButton(onClick = { onPick(JalaliDate(y, m, d)) }) { Text("تایید") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

@Composable
private fun Stepper(value: String, onUp: () -> Unit, onDown: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        IconButton(onClick = onUp) { Icon(Icons.Filled.KeyboardArrowUp, contentDescription = "افزایش") }
        Text(value, style = MaterialTheme.typography.titleMedium)
        IconButton(onClick = onDown) { Icon(Icons.Filled.KeyboardArrowDown, contentDescription = "کاهش") }
    }
}
