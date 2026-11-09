package ir.hesabyar.app.ui.due

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.data.local.entity.ChequeDirection
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.DebtDirection
import ir.hesabyar.app.ui.components.AccountPicker
import ir.hesabyar.app.ui.components.AmountInputField
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.DateInput
import ir.hesabyar.app.ui.components.FieldLabel
import ir.hesabyar.app.ui.components.FormSheet
import ir.hesabyar.app.ui.components.Segmented
import ir.hesabyar.app.ui.components.SwitchRow
import ir.hesabyar.app.ui.components.TextInput
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.app.usecase.ChequeDraft
import ir.hesabyar.app.usecase.LoanDraft
import ir.hesabyar.app.usecase.SplitDraft
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.split.SplitCalculator
import ir.hesabyar.domain.text.PersianText

/** Shared save-state plumbing for the four forms. */
private class FormState {
    var error by mutableStateOf<String?>(null)
    var saving by mutableStateOf(false)
    fun submit(onDone: () -> Unit, call: ((String?) -> Unit) -> Unit) {
        saving = true; error = null
        call { msg -> saving = false; if (msg == null) onDone() else error = msg }
    }
}

// ================================================================== cheque

@Composable
fun ChequeSheet(vm: DueDatesViewModel, initialDirection: ChequeDirection, editing: ChequeEntity?, onDismiss: () -> Unit) {
    val s = vm.state.value
    val form = remember { FormState() }
    var direction by remember { mutableStateOf(editing?.direction ?: initialDirection) }
    var amount by remember { mutableStateOf(editing?.amountRial ?: 0L) }
    var amountOpen by remember { mutableStateOf(editing == null) }
    var due by remember { mutableStateOf(editing?.dueEpochDay?.let { JalaliDate.fromEpochDay(it) } ?: JalaliDate.today()) }
    var who by remember { mutableStateOf(editing?.counterpartyName.orEmpty()) }
    var sayad by remember { mutableStateOf(editing?.sayadId.orEmpty()) }
    var serial by remember { mutableStateOf(editing?.serial.orEmpty()) }
    var bank by remember { mutableStateOf(editing?.bank) }
    var account by remember { mutableStateOf(editing?.accountId ?: s.accounts.firstOrNull()?.id) }
    var reminders by remember { mutableStateOf(editing?.remindersEnabled ?: true) }
    var note by remember { mutableStateOf(editing?.note.orEmpty()) }

    FormSheet(
        title = if (editing == null) "ثبت چک" else "ویرایش چک",
        saveLabel = "ذخیره چک", error = form.error, saving = form.saving, onDismiss = onDismiss,
        onSave = {
            val ledger = s.ledger?.id ?: return@FormSheet
            form.submit(onDismiss) { cb ->
                vm.saveCheque(
                    ChequeDraft(editing?.id, ledger, direction, amount, due, who, sayad, serial, bank, account, note, reminders), cb,
                )
            }
        },
    ) {
        Segmented(
            listOf(ChequeDirection.RECEIVED to "دریافتی", ChequeDirection.ISSUED to "پرداختی"), direction, { direction = it },
            accent = { if (it == ChequeDirection.RECEIVED) Mint else Coral },
        )
        AmountInputField("مبلغ چک", amount, { amount = it }, amountOpen, { amountOpen = it })
        DateInput("تاریخ سررسید", due, { if (it != null) due = it })
        TextInput(if (direction == ChequeDirection.RECEIVED) "صادرکننده" else "در وجه", who, { who = it })
        TextInput("شناسه صیادی (۱۶ رقم، اختیاری)", sayad, { sayad = it.take(16) }, numeric = true)
        TextInput("سریال چک (اختیاری)", serial, { serial = it })
        BankPicker(bank) { bank = it }
        AccountPicker(if (direction == ChequeDirection.RECEIVED) "واریز به حساب هنگام پاس شدن" else "برداشت از حساب هنگام پاس شدن", s.accounts, account, { account = it })
        SwitchRow("یادآور ۳ روز قبل، ۱ روز قبل و روز سررسید", reminders, { reminders = it })
        TextInput("توضیحات", note, { note = it })
    }
}

@Composable
private fun BankPicker(bank: Bank?, onSelect: (Bank?) -> Unit) {
    var open by remember { mutableStateOf(false) }
    FieldLabel("بانک")
    OutlinedButton(onClick = { open = true }) { Text(bank?.persianName ?: "انتخاب بانک (اختیاری)") }
    DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
        DropdownMenuItem(text = { Text("بدون بانک") }, onClick = { onSelect(null); open = false })
        Bank.entries.filter { it != Bank.UNKNOWN }.forEach { b ->
            DropdownMenuItem(text = { Text(b.persianName) }, onClick = { onSelect(b); open = false })
        }
    }
}

