package ir.hesabyar.domain.sms

import kotlin.math.abs

/**
 * Detects money moved between two accounts of the *same user*.
 *
 * Rule: a DEBIT on user account A and a CREDIT on user account B (A ≠ B) of the same amount,
 * within [windowMillis] (default 2 minutes) of each other, in either order, are one internal
 * transfer — not an expense plus an income. Without this, moving 10M from Mellat to Blu would
 * inflate both "expenses" and "income" by 10M.
 *
 * Card-to-card fees are charged as a separate debit (or folded into the balance), so the
 * default fee tolerance is 0; it is a parameter for banks that report "amount + fee" in one line.
 */
class SelfTransferDetector(
    private val windowMillis: Long = 2 * 60_000L,
    private val feeToleranceRial: Long = 0L,
) {

    data class Candidate(
        val id: Long,
        /** Null when the SMS could not be matched to one of the user's accounts. */
        val accountId: Long?,
        val direction: TxDirection,
        val amountRial: Long,
        val occurredAtMillis: Long,
        /** Already paired or confirmed as a normal transaction → not eligible. */
        val alreadyResolved: Boolean = false,
    )

    /** Returns the best counterpart for [incoming] among [recent], or null. */
    fun findCounterpart(incoming: Candidate, recent: List<Candidate>): Candidate? {
        val myAccount = incoming.accountId ?: return null
        return recent.asSequence()
            .filter { it.id != incoming.id && !it.alreadyResolved }
            .filter { it.accountId != null && it.accountId != myAccount }
            .filter { it.direction != incoming.direction }
            .filter { abs(it.occurredAtMillis - incoming.occurredAtMillis) <= windowMillis }
            .filter { amountsMatch(incoming, it) }
            .minByOrNull { abs(it.occurredAtMillis - incoming.occurredAtMillis) }
    }

    private fun amountsMatch(a: Candidate, b: Candidate): Boolean {
        val debit = if (a.direction == TxDirection.DEBIT) a.amountRial else b.amountRial
        val credit = if (a.direction == TxDirection.CREDIT) a.amountRial else b.amountRial
        val diff = debit - credit
        return diff in 0..feeToleranceRial
    }
}
