package ir.hesabyar.app.ui.transaction

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.ui.components.CalculatorKeyboard
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText

/**
 * Quick add. Ad-free zone by policy: no banner, no interstitial, nothing near the keyboard or
 * the save button. Back / swipe-down closes the sheet only (never the app).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddTransactionSheet(vm: AddTransactionViewModel, onDismiss: () -> Unit) {
    val s by vm.state.collectAsStateWithLifecycle()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val focus = LocalFocusManager.current
    var noteFocused by remember { mutableStateOf(false) }
    var pickDate by remember { mutableStateOf(false) }

    LaunchedEffect(s.saved) { if (s.saved) onDismiss() }

    val accent = when (s.kind) {
        DraftKind.EXPENSE -> Coral
        DraftKind.INCOME -> Mint
        DraftKind.TRANSFER -> Navy
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.background,
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding()) {
            Column(
                Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
            ) {
                s.voiceTranscript?.let {
                    Text(
                        "🎙 «$it» — موارد را بررسی و ثبت کنید",
                        style = MaterialTheme.typography.bodySmall, color = AppTheme.money.gold,
                        modifier = Modifier.padding(bottom = 8.dp),
                    )
                }
                KindSelector(s.kind, vm::setKind)
                Spacer(Modifier.height(16.dp))

                // ---- amount: big, live-evaluated, in Toman
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    val display = if (s.expr.isEmpty) "۰" else PersianText.toPersianDigits(groupExpression(s.expr.raw))
                    Text(display, style = MaterialTheme.typography.headlineMedium, color = accent, textAlign = TextAlign.Center)
                    Text(
                        if (s.expr.hasOperator) "= ${Money.formatToman(Money.tomanToRial(s.amountToman))} تومان" else "تومان",
                        style = MaterialTheme.typography.labelLarge, color = AppTheme.money.muted,
                    )
                }
                Spacer(Modifier.height(12.dp))

                Label(if (s.kind == DraftKind.TRANSFER) "از حساب" else "حساب")
                AccountChips(s.accounts, s.accountId, vm::selectAccount)

                if (s.kind == DraftKind.TRANSFER) {
                    Label("به حساب")
                    AccountChips(s.accounts.filter { it.id != s.accountId }, s.toAccountId, vm::selectToAccount)
                } else {
                    Label("دسته‌بندی")
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        s.categories.forEach { c ->
                            FilterChip(
                                selected = c.id == s.categoryId,
                                onClick = { vm.selectCategory(c.id) },
                                label = { Text("${c.icon} ${c.name}") },
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = accent.copy(alpha = 0.16f),
                                    containerColor = MaterialTheme.colorScheme.surface,
                                ),
                            )
                        }
                    }
                }

                Label("تاریخ")
                DateChips(s.date, onSelect = vm::setDate, onPick = { pickDate = true })

                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = s.note,
                    onValueChange = vm::setNote,
                    placeholder = { Text("توضیحات (اختیاری)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    modifier = Modifier.fillMaxWidth().onFocusChanged { noteFocused = it.isFocused },
                )
                s.error?.let {
                    Spacer(Modifier.height(6.dp))
                    Text(it, color = AppTheme.money.expense, style = MaterialTheme.typography.bodySmall)
                }
                Spacer(Modifier.height(12.dp))
            }

            Button(
                onClick = { focus.clearFocus(); vm.save() },
                enabled = !s.saving,
                colors = ButtonDefaults.buttonColors(containerColor = if (s.kind == DraftKind.TRANSFER) Navy else accent, contentColor = Color.White),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).height(52.dp),
                shape = MaterialTheme.shapes.medium,
            ) {
                Text(
                    when (s.kind) { DraftKind.EXPENSE -> "ثبت هزینه"; DraftKind.INCOME -> "ثبت درآمد"; DraftKind.TRANSFER -> "ثبت انتقال" },
                    style = MaterialTheme.typography.titleSmall,
                )
            }
            Spacer(Modifier.height(12.dp))

            // The calculator keyboard yields to the system keyboard while the note is edited.
            if (!noteFocused) {
                CalculatorKeyboard(onKey = { focus.clearFocus(); vm.onKey(it) })
            }
        }
    }

    if (pickDate) {
        JalaliDatePickerDialog(s.date, onPick = { vm.setDate(it); pickDate = false }, onDismiss = { pickDate = false })
    }
}

@Composable
private fun KindSelector(kind: DraftKind, onSelect: (DraftKind) -> Unit) {
    val items = listOf(DraftKind.EXPENSE to "هزینه", DraftKind.INCOME to "درآمد", DraftKind.TRANSFER to "انتقال")
    Row(Modifier.fillMaxWidth().clip(CircleShape).background(AppTheme.money.chipBg).padding(4.dp)) {
        items.forEach { (k, label) ->
            val selected = k == kind
            val color = when (k) { DraftKind.EXPENSE -> Coral; DraftKind.INCOME -> Mint; DraftKind.TRANSFER -> Navy }
            Text(
                label,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.labelLarge,
                color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f).clip(CircleShape)
                    .background(if (selected) color else Color.Transparent)
                    .clickable { onSelect(k) }
                    .padding(vertical = 10.dp),
            )
        }
    }
}

@Composable
private fun Label(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted, modifier = Modifier.padding(top = 12.dp, bottom = 4.dp))
}

@Composable
private fun AccountChips(accounts: List<AccountEntity>, selectedId: Long?, onSelect: (Long) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        accounts.forEach { a ->
            FilterChip(
                selected = a.id == selectedId,
                onClick = { onSelect(a.id) },
                label = { Text(a.name) },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = Navy, selectedLabelColor = Color.White,
                    containerColor = MaterialTheme.colorScheme.surface,
                ),
            )
        }
    }
}

@Composable
private fun DateChips(date: JalaliDate, onSelect: (JalaliDate) -> Unit, onPick: () -> Unit) {
    val today = JalaliDate.today()
    val yesterday = today.plusDays(-1)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        FilterChip(selected = date == today, onClick = { onSelect(today) }, label = { Text("امروز") })
        FilterChip(selected = date == yesterday, onClick = { onSelect(yesterday) }, label = { Text("دیروز") })
        FilterChip(
            selected = date != today && date != yesterday,
            onClick = onPick,
            label = { Text("📅 " + date.formatLong()) },
        )
    }
}

/** "250000+18000×2" → "250,000 + 18,000 × 2" */
private fun groupExpression(raw: String): String {
    val sb = StringBuilder()
    val num = StringBuilder()
    fun flush() { if (num.isNotEmpty()) { sb.append(Money.group(num.toString().toLong())); num.clear() } }
    for (ch in raw) {
        if (ch.isDigit()) num.append(ch) else { flush(); sb.append(' ').append(ch).append(' ') }
    }
    flush()
    return sb.toString()
}
