package ir.hesabyar.app.ui.due

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.data.local.dao.DebtRow
import ir.hesabyar.app.data.local.dao.LoanSummary
import ir.hesabyar.app.data.local.entity.ChequeDirection
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.ChequeStatus
import ir.hesabyar.app.data.local.entity.DebtDirection
import ir.hesabyar.app.data.local.entity.InstallmentStatus
import ir.hesabyar.app.data.local.entity.LoanStatus
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.JalaliMonthCalendar
import ir.hesabyar.app.ui.components.SectionHeader
import ir.hesabyar.app.ui.components.Segmented
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText

private enum class Sheet { CHEQUE_IN, CHEQUE_OUT, LOAN, DEBT, SPLIT }

fun EntryKind.color(): Color = when (this) {
    EntryKind.CHEQUE_IN, EntryKind.DEBT_IN -> Mint
    EntryKind.CHEQUE_OUT, EntryKind.DEBT_OUT -> Coral
    EntryKind.INSTALLMENT -> Gold
}

/**
 * «سررسیدها». No ad slot at all on this tab (AdPolicy allows only user-initiated rewarded here,
 * and nothing in this screen offers one) — due dates are stressful enough.
 */
@Composable
fun DueDatesScreen(vm: DueDatesViewModel, contentPadding: PaddingValues) {
    val s by vm.state.collectAsStateWithLifecycle()
    var section by rememberSaveable { mutableStateOf(DueSection.CALENDAR) }
    var sheet by remember { mutableStateOf<Sheet?>(null) }
    var editingCheque by remember { mutableStateOf<ChequeEntity?>(null) }
    var settling by remember { mutableStateOf<DebtRow?>(null) }
    var addMenu by remember { mutableStateOf(false) }
    val today = JalaliDate.today()

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.fillMaxSize().statusBarsPadding(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = contentPadding.calculateBottomPadding() + 88.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Text("سررسیدها", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(8.dp))
                Segmented(DueSection.entries.map { it to it.label }, section, { section = it })
            }

            when (section) {
                DueSection.CALENDAR -> {
                    item {
                        AppCard {
                            val markers = s.monthEntries.filter { !it.done }.groupBy({ it.dueEpochDay }, { it.kind.color() })
                            JalaliMonthCalendar(s.year, s.month, today, s.selected, markers, vm::select, vm::prevMonth, vm::nextMonth)
                        }
                    }
                    item {
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            SummaryTile("ورودی این ماه", s.monthIncomingRial, AppTheme.money.income, Modifier.weight(1f))
                            SummaryTile("خروجی این ماه", s.monthOutgoingRial, AppTheme.money.expense, Modifier.weight(1f))
                        }
                    }
                    item {
                        SectionHeader(s.selected?.let { "سررسیدهای ${it.formatLong()}" } ?: "همه‌ی سررسیدهای این ماه")
                    }
                    if (s.dayEntries.isEmpty()) item { EmptyHint("سررسیدی برای این بازه ثبت نشده است.") }
                    items(s.dayEntries, key = { "${it.kind}-${it.refId}" }) { e ->
                        EntryRow(e, today, onAction = {
                            when (e.kind) {
                                EntryKind.CHEQUE_IN, EntryKind.CHEQUE_OUT -> vm.clearCheque(e.refId)
                                EntryKind.INSTALLMENT -> vm.payInstallment(e.refId)
                                else -> s.debts.firstOrNull { it.debt.id == e.refId }?.let { settling = it }
                            }
                        })
                    }
                }

                DueSection.CHEQUES -> {
                    val pending = s.cheques.filter { it.status == ChequeStatus.PENDING }
                    item {
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            SummaryTile("دریافتی در جریان", pending.filter { it.direction == ChequeDirection.RECEIVED }.sumOf { it.amountRial }, AppTheme.money.income, Modifier.weight(1f))
                            SummaryTile("پرداختی در جریان", pending.filter { it.direction == ChequeDirection.ISSUED }.sumOf { it.amountRial }, AppTheme.money.expense, Modifier.weight(1f))
                        }
                    }
                    if (s.cheques.isEmpty()) item { EmptyHint("هنوز چکی ثبت نشده. با دکمه «افزودن» چک دریافتی یا پرداختی ثبت کنید.") }
                    items(s.cheques, key = { "ch-${it.id}" }) { ch ->
                        ChequeCard(ch, today, vm, onEdit = { editingCheque = ch; sheet = if (ch.direction == ChequeDirection.RECEIVED) Sheet.CHEQUE_IN else Sheet.CHEQUE_OUT })
                    }
                }

                DueSection.LOANS -> {
                    if (s.loans.isEmpty()) item { EmptyHint("وام یا خرید قسطی ثبت نشده. دفترچه اقساط را با «افزودن» بسازید.") }
                    items(s.loans, key = { "loan-${it.loan.id}" }) { LoanCard(it, today, vm) }
                }

                DueSection.DEBTS -> {
                    item {
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            SummaryTile("طلب شما", s.theyOweMeRial, AppTheme.money.income, Modifier.weight(1f))
                            SummaryTile("بدهی شما", s.iOweRial, AppTheme.money.expense, Modifier.weight(1f))
                        }
                    }
                    item {
                        OutlinedButton(onClick = { sheet = Sheet.SPLIT }, modifier = Modifier.fillMaxWidth()) { Text("➗ ماشین‌حساب دنگ") }
                    }
                    if (s.debts.isEmpty()) item { EmptyHint("طلب یا بدهی ثبت نشده است.") }
                    items(s.debts, key = { "debt-${it.debt.id}" }) { d -> DebtCard(d, onSettle = { settling = d }, onDelete = { vm.deleteDebt(d.debt.id) }) }
                }
            }
        }

        Box(Modifier.align(Alignment.BottomEnd).padding(bottom = contentPadding.calculateBottomPadding() + 16.dp, end = 16.dp)) {
            ExtendedFloatingActionButton(
                onClick = { addMenu = true }, containerColor = Navy, contentColor = Color.White,
                icon = { Icon(Icons.Filled.Add, contentDescription = null) }, text = { Text("افزودن") },
            )
            DropdownMenu(expanded = addMenu, onDismissRequest = { addMenu = false }) {
                listOf(
                    Sheet.CHEQUE_IN to "چک دریافتی", Sheet.CHEQUE_OUT to "چک پرداختی", Sheet.LOAN to "وام / دفترچه اقساط",
                    Sheet.DEBT to "طلب یا بدهی", Sheet.SPLIT to "دنگ (تقسیم هزینه)",
                ).forEach { (k, label) ->
                    DropdownMenuItem(text = { Text(label) }, onClick = { addMenu = false; editingCheque = null; sheet = k })
                }
            }
        }
    }

    when (sheet) {
        Sheet.CHEQUE_IN -> ChequeSheet(vm, ChequeDirection.RECEIVED, editingCheque) { sheet = null; editingCheque = null }
        Sheet.CHEQUE_OUT -> ChequeSheet(vm, ChequeDirection.ISSUED, editingCheque) { sheet = null; editingCheque = null }
        Sheet.LOAN -> LoanSheet(vm) { sheet = null }
        Sheet.DEBT -> DebtSheet(vm) { sheet = null }
        Sheet.SPLIT -> SplitBillSheet(vm) { sheet = null }
        null -> Unit
    }
    settling?.let { d ->
        SettleDebtSheet(vm, d.debt.id, d.debt.amountRial - d.debt.settledRial, d.debt.direction == DebtDirection.THEY_OWE_ME) { settling = null }
    }
}

