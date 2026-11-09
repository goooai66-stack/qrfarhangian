package ir.hesabyar.app.ui.transaction

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.AccountKind
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.data.repository.TransactionDraft
import ir.hesabyar.app.ui.components.CalcKey
import ir.hesabyar.app.ui.components.apply
import ir.hesabyar.domain.calc.AmountExpression
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.voice.VoiceTransactionParser
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Calendar

data class AddTxState(
    val kind: DraftKind = DraftKind.EXPENSE,
    val expr: AmountExpression = AmountExpression.EMPTY,
    val ledgerId: Long = 0,
    val accounts: List<AccountEntity> = emptyList(),
    private val allCategories: List<CategoryEntity> = emptyList(),
    val accountId: Long? = null,
    val toAccountId: Long? = null,
    val categoryId: Long? = null,
    val date: JalaliDate = JalaliDate.today(),
    val note: String = "",
    val error: String? = null,
    val saving: Boolean = false,
    val saved: Boolean = false,
    /** Set when the form was pre-filled from speech; shown as a review hint. */
    val voiceTranscript: String? = null,
) {
    val categories: List<CategoryEntity>
        get() = when (kind) {
            DraftKind.EXPENSE -> allCategories.filter { it.kind == CategoryKind.EXPENSE }
            DraftKind.INCOME -> allCategories.filter { it.kind == CategoryKind.INCOME }
            DraftKind.TRANSFER -> emptyList()
        }
    val amountToman: Long get() = expr.evaluate()?.coerceAtLeast(0) ?: 0
    fun withCategories(list: List<CategoryEntity>) = copy(allCategories = list)
}

@OptIn(ExperimentalCoroutinesApi::class)
class AddTransactionViewModel(private val c: AppContainer) : ViewModel() {

    private val _state = MutableStateFlow(AddTxState())
    val state: StateFlow<AddTxState> = _state.asStateFlow()
    private var loadJob: Job? = null

    /**
     * Called every time the sheet opens: fresh form, same ViewModel.
     * With [voiceTranscript], the form is pre-filled from speech (amount, type, account, category)
     * and the user only reviews and taps save.
     */
    fun start(kind: DraftKind, voiceTranscript: String? = null) {
        _state.value = AddTxState(kind = kind, date = JalaliDate.today(), voiceTranscript = voiceTranscript)
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            val ledgers = c.db.ledgerDao().observeAll().first { it.isNotEmpty() }
            val ledgerId = ledgers.firstOrNull { it.id == c.prefs.activeLedgerId.value }?.id ?: ledgers.first().id
            var voicePending = voiceTranscript != null
            combine(c.db.accountDao().observeByLedger(ledgerId), c.db.categoryDao().observeByLedger(ledgerId)) { a, cat -> a to cat }
                .collect { (accounts, categories) ->
                    // Decide outside update{}: its lambda may be retried and must stay side-effect free.
                    val applyVoiceNow = voicePending
                    voicePending = false
                    _state.update { s ->
                        var next = s.copy(
                            ledgerId = ledgerId,
                            accounts = accounts,
                            accountId = s.accountId ?: accounts.firstOrNull()?.id,
                            toAccountId = s.toAccountId ?: accounts.getOrNull(1)?.id,
                        ).withCategories(categories)
                        if (applyVoiceNow && voiceTranscript != null) next = applyVoice(next, voiceTranscript, accounts, categories)
                        next
                    }
                }
        }
    }

    private fun applyVoice(s: AddTxState, transcript: String, accounts: List<AccountEntity>, categories: List<CategoryEntity>): AddTxState {
        fun candidates(kind: CategoryKind) = categories.filter { it.kind == kind }.map { VoiceTransactionParser.CategoryCandidate(it.id, it.name) }
        val r = VoiceTransactionParser.parse(transcript, candidates(CategoryKind.EXPENSE), candidates(CategoryKind.INCOME))
        fun accountFor(bank: Bank?) = bank?.let { b -> accounts.firstOrNull { it.bank == b } }
        val cash = accounts.firstOrNull { it.kind == AccountKind.CASH }
        val kind = when (r.kind) {
            VoiceTransactionParser.Kind.EXPENSE -> DraftKind.EXPENSE
            VoiceTransactionParser.Kind.INCOME -> DraftKind.INCOME
            VoiceTransactionParser.Kind.TRANSFER -> DraftKind.TRANSFER
        }
        val from = accountFor(r.banks.getOrNull(0)) ?: if (r.cash) cash else null
        val to = when {
            kind != DraftKind.TRANSFER -> null
            accountFor(r.banks.getOrNull(1)) != null -> accountFor(r.banks.getOrNull(1))
            r.cash && from != cash -> cash
            else -> null
        }
        return s.copy(
            kind = kind,
            expr = r.amountToman?.let { AmountExpression.ofValue(it) } ?: s.expr,
            accountId = from?.id ?: s.accountId,
            toAccountId = to?.id ?: s.toAccountId,
            categoryId = r.categoryId,
            note = transcript.take(200),
            error = if (r.amountToman == null) "مبلغ از گفتار تشخیص داده نشد؛ لطفاً وارد کنید" else null,
        )
    }

    fun setKind(kind: DraftKind) = _state.update { it.copy(kind = kind, categoryId = null, error = null) }
    fun onKey(key: CalcKey) = _state.update { it.copy(expr = it.expr.apply(key), error = null) }
    fun selectAccount(id: Long) = _state.update { it.copy(accountId = id, error = null) }
    fun selectToAccount(id: Long) = _state.update { it.copy(toAccountId = id, error = null) }
    fun selectCategory(id: Long) = _state.update { it.copy(categoryId = if (it.categoryId == id) null else id) }
    fun setDate(date: JalaliDate) = _state.update { it.copy(date = date) }
    fun setNote(note: String) = _state.update { it.copy(note = note.take(200)) }

    fun save() {
        val s = _state.value
        if (s.saving) return
        val error = when {
            s.amountToman <= 0 -> "مبلغ را وارد کنید"
            s.accountId == null -> "یک حساب انتخاب کنید"
            s.kind == DraftKind.TRANSFER && (s.toAccountId == null || s.toAccountId == s.accountId) -> "حساب مقصد باید با مبدأ متفاوت باشد"
            else -> null
        }
        if (error != null) { _state.update { it.copy(error = error) }; return }

        _state.update { it.copy(saving = true) }
        viewModelScope.launch {
            runCatching {
                c.transactions.save(
                    TransactionDraft(
                        ledgerId = s.ledgerId, kind = s.kind, amountRial = Money.tomanToRial(s.amountToman),
                        accountId = s.accountId!!, toAccountId = s.toAccountId.takeIf { s.kind == DraftKind.TRANSFER },
                        categoryId = s.categoryId, occurredAt = occurredAt(s.date), note = s.note,
                    ),
                )
            }.onSuccess { _state.update { it.copy(saving = false, saved = true) } }
                .onFailure { _state.update { it.copy(saving = false, error = "ثبت انجام نشد، دوباره تلاش کنید") } }
        }
    }

    /** Today → now. A past day → that day at the current clock time (keeps intra-day order natural). */
    private fun occurredAt(date: JalaliDate): Long {
        val now = System.currentTimeMillis()
        if (date == JalaliDate.fromEpochMillis(now)) return now
        val cal = Calendar.getInstance(JalaliDate.TEHRAN).apply { timeInMillis = now }
        return JalaliDate.toEpochMillis(date, cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
    }
}
