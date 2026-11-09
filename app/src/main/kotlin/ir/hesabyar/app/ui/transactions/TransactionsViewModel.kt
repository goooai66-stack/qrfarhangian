package ir.hesabyar.app.ui.transactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.repository.TransactionFilter
import ir.hesabyar.domain.ledger.TransactionType
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update

data class TransactionsState(
    val filter: TransactionFilter = TransactionFilter(),
    val rows: List<TransactionRow> = emptyList(),
    val unconfirmedSms: Int = 0,
    val categories: List<CategoryEntity> = emptyList(),
    val accounts: List<AccountEntity> = emptyList(),
) {
    val incomeRial: Long get() = rows.filter { it.tx.type == TransactionType.INCOME }.sumOf { it.tx.amountRial }
    val expenseRial: Long get() = rows.filter { it.tx.type == TransactionType.EXPENSE }.sumOf { it.tx.amountRial }
}

private data class Lookups(val categories: List<CategoryEntity>, val accounts: List<AccountEntity>)

/** Instant search over thousands of rows: SQL-side filtering, indexed by (ledgerId, occurredAt). */
@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
class TransactionsViewModel(c: AppContainer) : ViewModel() {

    private val filter = MutableStateFlow(TransactionFilter())

    private val ledgerId = combine(c.db.ledgerDao().observeAll(), c.prefs.activeLedgerId) { list, id ->
        (list.firstOrNull { it.id == id } ?: list.firstOrNull())?.id
    }

    private val rows = combine(ledgerId, filter.debounce(150)) { id, f -> id to f }
        .flatMapLatest { (id, f) -> if (id == null) flowOf(emptyList()) else c.transactions.observeFiltered(id, f) }

    private val lookups = ledgerId.flatMapLatest { id ->
        if (id == null) flowOf(Lookups(emptyList(), emptyList()))
        else combine(c.db.categoryDao().observeByLedger(id), c.db.accountDao().observeByLedger(id)) { cat, acc -> Lookups(cat, acc) }
    }

    val state: StateFlow<TransactionsState> = combine(filter, rows, c.db.bankSmsDao().observeInbox(), lookups) { f, r, inbox, l ->
        TransactionsState(f, r, inbox.size, l.categories, l.accounts)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TransactionsState())

    fun setQuery(q: String) = filter.update { it.copy(query = q) }
    fun applyFilter(f: TransactionFilter) = filter.update { f.copy(query = it.query) }
    fun clearFilters() = filter.update { TransactionFilter(query = it.query) }
}
