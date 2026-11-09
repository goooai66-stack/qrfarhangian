package ir.hesabyar.domain.ledger

/**
 * Balance arithmetic, kept pure so it can be unit-tested and reused by the Room layer.
 *
 * The classic bug in competing apps: a transaction back-dated to last week is appended at the
 * end, so every "balance after" in between is wrong. Here a balance is *always* derived from
 * the chronological order (occurredAt, then id as a stable tie-breaker), never from insert order.
 */
enum class TransactionType(val sign: Int, val countsInReports: Boolean) {
    EXPENSE(-1, true),
    INCOME(+1, true),
    /** Leg of an internal transfer leaving this account. Excluded from income/expense reports. */
    TRANSFER_OUT(-1, false),
    TRANSFER_IN(+1, false),
    /** Manual correction to match the real bank balance. */
    ADJUSTMENT_UP(+1, false),
    ADJUSTMENT_DOWN(-1, false);

    fun signedAmount(amountRial: Long): Long = sign * amountRial
}

data class LedgerEntry(
    val id: Long,
    val occurredAtMillis: Long,
    val type: TransactionType,
    val amountRial: Long,
)

object LedgerMath {

    val chronological: Comparator<LedgerEntry> =
        compareBy<LedgerEntry> { it.occurredAtMillis }.thenBy { it.id }

    /**
     * Recomputes running balances.
     *
     * @param startingBalance balance just *before* the first entry in [entries]
     *   (account opening balance, or the balanceAfter of the last untouched entry).
     * @return id → balanceAfter, in chronological order.
     */
    fun runningBalances(startingBalance: Long, entries: List<LedgerEntry>): LinkedHashMap<Long, Long> {
        val result = LinkedHashMap<Long, Long>(entries.size * 2)
        var balance = startingBalance
        for (e in entries.sortedWith(chronological)) {
            balance = Math.addExact(balance, e.type.signedAmount(e.amountRial))
            result[e.id] = balance
        }
        return result
    }

    fun finalBalance(opening: Long, entries: List<LedgerEntry>): Long =
        entries.fold(opening) { acc, e -> Math.addExact(acc, e.type.signedAmount(e.amountRial)) }

    data class PeriodTotals(val incomeRial: Long, val expenseRial: Long) {
        val netRial: Long get() = incomeRial - expenseRial
    }

    fun totals(entries: List<LedgerEntry>): PeriodTotals {
        var income = 0L
        var expense = 0L
        for (e in entries) {
            when (e.type) {
                TransactionType.INCOME -> income += e.amountRial
                TransactionType.EXPENSE -> expense += e.amountRial
                else -> Unit
            }
        }
        return PeriodTotals(income, expense)
    }
}
