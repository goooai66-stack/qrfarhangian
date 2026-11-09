package ir.hesabyar.domain.report

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.ledger.TransactionType

/**
 * Pure analytics over a ledger's movements. Transfers and adjustments never count as income
 * or expense (same rule as the dashboard), so moving money between your own cards or into a
 * gold savings goal does not distort any chart.
 */
object ReportBuilder {

    data class Entry(val occurredAtMillis: Long, val type: TransactionType, val amountRial: Long, val categoryId: Long?)

    data class MonthBucket(val year: Int, val month: Int, val incomeRial: Long, val expenseRial: Long) {
        val netRial: Long get() = incomeRial - expenseRial
        val label: String get() = JalaliDate.MONTH_NAMES[month - 1]
    }

    data class Slice(val categoryId: Long?, val amountRial: Long, val percent: Double, val isOther: Boolean = false)

    data class PeriodReport(
        val from: JalaliDate,
        val to: JalaliDate,
        val incomeRial: Long,
        val expenseRial: Long,
        val expenseSlices: List<Slice>,
        val incomeSlices: List<Slice>,
        val dailyAverageExpenseRial: Long,
        val previousExpenseRial: Long?,
        val transactionCount: Int,
    ) {
        val netRial: Long get() = incomeRial - expenseRial
        /** Share of income kept; null without income. */
        val savingsRatePercent: Double? get() = if (incomeRial <= 0) null else netRial * 100.0 / incomeRial
        /** Expense change versus the previous period of the same length. */
        val expenseChangePercent: Double?
            get() = previousExpenseRial?.takeIf { it > 0 }?.let { (expenseRial - it) * 100.0 / it }
    }

    /** Last [months] Jalali months ending with the month of [end], oldest first, zero-filled. */
    fun monthly(entries: List<Entry>, end: JalaliDate, months: Int = 6): List<MonthBucket> {
        val firstOfEnd = JalaliDate(end.year, end.month, 1)
        val keys = (months - 1 downTo 0).map { firstOfEnd.plusMonths(-it) }
        val sums = HashMap<Pair<Int, Int>, LongArray>()
        for (e in entries) {
            if (!e.type.countsInReports) continue
            val d = JalaliDate.fromEpochMillis(e.occurredAtMillis)
            val arr = sums.getOrPut(d.year to d.month) { LongArray(2) }
            if (e.type == TransactionType.INCOME) arr[0] += e.amountRial else arr[1] += e.amountRial
        }
        return keys.map { k -> sums[k.year to k.month].let { MonthBucket(k.year, k.month, it?.get(0) ?: 0, it?.get(1) ?: 0) } }
    }

    /**
     * Report for the inclusive Jalali range [from]..[to]. [previousEntries] (optional) is the
     * same-length period just before, used for the «نسبت به دوره قبل» comparison.
     */
    fun period(
        entries: List<Entry>,
        from: JalaliDate,
        to: JalaliDate,
        previousEntries: List<Entry>? = null,
        today: JalaliDate = JalaliDate.today(),
        maxSlices: Int = 6,
    ): PeriodReport {
        val inRange = entries.filter { inRange(it, from, to) }
        val income = inRange.filter { it.type == TransactionType.INCOME }
        val expense = inRange.filter { it.type == TransactionType.EXPENSE }
        val lastCountedDay = minOf(to.toEpochDay(), today.toEpochDay())
        val days = (lastCountedDay - from.toEpochDay() + 1).coerceAtLeast(1)
        val expenseTotal = expense.sumOf { it.amountRial }
        return PeriodReport(
            from = from, to = to,
            incomeRial = income.sumOf { it.amountRial },
            expenseRial = expenseTotal,
            expenseSlices = slices(expense, maxSlices),
            incomeSlices = slices(income, maxSlices),
            dailyAverageExpenseRial = expenseTotal / days,
            previousExpenseRial = previousEntries?.filter { it.type == TransactionType.EXPENSE }?.sumOf { it.amountRial },
            transactionCount = inRange.count { it.type.countsInReports },
        )
    }

    /** Largest categories first; everything beyond [max]-1 is merged into one «سایر» slice. */
    fun slices(entries: List<Entry>, max: Int = 6): List<Slice> {
        val total = entries.sumOf { it.amountRial }
        if (total == 0L) return emptyList()
        val grouped = entries.groupBy { it.categoryId }.map { (id, list) -> id to list.sumOf { it.amountRial } }.sortedByDescending { it.second }
        val head = if (grouped.size > max) grouped.take(max - 1) else grouped
        val rest = if (grouped.size > max) grouped.drop(max - 1).sumOf { it.second } else 0L
        return head.map { (id, sum) -> Slice(id, sum, sum * 100.0 / total) } +
            if (rest > 0) listOf(Slice(null, rest, rest * 100.0 / total, isOther = true)) else emptyList()
    }

    private fun inRange(e: Entry, from: JalaliDate, to: JalaliDate): Boolean {
        val day = JalaliDate.fromEpochMillis(e.occurredAtMillis).toEpochDay()
        return day in from.toEpochDay()..to.toEpochDay()
    }

    /** Standard report periods. */
    enum class Preset(val label: String) { THIS_MONTH("این ماه"), LAST_MONTH("ماه قبل"), LAST_3_MONTHS("۳ ماه اخیر"), THIS_YEAR("امسال") }

    /** (from, to, previous-from, previous-to) — all inclusive Jalali days. */
    fun range(preset: Preset, today: JalaliDate = JalaliDate.today()): List<JalaliDate> {
        val first = JalaliDate(today.year, today.month, 1)
        fun lastOf(d: JalaliDate) = d.plusMonths(1).plusDays(-1)
        return when (preset) {
            Preset.THIS_MONTH -> listOf(first, lastOf(first), first.plusMonths(-1), first.plusDays(-1))
            Preset.LAST_MONTH -> first.plusMonths(-1).let { listOf(it, first.plusDays(-1), it.plusMonths(-1), it.plusDays(-1)) }
            Preset.LAST_3_MONTHS -> first.plusMonths(-2).let { listOf(it, lastOf(first), it.plusMonths(-3), it.plusDays(-1)) }
            Preset.THIS_YEAR -> JalaliDate(today.year, 1, 1).let { listOf(it, JalaliDate(today.year, 12, JalaliDate.monthLength(today.year, 12)), JalaliDate(today.year - 1, 1, 1), it.plusDays(-1)) }
        }
    }
}