// ================================================================== pieces

@Composable
private fun SummaryTile(label: String, rial: Long, color: Color, modifier: Modifier) {
    AppCard(modifier) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted)
        Text(Money.formatToman(rial), style = MaterialTheme.typography.titleMedium, color = color)
    }
}

@Composable
private fun EmptyHint(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = AppTheme.money.muted, modifier = Modifier.padding(vertical = 16.dp))
}

private fun relative(today: JalaliDate, epochDay: Long): String {
    val diff = epochDay - today.toEpochDay()
    return when {
        diff == 0L -> "امروز"
        diff == 1L -> "فردا"
        diff == -1L -> "دیروز"
        diff > 1 -> PersianText.toPersianDigits("$diff روز دیگر")
        else -> PersianText.toPersianDigits("${-diff} روز گذشته")
    }
}

@Composable
private fun EntryRow(e: DueEntry, today: JalaliDate, onAction: () -> Unit) {
    AppCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(10.dp).clip(CircleShape).background(e.kind.color()))
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    e.title, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    textDecoration = if (e.done) TextDecoration.LineThrough else null,
                )
                Text(
                    listOf(JalaliDate.fromEpochDay(e.dueEpochDay).formatLong(), relative(today, e.dueEpochDay), e.subtitle).filter { it.isNotBlank() }.joinToString(" • "),
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
            }
            Text(Money.formatToman(e.amountRial), style = MaterialTheme.typography.titleSmall, color = if (e.isIncoming) AppTheme.money.income else AppTheme.money.expense)
        }
        if (!e.done) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                TextButton(onClick = onAction) {
                    Text(
                        when (e.kind) {
                            EntryKind.CHEQUE_IN, EntryKind.CHEQUE_OUT -> "پاس شد"
                            EntryKind.INSTALLMENT -> "پرداخت شد"
                            EntryKind.DEBT_IN -> "دریافت کردم"
                            EntryKind.DEBT_OUT -> "پرداخت کردم"
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun ChequeCard(ch: ChequeEntity, today: JalaliDate, vm: DueDatesViewModel, onEdit: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    val received = ch.direction == ChequeDirection.RECEIVED
    val statusColor = when (ch.status) {
        ChequeStatus.PENDING -> AppTheme.money.gold
        ChequeStatus.CLEARED -> AppTheme.money.income
        ChequeStatus.BOUNCED -> AppTheme.money.expense
        else -> AppTheme.money.muted
    }
    AppCard(onClick = onEdit) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (received) "دریافتی" else "پرداختی", style = MaterialTheme.typography.labelSmall, color = Color.White,
                modifier = Modifier.clip(CircleShape).background(if (received) Mint else Coral).padding(horizontal = 8.dp, vertical = 2.dp),
            )
            Spacer(Modifier.width(8.dp))
            Text(ch.counterpartyName, style = MaterialTheme.typography.titleSmall, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(DueDatesViewModel.chequeStatusLabel(ch.status), style = MaterialTheme.typography.labelMedium, color = statusColor)
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, contentDescription = "گزینه‌ها") }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    if (ch.status == ChequeStatus.PENDING) {
                        DropdownMenuItem(text = { Text("پاس شد") }, onClick = { menu = false; vm.clearCheque(ch.id) })
                        DropdownMenuItem(text = { Text("برگشت خورد") }, onClick = { menu = false; vm.bounceCheque(ch.id) })
                    } else {
                        DropdownMenuItem(text = { Text("بازگشت به «در جریان»") }, onClick = { menu = false; vm.reopenCheque(ch.id) })
                    }
                    DropdownMenuItem(text = { Text("ویرایش") }, onClick = { menu = false; onEdit() })
                    DropdownMenuItem(text = { Text("حذف", color = AppTheme.money.expense) }, onClick = { menu = false; vm.deleteCheque(ch.id) })
                }
            }
        }
        Text(Money.formatTomanWithUnit(ch.amountRial), style = MaterialTheme.typography.titleLarge, color = if (received) AppTheme.money.income else AppTheme.money.expense)
        Text(
            listOfNotNull(
                "سررسید ${JalaliDate.fromEpochDay(ch.dueEpochDay).formatLong()}",
                if (ch.status == ChequeStatus.PENDING) relative(today, ch.dueEpochDay) else null,
                ch.bank?.persianName,
                ch.sayadId?.let { "صیادی …" + PersianText.toPersianDigits(it.takeLast(4)) },
            ).joinToString(" • "),
            style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
        )
    }
}

