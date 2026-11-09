package ir.hesabyar.app.ui.due

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.dao.DebtRow
import ir.hesabyar.app.data.local.dao.InstallmentRow
import ir.hesabyar.app.data.local.dao.LoanSummary
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.local.entity.ChequeDirection
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.ChequeStatus
import ir.hesabyar.app.data.local.entity.DebtDirection
import ir.hesabyar.app.data.local.entity.InstallmentEntity
import ir.hesabyar.app.data.local.entity.InstallmentStatus
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.usecase.ChequeDraft
import ir.hesabyar.app.usecase.DueValidationException
import ir.hesabyar.app.usecase.LoanDraft
import ir.hesabyar.app.usecase.SplitDraft
import ir.hesabyar.domain.calendar.JalaliDate
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class DueSection(val label: String) { CALENDAR("تقویم"), CHEQUES("چک‌ها"), LOANS("اقساط"), DEBTS("طلب و بدهی") }

enum class EntryKind { CHEQUE_IN, CHEQUE_OUT, INSTALLMENT, DEBT_IN, DEBT_OUT }

/** One row in the calendar's day list, whatever its source table. */
data class DueEntry(
    val kind: EntryKind,
    val refId: Long,
    val title: String,
    val subtitle: String,
    val amountRial: Long,
    val dueEpochDay: Long,
    val done: Boolean,
) {
    val isIncoming: Boolean get() = kind == EntryKind.CHEQUE_IN || kind == EntryKind.DEBT_IN
}

data class DueState(
    val ledger: LedgerEntity? = null,
    val accounts: List<AccountEntity> = emptyList(),
    val expenseCategories: List<CategoryEntity> = emptyList(),
    val year: Int = JalaliDate.today().year,
    val month: Int = JalaliDate.today().month,
    val selected: JalaliDate? = null,
    val monthEntries: List<DueEntry> = emptyList(),
    val cheques: List<ChequeEntity> = emptyList(),
    val loans: List<LoanSummary> = emptyList(),
    val debts: List<DebtRow> = emptyList(),
) {
    val dayEntries: List<DueEntry>
        get() = selected?.toEpochDay()?.let { d -> monthEntries.filter { it.dueEpochDay == d } } ?: monthEntries
    val monthIncomingRial: Long get() = monthEntries.filter { !it.done && it.isIncoming }.sumOf { it.amountRial }
    val monthOutgoingRial: Long get() = monthEntries.filter { !it.done && !it.isIncoming }.sumOf { it.amountRial }
    val theyOweMeRial: Long get() = debts.filter { it.debt.direction == DebtDirection.THEY_OWE_ME }.sumOf { it.debt.amountRial - it.debt.settledRial }
    val iOweRial: Long get() = debts.filter { it.debt.direction == DebtDirection.I_OWE_THEM }.sumOf { it.debt.amountRial - it.debt.settledRial }
}

private data class Scoped(
    val accounts: List<AccountEntity>,
    val categories: List<CategoryEntity>,
    val cheques: List<ChequeEntity>,
    val loans: List<LoanSummary>,
    val debts: List<DebtRow>,
)

@OptIn(ExperimentalCoroutinesApi::class)
class DueDatesViewModel(private val c: AppContainer) : ViewModel() {

    private val ym = MutableStateFlow(JalaliDate.today().let { it.year to it.month })
    private val selected = MutableStateFlow<JalaliDate?>(null)

    private val ledger: Flow<LedgerEntity?> = combine(c.db.ledgerDao().observeAll(), c.prefs.activeLedgerId) { list, id ->
        list.firstOrNull { it.id == id } ?: list.firstOrNull()
    }

    private val scoped: Flow<Scoped?> = ledger.flatMapLatest { l ->
        if (l == null) flowOf(null) else combine(
            c.db.accountDao().observeByLedger(l.id),
            c.db.categoryDao().observeByLedger(l.id),
            c.db.planningDao().observeCheques(l.id),
            c.db.planningDao().observeLoanSummaries(l.id),
            c.db.planningDao().observeDebts(l.id),
        ) { a, cat, ch, lo, de -> Scoped(a, cat, ch, lo, de) }
    }

    private val monthInstallments: Flow<List<InstallmentRow>> = combine(ledger, ym) { l, m -> l to m }.flatMapLatest { (l, m) ->
        if (l == null) flowOf(emptyList()) else {
            val first = JalaliDate(m.first, m.second, 1)
            val last = JalaliDate(m.first, m.second, JalaliDate.monthLength(m.first, m.second))
            c.db.planningDao().observeInstallmentsBetween(l.id, first.toEpochDay(), last.toEpochDay())
        }
    }

