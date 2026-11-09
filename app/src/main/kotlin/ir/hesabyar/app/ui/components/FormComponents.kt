package ir.hesabyar.app.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.app.ui.transaction.JalaliDatePickerDialog
import ir.hesabyar.domain.calc.AmountExpression
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText

/**
 * Bottom-sheet form shell shared by cheque / loan / debt / split forms. Ad-free (these are
 * money-entry surfaces), Back closes only the sheet, the save button sits apart from any keyboard.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FormSheet(
    title: String,
    saveLabel: String,
    error: String?,
    saving: Boolean,
    onSave: () -> Unit,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val focus = LocalFocusManager.current
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.background,
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding()) {
            Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp)) {
                Text(title, style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(8.dp))
                content()
                error?.let {
                    Spacer(Modifier.height(8.dp))
                    Text(it, color = AppTheme.money.expense, style = MaterialTheme.typography.bodySmall)
                }
                Spacer(Modifier.height(16.dp))
            }
            Button(
                onClick = { focus.clearFocus(); onSave() },
                enabled = !saving,
                colors = ButtonDefaults.buttonColors(containerColor = Navy, contentColor = Color.White),
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp).height(52.dp),
            ) { Text(saveLabel, style = MaterialTheme.typography.titleSmall) }
        }
    }
}

@Composable
fun FieldLabel(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted, modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
}

/**
 * Amount entry backed by the built-in calculator keyboard (no system keyboard). Tapping the
 * field toggles the keyboard inline; [expanded] is hoisted so only one keyboard is open at a time.
 */
@Composable
fun AmountInputField(
    label: String,
    rial: Long,
    onChange: (Long) -> Unit,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    val focus = LocalFocusManager.current
    var expr by remember { mutableStateOf(AmountExpression.ofValue(Money.rialToToman(rial))) }
    FieldLabel(label)
    Surface(
        shape = MaterialTheme.shapes.small,
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(if (expanded) 2.dp else 1.dp, if (expanded) Navy else AppTheme.money.hairline),
        modifier = modifier.fillMaxWidth().clickable { focus.clearFocus(); onExpandedChange(!expanded) },
    ) {
        Row(Modifier.padding(horizontal = 14.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (expr.isEmpty) "۰" else PersianText.toPersianDigits(groupExpr(expr.raw)),
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.weight(1f),
            )
            Text(
                if (expr.hasOperator) "= " + Money.formatToman(rial) + " تومان" else "تومان",
                style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted,
            )
        }
    }
    if (expanded) {
        Spacer(Modifier.height(6.dp))
        CalculatorKeyboard(onKey = { key ->
            expr = expr.apply(key)
            onChange(Money.tomanToRial((expr.evaluate() ?: 0L).coerceAtLeast(0)))
        }, modifier = Modifier.clip(MaterialTheme.shapes.small))
    }
}

/** "250000+18000" → "250,000 + 18,000" */
fun groupExpr(raw: String): String {
    val sb = StringBuilder()
    val num = StringBuilder()
    fun flush() { if (num.isNotEmpty()) { sb.append(Money.group(num.toString().toLong())); num.clear() } }
    for (ch in raw) if (ch.isDigit()) num.append(ch) else { flush(); sb.append(' ').append(ch).append(' ') }
    flush()
    return sb.toString()
}

@Composable
fun TextInput(
    label: String,
    value: String,
    onChange: (String) -> Unit,
    placeholder: String = "",
    numeric: Boolean = false,
    modifier: Modifier = Modifier,
) {
    FieldLabel(label)
    OutlinedTextField(
        value = value,
        onValueChange = { onChange(if (numeric) PersianText.toLatinDigits(it).filter { c -> c.isDigit() } else it) },
        placeholder = { if (placeholder.isNotEmpty()) Text(placeholder) },
        singleLine = true,
        keyboardOptions = if (numeric) KeyboardOptions(keyboardType = KeyboardType.Number) else KeyboardOptions.Default,
        modifier = modifier.fillMaxWidth(),
    )
}

@Composable
fun DateInput(label: String, date: JalaliDate?, onChange: (JalaliDate?) -> Unit, optional: Boolean = false) {
    var pick by remember { mutableStateOf(false) }
    FieldLabel(label)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        if (optional) FilterChip(selected = date == null, onClick = { onChange(null) }, label = { Text("بدون تاریخ") })
        FilterChip(selected = date != null, onClick = { pick = true }, label = { Text("📅 " + (date?.formatLong() ?: "انتخاب تاریخ")) })
    }
    if (pick) JalaliDatePickerDialog(date ?: JalaliDate.today(), onPick = { onChange(it); pick = false }, onDismiss = { pick = false })
}

@Composable
fun AccountPicker(label: String, accounts: List<AccountEntity>, selectedId: Long?, onSelect: (Long?) -> Unit, allowNone: Boolean = true) {
    FieldLabel(label)
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        if (allowNone) FilterChip(selected = selectedId == null, onClick = { onSelect(null) }, label = { Text("بدون حساب") })
        accounts.forEach { a ->
            FilterChip(
                selected = a.id == selectedId, onClick = { onSelect(a.id) }, label = { Text(a.name) },
                colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Navy, selectedLabelColor = Color.White),
            )
        }
    }
}

@Composable
fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit, hint: String? = null) {
    Row(Modifier.fillMaxWidth().padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            hint?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted) }
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

/** Pill segmented control used in forms and tab headers. */
@Composable
fun <T> Segmented(options: List<Pair<T, String>>, selected: T, onSelect: (T) -> Unit, accent: (T) -> Color = { Navy }, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth().clip(CircleShape).background(AppTheme.money.chipBg).padding(4.dp)) {
        options.forEach { (value, label) ->
            val isSel = value == selected
            Text(
                label, textAlign = TextAlign.Center, style = MaterialTheme.typography.labelLarge, maxLines = 1,
                color = if (isSel) Color.White else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f).clip(CircleShape).background(if (isSel) accent(value) else Color.Transparent)
                    .clickable { onSelect(value) }.padding(vertical = 9.dp),
            )
        }
    }
}