// ================================================================== loan

@Composable
fun LoanSheet(vm: DueDatesViewModel, onDismiss: () -> Unit) {
    val s = vm.state.value
    val form = remember { FormState() }
    var title by remember { mutableStateOf("") }
    var lender by remember { mutableStateOf("") }
    var installment by remember { mutableStateOf(0L) }
    var principal by remember { mutableStateOf(0L) }
    var openField by remember { mutableStateOf(1) } // 1 = installment keyboard, 2 = principal keyboard, 0 = none
    var count by remember { mutableStateOf("") }
    var paid by remember { mutableStateOf("") }
    var firstDue by remember { mutableStateOf(JalaliDate.today().plusMonths(1)) }
    var account by remember { mutableStateOf(s.accounts.firstOrNull()?.id) }
    var autoDeduct by remember { mutableStateOf(true) }
    var reminders by remember { mutableStateOf(true) }

    val n = count.toIntOrNull() ?: 0
    FormSheet(
        title = "تعریف وام و دفترچه اقساط", saveLabel = "ساخت دفترچه اقساط", error = form.error, saving = form.saving, onDismiss = onDismiss,
        onSave = {
            val ledger = s.ledger?.id ?: return@FormSheet
            form.submit(onDismiss) { cb ->
                vm.createLoan(LoanDraft(ledger, title, lender, principal, installment, n, firstDue, paid.toIntOrNull() ?: 0, account, autoDeduct, reminders), cb)
            }
        },
    ) {
        TextInput("عنوان", title, { title = it }, placeholder = "مثلاً وام ازدواج، قسط گوشی")
        TextInput("وام‌دهنده (اختیاری)", lender, { lender = it }, placeholder = "بانک، فروشگاه، شخص")
        AmountInputField("مبلغ هر قسط", installment, { installment = it }, openField == 1, { openField = if (it) 1 else 0 })
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f)) { TextInput("تعداد کل اقساط", count, { count = it.take(3) }, numeric = true) }
            Column(Modifier.weight(1f)) { TextInput("پرداخت‌شده تاکنون", paid, { paid = it.take(3) }, numeric = true) }
        }
        DateInput("سررسید اولین قسط (روز ماه برای بقیه اقساط همین است)", firstDue, { if (it != null) firstDue = it })
        AmountInputField("مبلغ اصل وام (اختیاری)", principal, { principal = it }, openField == 2, { openField = if (it) 2 else 0 })
        if (n > 0 && installment > 0) {
            Text(
                PersianText.toPersianDigits("جمع بازپرداخت: ${Money.formatToman(installment * n)} تومان در $n قسط"),
                style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 8.dp),
            )
        }
        AccountPicker("حساب پرداخت اقساط", s.accounts, account, { account = it })
        SwitchRow("کسر خودکار از حساب پس از تایید پرداخت", autoDeduct, { autoDeduct = it })
        SwitchRow("یادآور سررسید اقساط", reminders, { reminders = it })
    }
}

// ================================================================== debt

@Composable
fun DebtSheet(vm: DueDatesViewModel, onDismiss: () -> Unit) {
    val form = remember { FormState() }
    var dir by remember { mutableStateOf(DebtDirection.THEY_OWE_ME) }
    var name by remember { mutableStateOf("") }
    var amount by remember { mutableStateOf(0L) }
    var open by remember { mutableStateOf(true) }
    var due by remember { mutableStateOf<JalaliDate?>(null) }
    var note by remember { mutableStateOf("") }
    FormSheet(
        title = "طلب یا بدهی", saveLabel = "ذخیره", error = form.error, saving = form.saving, onDismiss = onDismiss,
        onSave = { form.submit(onDismiss) { cb -> vm.addDebt(name, dir, amount, due, note, cb) } },
    ) {
        Segmented(
            listOf(DebtDirection.THEY_OWE_ME to "طلب دارم", DebtDirection.I_OWE_THEM to "بدهکارم"), dir, { dir = it },
            accent = { if (it == DebtDirection.THEY_OWE_ME) Mint else Coral },
        )
        TextInput("نام شخص", name, { name = it })
        AmountInputField("مبلغ", amount, { amount = it }, open, { open = it })
        DateInput("موعد بازپرداخت", due, { due = it }, optional = true)
        TextInput("بابت", note, { note = it })
    }
}

// ================================================================== split bill (دنگ)