@Composable
private fun LoanCard(l: LoanSummary, today: JalaliDate, vm: DueDatesViewModel) {
    var expanded by remember { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }
    val loan = l.loan
    val progress = if (loan.totalInstallments == 0) 0f else l.paidCount.toFloat() / loan.totalInstallments
    AppCard(onClick = { expanded = !expanded }) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(loan.title, style = MaterialTheme.typography.titleSmall)
                if (loan.lender.isNotBlank()) Text(loan.lender, style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
            }
            Text(Money.formatToman(loan.installmentAmountRial) + " / ماه", style = MaterialTheme.typography.labelLarge)
            Box {
                IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, contentDescription = "گزینه‌ها") }
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(text = { Text("حذف دفترچه", color = AppTheme.money.expense) }, onClick = { menu = false; vm.deleteLoan(loan.id) })
                }
            }
        }
        Spacer(Modifier.height(8.dp))
        LinearProgressIndicator(
            progress = { progress }, color = Mint, trackColor = AppTheme.money.chipBg,
            modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape),
        )
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                PersianText.toPersianDigits("${l.paidCount} قسط از ${loan.totalInstallments} قسط پرداخت شده"),
                style = MaterialTheme.typography.bodySmall, modifier = Modifier.weight(1f),
            )
            Text(
                "مانده: " + Money.formatToman(loan.installmentAmountRial * (loan.totalInstallments - l.paidCount)),
                style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
            )
        }
        if (loan.status == LoanStatus.SETTLED) {
            Text("✓ تسویه شد", color = AppTheme.money.income, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 6.dp))
        } else if (l.nextDueEpochDay != null && l.nextInstallmentId != null) {
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = AppTheme.money.hairline)
            Row(verticalAlignment = Alignment.CenterVertically) {
                val overdue = l.nextDueEpochDay < today.toEpochDay()
                Text(
                    "قسط بعدی: ${JalaliDate.fromEpochDay(l.nextDueEpochDay).formatLong()} (${relative(today, l.nextDueEpochDay)})",
                    style = MaterialTheme.typography.bodySmall, color = if (overdue) AppTheme.money.expense else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = { vm.payInstallment(l.nextInstallmentId) }) { Text("پرداخت شد") }
            }
        }
        if (expanded) {
            val list by remember(loan.id) { vm.installments(loan.id) }.collectAsState(initial = emptyList())
            list.forEach { i ->
                Row(Modifier.fillMaxWidth().clickable {
                    if (i.status == InstallmentStatus.PAID) vm.undoInstallment(i.id) else vm.payInstallment(i.id)
                }.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(if (i.status == InstallmentStatus.PAID) "✅" else "⬜")
                    Spacer(Modifier.width(8.dp))
                    Text(PersianText.toPersianDigits("قسط ${i.number}"), style = MaterialTheme.typography.bodySmall, modifier = Modifier.width(56.dp))
                    Text(JalaliDate.fromEpochDay(i.dueEpochDay).formatLong(), style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted, modifier = Modifier.weight(1f))
                    Text(Money.formatToman(i.amountRial), style = MaterialTheme.typography.bodySmall)
                }
            }
            Text("برای تغییر وضعیت هر قسط روی آن بزنید.", style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted)
        }
    }
}

