package ir.hesabyar.app.data.repository

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.ledger.TransactionType
import ir.hesabyar.domain.money.Money

enum class FilterKind(val label: String, val types: List<TransactionType>) {
    EXPENSE("هزینه", listOf(TransactionType.EXPENSE)),
    INCOME("درآمد", listOf(TransactionType.INCOME)),
    TRANSFER("انتقال", listOf(TransactionType.TRANSFER_OUT)),
    ADJUSTMENT("اصلاح موجودی", listOf(TransactionType.ADJUSTMENT_UP, TransactionType.ADJUSTMENT_DOWN)),
}

/** Every field optional. Dates are inclusive Jalali days; amounts in Toman as the user types them. */
data class TransactionFilter(
    val query: String = "",
    val from: JalaliDate? = null,
    val to: JalaliDate? = null,
    val minToman: Long? = null,
    val maxToman: Long? = null,
    val kinds: Set<FilterKind> = emptySet(),
    val categoryIds: Set<Long> = emptySet(),
    val accountIds: Set<Long> = emptySet(),
) {
    /** Number of active filters besides the text query — shown as a badge on the filter button. */
    val activeCount: Int
        get() = listOf(from != null || to != null, minToman != null || maxToman != null, kinds.isNotEmpty(), categoryIds.isNotEmpty(), accountIds.isNotEmpty()).count { it }

    val fromMillis: Long get() = from?.let { JalaliDate.toEpochMillis(it) } ?: Long.MIN_VALUE
    val toMillisExclusive: Long get() = to?.let { JalaliDate.toEpochMillis(it.plusDays(1)) } ?: Long.MAX_VALUE
    val minRial: Long get() = minToman?.let { Money.tomanToRial(it) } ?: 0L
    val maxRial: Long get() = maxToman?.let { Money.tomanToRial(it) } ?: Long.MAX_VALUE

    companion object {
        fun thisMonth(today: JalaliDate = JalaliDate.today()): TransactionFilter {
            val first = JalaliDate(today.year, today.month, 1)
            return TransactionFilter(from = first, to = first.plusMonths(1).plusDays(-1))
        }
        fun lastMonth(today: JalaliDate = JalaliDate.today()): TransactionFilter {
            val first = JalaliDate(today.year, today.month, 1).plusMonths(-1)
            return TransactionFilter(from = first, to = first.plusMonths(1).plusDays(-1))
        }
        fun lastDays(days: Int, today: JalaliDate = JalaliDate.today()) =
            TransactionFilter(from = today.plusDays(-(days - 1).toLong()), to = today)
    }
}
