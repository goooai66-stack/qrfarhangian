package ir.hesabyar.app.data.repository

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.data.local.entity.TransactionEntity
import ir.hesabyar.app.data.local.entity.TxSource
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.ledger.LedgerEntry
import ir.hesabyar.domain.ledger.LedgerMath
import ir.hesabyar.domain.ledger.TransactionType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import java.util.UUID

enum class DraftKind { EXPENSE, INCOME, TRANSFER }

/** Everything the form (or an SMS / voice / installment) needs to create a movement. */
data class TransactionDraft(
    val editingId: Long? = null,
    val ledgerId: Long,
    val kind: DraftKind,
    val amountRial: Long,
    val accountId: Long,
    val toAccountId: Long? = null,
    val categoryId: Long? = null,
    val occurredAt: Long,
    val note: String = "",
    val source: TxSource = TxSource.MANUAL,
    val smsId: Long? = null,
)

class TransactionRepository(private val db: AppDatabase) {

    private val txDao = db.transactionDao()
    private val accountDao = db.accountDao()

    fun observeRows(ledgerId: Long, query: String = "", limit: Int = 500): Flow<List<TransactionRow>> =
        txDao.observeRows(ledgerId, query.trim(), limit)

    fun observeFiltered(ledgerId: Long, f: TransactionFilter, limit: Int = 2_000): Flow<List<TransactionRow>> =
        txDao.observeFiltered(
            ledgerId = ledgerId, query = f.query.trim(), fromMillis = f.fromMillis, toMillis = f.toMillisExclusive,
            minRial = f.minRial, maxRial = f.maxRial,
            allTypes = f.kinds.isEmpty(), types = f.kinds.flatMap { k -> k.types.map { it.name } },
            allCategories = f.categoryIds.isEmpty(), categoryIds = f.categoryIds.toList(),
            allAccounts = f.accountIds.isEmpty(), accountIds = f.accountIds.toList(),
            limit = limit,
        )

    /** Income/expense of the current Jalali month (transfers excluded by construction). */
    fun observeMonthTotals(ledgerId: Long, nowMillis: Long = System.currentTimeMillis()): Flow<LedgerMath.PeriodTotals> {
        val today = JalaliDate.fromEpochMillis(nowMillis)
        val first = JalaliDate(today.year, today.month, 1)
        val from = JalaliDate.toEpochMillis(first)
        val to = JalaliDate.toEpochMillis(first.plusMonths(1))
        return combine(
            txDao.observeSum(ledgerId, TransactionType.INCOME, from, to),
            txDao.observeSum(ledgerId, TransactionType.EXPENSE, from, to),
        ) { income, expense -> LedgerMath.PeriodTotals(income, expense) }
    }

    /**
     * Creates or edits a movement and re-derives every affected running balance from the
     * earliest touched instant — so a back-dated or re-dated entry fixes all later balances.
     * @return id of the (first) row written.
     */
    suspend fun save(d: TransactionDraft): Long = db.withTransaction {
        require(d.amountRial > 0) { "amount must be positive" }
        if (d.kind == DraftKind.TRANSFER) require(d.toAccountId != null && d.toAccountId != d.accountId)

        val touched = HashMap<Long, Long>() // accountId → earliest affected millis
        fun touch(accountId: Long, at: Long) { touched[accountId] = minOf(touched[accountId] ?: Long.MAX_VALUE, at) }
        val now = System.currentTimeMillis()

        val old = d.editingId?.let { txDao.getById(it) }
        val resultId: Long

        if (old != null && old.transferGroupId == null && d.kind != DraftKind.TRANSFER) {
            // Simple edit in place keeps the id (and the bank_sms → transaction link) stable.
            touch(old.accountId, old.occurredAt)
            txDao.update(
                old.copy(
                    ledgerId = d.ledgerId, accountId = d.accountId, type = d.kind.toType(),
                    amountRial = d.amountRial, categoryId = d.categoryId, occurredAt = d.occurredAt,
                    note = d.note.trim(), updatedAt = now,
                ),
            )
            resultId = old.id
        } else {
            if (old != null) {
                val legs = old.transferGroupId?.let { txDao.getTransferLegs(it) } ?: listOf(old)
                legs.forEach { touch(it.accountId, it.occurredAt); txDao.deleteById(it.id) }
            }
            resultId = when (d.kind) {
                DraftKind.EXPENSE, DraftKind.INCOME -> txDao.insert(d.toEntity(d.accountId, d.ledgerId, d.kind.toType(), null, now))
                DraftKind.TRANSFER -> {
                    val group = UUID.randomUUID().toString()
                    val toAccount = requireNotNull(accountDao.getById(d.toAccountId!!))
                    val outId = txDao.insert(d.toEntity(d.accountId, d.ledgerId, TransactionType.TRANSFER_OUT, group, now))
                    txDao.insert(d.toEntity(toAccount.id, toAccount.ledgerId, TransactionType.TRANSFER_IN, group, now))
                    outId
                }
            }
        }
        touch(d.accountId, d.occurredAt)
        d.toAccountId?.let { touch(it, d.occurredAt) }
        touched.forEach { (accountId, from) -> recomputeFrom(accountId, from) }
        resultId
    }

    suspend fun delete(id: Long) = db.withTransaction {
        val tx = txDao.getById(id) ?: return@withTransaction
        val legs = tx.transferGroupId?.let { txDao.getTransferLegs(it) } ?: listOf(tx)
        legs.forEach { txDao.deleteById(it.id) }
        legs.forEach { recomputeFrom(it.accountId, it.occurredAt) }
    }

    /** Must run inside a transaction. O(rows after [fromMillis]) — not O(all rows). */
    suspend fun recomputeFrom(accountId: Long, fromMillis: Long) {
        val account = accountDao.getById(accountId) ?: return
        val start = txDao.balanceBefore(accountId, fromMillis) ?: account.openingBalanceRial
        val entries = txDao.entriesFrom(accountId, fromMillis)
        val balances = LedgerMath.runningBalances(start, entries.map { LedgerEntry(it.id, it.occurredAt, it.type, it.amountRial) })
        balances.forEach { (id, balance) -> txDao.setBalanceAfter(id, balance) }
        accountDao.setCurrentBalance(accountId, balances.values.lastOrNull() ?: start)
    }

    private fun DraftKind.toType() = if (this == DraftKind.INCOME) TransactionType.INCOME else TransactionType.EXPENSE

    private fun TransactionDraft.toEntity(account: Long, ledger: Long, type: TransactionType, group: String?, now: Long) =
        TransactionEntity(
            ledgerId = ledger, accountId = account, type = type, amountRial = amountRial,
            categoryId = if (group == null) categoryId else null, occurredAt = occurredAt, note = note.trim(),
            source = source, smsId = smsId, transferGroupId = group, createdAt = now, updatedAt = now,
        )
}
