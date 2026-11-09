package ir.hesabyar.app.ui.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.export.ExportedFile
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.report.ReportBuilder
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

data class ReportsState(
    val ledger: LedgerEntity? = null,
    val preset: ReportBuilder.Preset = ReportBuilder.Preset.THIS_MONTH,
    val report: ReportBuilder.PeriodReport? = null,
    val months: List<ReportBuilder.MonthBucket> = emptyList(),
    val categories: Map<Long, CategoryEntity> = emptyMap(),
    val exporting: Boolean = false,
)

enum class ExportKind { EXCEL, PDF }

@OptIn(ExperimentalCoroutinesApi::class)
class ReportsViewModel(private val c: AppContainer) : ViewModel() {

    private val preset = MutableStateFlow(ReportBuilder.Preset.THIS_MONTH)
    private val exporting = MutableStateFlow(false)

    private val ledger: Flow<LedgerEntity?> = combine(c.db.ledgerDao().observeAll(), c.prefs.activeLedgerId) { list, id ->
        list.firstOrNull { it.id == id } ?: list.firstOrNull()
    }

    val state: StateFlow<ReportsState> = combine(ledger, preset) { l, p -> l to p }.flatMapLatest { (l, p) ->
        if (l == null) return@flatMapLatest flowOf(ReportsState(preset = p))
        val today = JalaliDate.today()
        val (from, to, prevFrom, prevTo) = ReportBuilder.range(p, today)
        val chartEnd = if (to > today) today else to
        val chartStart = JalaliDate(chartEnd.year, chartEnd.month, 1).plusMonths(-5)
        val windowStart = minOf(prevFrom, chartStart)
        combine(
            c.db.transactionDao().observeReportRows(l.id, JalaliDate.toEpochMillis(windowStart), JalaliDate.toEpochMillis(to.plusDays(1))),
            c.db.categoryDao().observeByLedger(l.id),
        ) { rows, cats ->
            val entries = rows.map { ReportBuilder.Entry(it.occurredAt, it.type, it.amountRial, it.categoryId) }
            val previous = entries.filter { JalaliDate.fromEpochMillis(it.occurredAtMillis).let { d -> d >= prevFrom && d <= prevTo } }
            ReportsState(
                ledger = l, preset = p,
                report = ReportBuilder.period(entries, from, to, previous, today),
                months = ReportBuilder.monthly(entries, chartEnd, 6),
                categories = cats.associateBy { it.id },
            )
        }
    }.combine(exporting) { s, e -> s.copy(exporting = e) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ReportsState())

    fun setPreset(p: ReportBuilder.Preset) { preset.value = p }

    fun export(kind: ExportKind, onDone: (ExportedFile?) -> Unit) {
        val s = state.value
        val l = s.ledger ?: return onDone(null)
        val (from, to) = ReportBuilder.range(s.preset)
        exporting.value = true
        viewModelScope.launch {
            val file = runCatching {
                when (kind) {
                    ExportKind.EXCEL -> c.exporter.excel(l.id, from, to)
                    ExportKind.PDF -> c.exporter.pdf(l.id, from, to)
                }
            }.getOrNull()
            exporting.value = false
            onDone(file)
        }
    }
}
