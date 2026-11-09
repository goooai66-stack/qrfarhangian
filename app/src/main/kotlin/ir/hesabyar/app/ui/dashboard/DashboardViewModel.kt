package ir.hesabyar.app.ui.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.BankSmsEntity
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.app.data.local.entity.SmsStatus
import ir.hesabyar.domain.ledger.LedgerMath
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** One SMS card on the dashboard; a self-transfer pair collapses into a single card. */
data class PendingSmsUi(
    val sms: BankSmsEntity,
    val pair: BankSmsEntity?,
    val accountName: String,
    val pairAccountName: String?,
    /** Best-matching categories first (by SMS channel), max 6: the one-tap row. */
    val suggestions: List<CategoryEntity>,
) {
    val isSelfTransfer: Boolean get() = sms.status == SmsStatus.SELF_TRANSFER && pair != null
}

data class DashboardState(
    val loading: Boolean = true,
    val ledgers: List<LedgerEntity> = emptyList(),
    val activeLedger: LedgerEntity? = null,
    val accounts: List<AccountEntity> = emptyList(),
    val month: LedgerMath.PeriodTotals = LedgerMath.PeriodTotals(0, 0),
    val pending: List<PendingSmsUi> = emptyList(),
    val recent: List<TransactionRow> = emptyList(),
    val rates: Map<RateKey, RateEntity> = emptyMap(),
) {
    val totalBalanceRial: Long get() = accounts.sumOf { it.currentBalanceRial }
}

private data class LedgerScoped(
    val accounts: List<AccountEntity>,
    val categories: List<CategoryEntity>,
    val month: LedgerMath.PeriodTotals,
    val recent: List<TransactionRow>,
)

@OptIn(ExperimentalCoroutinesApi::class)
class DashboardViewModel(private val c: AppContainer) : ViewModel() {

    private val ledgers = c.db.ledgerDao().observeAll()

    private val activeLedger: Flow<LedgerEntity?> = combine(ledgers, c.prefs.activeLedgerId) { list, id ->
        list.firstOrNull { it.id == id } ?: list.firstOrNull()
    }

    private val scoped: Flow<LedgerScoped?> = activeLedger.flatMapLatest { ledger ->
        if (ledger == null) flowOf(null)
        else combine(
            c.db.accountDao().observeByLedger(ledger.id),
            c.db.categoryDao().observeByLedger(ledger.id),
            c.transactions.observeMonthTotals(ledger.id),
            c.transactions.observeRows(ledger.id, limit = 6),
        ) { accounts, categories, month, recent -> LedgerScoped(accounts, categories, month, recent) }
    }

    val state: StateFlow<DashboardState> = combine(
        ledgers, activeLedger, scoped, c.db.bankSmsDao().observeInbox(), c.rates.observe(),
    ) { allLedgers, active, s, inbox, rates ->
        DashboardState(
            loading = active == null,
            ledgers = allLedgers,
            activeLedger = active,
            accounts = s?.accounts.orEmpty(),
            month = s?.month ?: LedgerMath.PeriodTotals(0, 0),
            pending = if (s == null) emptyList() else buildPending(inbox, s.accounts, s.categories),
            recent = s?.recent.orEmpty(),
            rates = rates,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DashboardState())

    private fun buildPending(inbox: List<BankSmsEntity>, accounts: List<AccountEntity>, categories: List<CategoryEntity>): List<PendingSmsUi> {
        val byId = accounts.associateBy { it.id }
        val inboxById = inbox.associateBy { it.id }
        val shownPairs = HashSet<Long>()
        return inbox.mapNotNull { sms ->
            val account = sms.matchedAccountId?.let(byId::get) ?: return@mapNotNull null // other ledger
            if (sms.id in shownPairs) return@mapNotNull null
            val pair = sms.selfTransferPairId?.let(inboxById::get)?.takeIf { sms.status == SmsStatus.SELF_TRANSFER }
            pair?.let { shownPairs += it.id }
            val kind = if (sms.isDebit) CategoryKind.EXPENSE else CategoryKind.INCOME
            val suggestions = categories.filter { it.kind == kind }
                .sortedByDescending { sms.channel in it.matchKeywords.split(',') }
                .take(6)
            PendingSmsUi(sms, pair, account.name, pair?.matchedAccountId?.let { byId[it]?.name ?: "حساب دیگر" }, suggestions)
        }.take(5)
    }

    init {
        // Cheap and polite: at most one feed request per 30 minutes, only while the app is open.
        viewModelScope.launch { c.rates.refreshIfStale() }
    }

    fun selectLedger(id: Long) = c.prefs.setActiveLedger(id)

    fun confirmSms(smsId: Long, categoryId: Long?) = viewModelScope.launch { c.confirmSms.confirm(smsId, categoryId) }
    fun dismissSms(smsId: Long) = viewModelScope.launch { c.confirmSms.dismiss(smsId) }
    fun notATransfer(smsId: Long) = viewModelScope.launch { c.confirmSms.splitSelfTransfer(smsId) }
    fun refreshRates() = viewModelScope.launch { c.rates.refresh() }
}
