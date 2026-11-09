package ir.hesabyar.app.ui.tools

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.app.data.local.entity.SavingsDepositEntity
import ir.hesabyar.app.data.local.entity.SavingsGoalEntity
import ir.hesabyar.app.data.local.entity.SavingsUnit
import ir.hesabyar.app.data.repository.RefreshResult
import ir.hesabyar.app.usecase.DueValidationException
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.savings.InflationShield
import ir.hesabyar.domain.text.PersianText
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
import java.math.BigDecimal

data class GoalUi(
    val goal: SavingsGoalEntity,
    val deposits: List<SavingsDepositEntity>,
    val currentPriceRial: Long?,
    val report: InflationShield.Report,
    val curve: List<InflationShield.CurvePoint>,
)

data class ToolsState(
    val ledger: LedgerEntity? = null,
    val rates: Map<RateKey, RateEntity> = emptyMap(),
    val hasOnlineSource: Boolean = false,
    val refreshing: Boolean = false,
    val refreshMessage: String? = null,
    val accounts: List<AccountEntity> = emptyList(),
    val goals: List<GoalUi> = emptyList(),
) {
    fun priceFor(unit: SavingsUnit): Long? = rates[unit.rateKey()]?.priceRial
}

fun SavingsUnit.rateKey(): RateKey = when (this) {
    SavingsUnit.GOLD_18K_GRAM -> RateKey.GOLD_18K_GRAM
    SavingsUnit.USD -> RateKey.USD
    SavingsUnit.USDT -> RateKey.USDT
}

fun SavingsUnit.label(): String = when (this) {
    SavingsUnit.GOLD_18K_GRAM -> "گرم طلای ۱۸"
    SavingsUnit.USD -> "دلار"
    SavingsUnit.USDT -> "تتر"
}

/** 3250 milli-grams → «۳٫۲۵ گرم طلای ۱۸» */
fun formatUnits(milli: Long, unit: SavingsUnit): String {
    val plain = BigDecimal(milli).movePointLeft(3).stripTrailingZeros().toPlainString()
    return PersianText.toPersianDigits(plain).replace('.', '٫') + " " + unit.label()
}

private data class RefreshUi(val refreshing: Boolean = false, val message: String? = null)

private data class Snapshot(val accounts: List<AccountEntity>, val goals: List<SavingsGoalEntity>, val deposits: List<SavingsDepositEntity>)

@OptIn(ExperimentalCoroutinesApi::class)
class ToolsViewModel(private val c: AppContainer) : ViewModel() {

    private val ui = MutableStateFlow(RefreshUi())

    private val ledger: Flow<LedgerEntity?> = combine(c.db.ledgerDao().observeAll(), c.prefs.activeLedgerId) { list, id ->
        list.firstOrNull { it.id == id } ?: list.firstOrNull()
    }

    private val snapshot: Flow<Snapshot?> = ledger.flatMapLatest { l ->
        if (l == null) flowOf(null) else combine(
            c.db.accountDao().observeByLedger(l.id), c.db.planningDao().observeGoals(l.id), c.db.planningDao().observeDepositsByLedger(l.id),
        ) { a, g, d -> Snapshot(a, g, d) }
    }

    val state: StateFlow<ToolsState> = combine(ledger, c.rates.observe(), snapshot, ui) { l, rates, snap, u ->
        val today = JalaliDate.today().toEpochDay()
        val allDeposits = snap?.deposits.orEmpty()
        val goals = snap?.goals.orEmpty().map { g ->
            val deps = allDeposits.filter { it.goalId == g.id }
            val price = rates[g.unit.rateKey()]?.priceRial
            val domainDeps = deps.map { InflationShield.Deposit(it.amountRial, it.unitPriceRialAtDeposit, it.depositedAt) }
            GoalUi(
                g, deps, price,
                InflationShield.report(g.targetMilliUnits, domainDeps, price ?: 0, today, g.deadlineEpochDay),
                InflationShield.curve(domainDeps, price ?: 0),
            )
        }
        ToolsState(l, rates, c.rates.hasOnlineSource, u.refreshing, u.message, snap?.accounts.orEmpty(), goals)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ToolsState())

    init { viewModelScope.launch { c.rates.refreshIfStale() } }

    fun refresh() = viewModelScope.launch {
        ui.value = RefreshUi(refreshing = true)
        val msg = when (c.rates.refresh()) {
            RefreshResult.UPDATED -> "نرخ‌ها به‌روز شد"
            RefreshResult.NO_SOURCE -> "منبع نرخ آنلاین تنظیم نشده؛ نرخ را دستی ثبت کنید"
            RefreshResult.FAILED -> "اتصال برقرار نشد؛ آخرین نرخ ذخیره‌شده نمایش داده می‌شود"
            RefreshResult.REJECTED -> "نرخ دریافتی غیرعادی بود و اعمال نشد"
        }
        ui.value = RefreshUi(message = msg)
    }

    fun setManualRate(key: RateKey, rial: Long) = viewModelScope.launch { if (rial > 0) c.rates.setManual(key, rial) }

    private fun action(onResult: (String?) -> Unit, block: suspend () -> Unit) = viewModelScope.launch {
        onResult(try { block(); null } catch (e: DueValidationException) { e.message } catch (_: Exception) { "عملیات انجام نشد" })
    }

    fun createGoal(title: String, unit: SavingsUnit, target: BigDecimal?, deadline: JalaliDate?, onResult: (String?) -> Unit) = action(onResult) {
        val l = state.value.ledger ?: throw DueValidationException("دفتری انتخاب نشده است")
        c.savings.createGoal(l.id, title, unit, target ?: BigDecimal.ZERO, deadline)
    }

    fun deposit(goalId: Long, amountRial: Long, unitPriceRial: Long, fromAccountId: Long?, onResult: (String?) -> Unit) =
        action(onResult) { c.savings.deposit(goalId, amountRial, unitPriceRial, fromAccountId) }

    fun deleteDeposit(id: Long) = viewModelScope.launch { c.savings.deleteDeposit(id) }
    fun archiveGoal(id: Long) = viewModelScope.launch { c.savings.archiveGoal(id) }
}