    val state: StateFlow<DueState> = combine(ledger, scoped, monthInstallments, ym, selected) { l, s, inst, m, sel ->
        val first = JalaliDate(m.first, m.second, 1).toEpochDay()
        val last = JalaliDate(m.first, m.second, JalaliDate.monthLength(m.first, m.second)).toEpochDay()
        DueState(
            ledger = l,
            accounts = s?.accounts.orEmpty(),
            expenseCategories = s?.categories.orEmpty().filter { it.kind == CategoryKind.EXPENSE },
            year = m.first, month = m.second, selected = sel,
            monthEntries = if (s == null) emptyList() else buildEntries(s, inst, first..last),
            cheques = s?.cheques.orEmpty(), loans = s?.loans.orEmpty(), debts = s?.debts.orEmpty(),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DueState())

    private fun buildEntries(s: Scoped, installments: List<InstallmentRow>, range: LongRange): List<DueEntry> {
        val out = mutableListOf<DueEntry>()
        s.cheques.filter { it.dueEpochDay in range && it.status != ChequeStatus.CANCELLED }.forEach { ch ->
            val received = ch.direction == ChequeDirection.RECEIVED
            out += DueEntry(
                if (received) EntryKind.CHEQUE_IN else EntryKind.CHEQUE_OUT, ch.id,
                if (received) "چک دریافتی از ${ch.counterpartyName}" else "چک پرداختی به ${ch.counterpartyName}",
                chequeStatusLabel(ch.status), ch.amountRial, ch.dueEpochDay, ch.status != ChequeStatus.PENDING,
            )
        }
        installments.forEach { r ->
            val i = r.installment
            out += DueEntry(
                EntryKind.INSTALLMENT, i.id, "قسط ${r.loanTitle}", "قسط ${fa(i.number)} از ${fa(r.totalInstallments)}",
                i.amountRial, i.dueEpochDay, i.status == InstallmentStatus.PAID,
            )
        }
        s.debts.forEach { r ->
            val d = r.debt
            val due = d.dueEpochDay ?: return@forEach
            if (due !in range) return@forEach
            val theyOwe = d.direction == DebtDirection.THEY_OWE_ME
            out += DueEntry(
                if (theyOwe) EntryKind.DEBT_IN else EntryKind.DEBT_OUT, d.id,
                if (theyOwe) "طلب از ${r.personName}" else "بدهی به ${r.personName}", d.note,
                d.amountRial - d.settledRial, due, d.settledRial >= d.amountRial,
            )
        }
        return out.sortedWith(compareBy<DueEntry> { it.dueEpochDay }.thenBy { it.done })
    }

    // ---------------------------------------------------------------- navigation
    fun prevMonth() = shiftMonth(-1)
    fun nextMonth() = shiftMonth(+1)
    private fun shiftMonth(delta: Int) {
        val (y, m) = ym.value
        val d = JalaliDate(y, m, 1).plusMonths(delta)
        ym.value = d.year to d.month
        selected.value = null
    }
    fun select(date: JalaliDate) { selected.value = if (selected.value == date) null else date }

    fun installments(loanId: Long): Flow<List<InstallmentEntity>> = c.db.planningDao().observeInstallments(loanId)

    // ---------------------------------------------------------------- actions (result: null = ok, else message)
    private fun action(onResult: (String?) -> Unit = {}, block: suspend () -> Unit) = viewModelScope.launch {
        val msg = try { block(); null } catch (e: DueValidationException) { e.message } catch (e: Exception) { "عملیات انجام نشد" }
        onResult(msg)
    }

    fun saveCheque(d: ChequeDraft, onResult: (String?) -> Unit) = action(onResult) { c.dues.saveCheque(d) }
    fun clearCheque(id: Long) = action { c.dues.clearCheque(id) }
    fun bounceCheque(id: Long) = action { c.dues.bounceCheque(id) }
    fun reopenCheque(id: Long) = action { c.dues.reopenCheque(id) }
    fun deleteCheque(id: Long) = action { c.dues.deleteCheque(id) }

    fun createLoan(d: LoanDraft, onResult: (String?) -> Unit) = action(onResult) { c.dues.createLoan(d) }
    fun payInstallment(id: Long) = action { c.dues.payInstallment(id) }
    fun undoInstallment(id: Long) = action { c.dues.undoInstallment(id) }
    fun deleteLoan(id: Long) = action { c.dues.deleteLoan(id) }

    fun addDebt(name: String, dir: DebtDirection, rial: Long, due: JalaliDate?, note: String, onResult: (String?) -> Unit) =
        action(onResult) { c.dues.addDebt(requireLedger(), name, dir, rial, due, note) }
    fun settleDebt(id: Long, rial: Long, accountId: Long?) = action { c.dues.settleDebt(id, rial, accountId) }
    fun deleteDebt(id: Long) = action { c.dues.deleteDebt(id) }
    fun splitBill(d: SplitDraft, onResult: (String?) -> Unit) = action(onResult) { c.dues.splitBill(d) }

    fun requireLedger(): Long = state.value.ledger?.id ?: throw DueValidationException("دفتری انتخاب نشده است")

    companion object {
        fun chequeStatusLabel(s: ChequeStatus) = when (s) {
            ChequeStatus.PENDING -> "در جریان"
            ChequeStatus.CLEARED -> "پاس شده"
            ChequeStatus.BOUNCED -> "برگشتی"
            ChequeStatus.CANCELLED -> "باطل شده"
            ChequeStatus.ENDORSED -> "واگذار شده"
        }
        private fun fa(n: Int) = ir.hesabyar.domain.text.PersianText.toPersianDigits(n.toString())
    }
}