@Composable
private fun DebtCard(d: DebtRow, onSettle: () -> Unit, onDelete: () -> Unit) {
    val debt = d.debt
    val left = debt.amountRial - debt.settledRial
    val theyOwe = debt.direction == DebtDirection.THEY_OWE_ME
    AppCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text((if (theyOwe) "طلب از " else "بدهی به ") + d.personName, style = MaterialTheme.typography.titleSmall)
                Text(
                    listOfNotNull(
                        debt.note.takeIf { it.isNotBlank() },
                        debt.dueEpochDay?.let { "موعد ${JalaliDate.fromEpochDay(it).formatLong()}" },
                        if (debt.splitGroupId != null) "دنگ" else null,
                    ).joinToString(" • "),
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
                )
            }
            Text(Money.formatToman(left), style = MaterialTheme.typography.titleSmall, color = if (theyOwe) AppTheme.money.income else AppTheme.money.expense)
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            if (left > 0) TextButton(onClick = onSettle) { Text(if (theyOwe) "دریافت کردم" else "پرداخت کردم") }
            else Text("✓ تسویه شد", color = AppTheme.money.income, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(8.dp))
            TextButton(onClick = onDelete) { Text("حذف", color = AppTheme.money.muted) }
        }
        if (left > 0 && debt.settledRial > 0) {
            Text("از " + Money.formatToman(debt.amountRial) + " تومان، " + Money.formatToman(debt.settledRial) + " تسویه شده", style = MaterialTheme.typography.labelSmall, color = AppTheme.money.muted)
        }
    }
}