@Composable
fun SplitBillSheet(vm: DueDatesViewModel, onDismiss: () -> Unit) {
    val s = vm.state.value
    val form = remember { FormState() }
    var title by remember { mutableStateOf("") }
    var total by remember { mutableStateOf(0L) }
    var open by remember { mutableStateOf(true) }
    val people = remember { mutableStateListOf(SplitDraft.ME to 1, "" to 1) }
    var payer by remember { mutableStateOf(SplitDraft.ME) }
    var account by remember { mutableStateOf(s.accounts.firstOrNull()?.id) }
    var category by remember { mutableStateOf<Long?>(null) }

    val preview = remember(total, people.toList(), payer) {
        val valid = people.map { it.first.trim() }
        if (total <= 0 || valid.any { it.isBlank() } || valid.toSet().size != valid.size || payer !in valid) null
        else runCatching { SplitCalculator.split(total, people.map { SplitCalculator.Participant(it.first.trim(), it.second) }, payer) }.getOrNull()
    }

    FormSheet(
        title = "ماشین‌حساب دنگ", saveLabel = "ثبت در طلب و بدهی", error = form.error, saving = form.saving, onDismiss = onDismiss,
        onSave = {
            val ledger = s.ledger?.id ?: return@FormSheet
            form.submit(onDismiss) { cb ->
                vm.splitBill(SplitDraft(ledger, title, total, people.map { it.first.trim() to it.second }, payer, account.takeIf { payer == SplitDraft.ME }, category), cb)
            }
        },
    ) {
        TextInput("بابت", title, { title = it }, placeholder = "سفر شمال، شام دورهمی، شارژ ساختمان")
        AmountInputField("مبلغ کل", total, { total = it }, open, { open = it })
        FieldLabel("افراد و سهم (×۲ برای زوج‌ها)")
        people.forEachIndexed { i, (name, weight) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = name, onValueChange = { v -> if (i != 0) people[i] = v to weight },
                    enabled = i != 0, singleLine = true, placeholder = { Text("نام") }, modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(4.dp))
                TextButton(onClick = { people[i] = name to (if (weight >= 5) 1 else weight + 1) }) {
                    Text(PersianText.toPersianDigits("×$weight"))
                }
                if (i != 0) IconButton(onClick = { if (payer == name) payer = SplitDraft.ME; people.removeAt(i) }) {
                    Icon(Icons.Filled.Close, contentDescription = "حذف")
                }
            }
            preview?.getOrNull(i)?.let {
                Text(Money.formatTomanWithUnit(it.amountRial), style = MaterialTheme.typography.labelMedium, color = AppTheme.money.gold, modifier = Modifier.padding(start = 8.dp, bottom = 4.dp))
            }
        }
        TextButton(onClick = { people.add("" to 1) }) {
            Icon(Icons.Filled.Add, contentDescription = null); Text("افزودن نفر")
        }
        FieldLabel("چه کسی پرداخت کرد؟")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            people.map { it.first.trim() }.filter { it.isNotBlank() }.distinct().forEach { n ->
                FilterChip(selected = payer == n, onClick = { payer = n }, label = { Text(n) })
            }
        }
        if (payer == SplitDraft.ME) {
            AccountPicker("کل مبلغ از کدام حساب پرداخت شد؟", s.accounts, account, { account = it })
            FieldLabel("دسته‌بندی هزینه")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                s.expenseCategories.forEach { c ->
                    FilterChip(selected = category == c.id, onClick = { category = if (category == c.id) null else c.id }, label = { Text("${c.icon} ${c.name}") })
                }
            }
            Text("سهم بقیه به‌عنوان «طلب» ثبت می‌شود.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 6.dp))
        } else {
            Text("سهم شما به‌عنوان «بدهی به $payer» ثبت می‌شود.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.padding(top = 6.dp))
        }
    }
}

// ================================================================== settle debt

@Composable
fun SettleDebtSheet(vm: DueDatesViewModel, debtId: Long, remainingRial: Long, theyOweMe: Boolean, onDismiss: () -> Unit) {
    val s = vm.state.value
    var amount by remember { mutableStateOf(remainingRial) }
    var open by remember { mutableStateOf(false) }
    var account by remember { mutableStateOf(s.accounts.firstOrNull()?.id) }
    FormSheet(
        title = if (theyOweMe) "دریافت طلب" else "پرداخت بدهی", saveLabel = "ثبت تسویه", error = null, saving = false, onDismiss = onDismiss,
        onSave = { if (amount > 0) { vm.settleDebt(debtId, amount, account); onDismiss() } },
    ) {
        AmountInputField("مبلغ (پیش‌فرض: کل باقیمانده)", amount, { amount = it }, open, { open = it })
        AccountPicker(if (theyOweMe) "به کدام حساب واریز شد؟" else "از کدام حساب پرداخت شد؟", s.accounts, account, { account = it })
        Spacer(Modifier.height(4.dp))
        AppCard { Text("با «بدون حساب» فقط طلب/بدهی تسویه می‌شود و موجودی تغییری نمی‌کند.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted) }
    }
}
