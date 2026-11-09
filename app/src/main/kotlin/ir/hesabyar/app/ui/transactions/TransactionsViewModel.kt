package ir.hesabyar.app.ui.transactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.data.local.entity.BankSmsEntity
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

data class TransactionsState(
    val query: String = "",
    val rows: List<TransactionRow> = emptyList(),
    val unconfirmedSms: Int = 0,
)

/** Step 1: text search. Step 2 adds Jalali date range, amount range, type and category filters. */
@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
class TransactionsViewModel(c: AppContainer) : ViewModel() {

    val query = MutableStateFlow("")

    private val ledgerId = combine(c.db.ledgerDao().observeAll(), c.prefs.activeLedgerId) { list, id ->
        (list.firstOrNull { it.id == id } ?: list.firstOrNull())?.id
    }

    private val rows = combine(ledgerId, query.debounce(150)) { id, q -> id to q }
        .flatMapLatest { (id, q) -> if (id == null) flowOf(emptyList()) else c.transactions.observeRows(id, q) }

    val state: StateFlow<TransactionsState> = combine(query, rows, c.db.bankSmsDao().observeInbox()) { q, r, inbox: List<BankSmsEntity> ->
        TransactionsState(q, r, inbox.size)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), TransactionsState())
}
