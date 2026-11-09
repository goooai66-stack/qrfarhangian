package ir.hesabyar.app.data.local.dao

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Embedded
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import ir.hesabyar.app.data.local.entity.TransactionEntity
import ir.hesabyar.domain.ledger.TransactionType
import kotlinx.coroutines.flow.Flow

/** Row for lists: transaction + display fields, one query, no N+1. */
data class TransactionRow(
    @Embedded val tx: TransactionEntity,
    @ColumnInfo(name = "category_name") val categoryName: String?,
    @ColumnInfo(name = "category_icon") val categoryIcon: String?,
    @ColumnInfo(name = "category_color") val categoryColor: Long?,
    @ColumnInfo(name = "account_name") val accountName: String,
    @ColumnInfo(name = "counter_account_name") val counterAccountName: String?,
)

data class LedgerEntryRow(
    val id: Long,
    val occurredAt: Long,
    val type: TransactionType,
    val amountRial: Long,
)

@Dao
interface TransactionDao {

    // The TRANSFER_IN leg is hidden in lists: a transfer is shown once, as «از X به Y».
    @Query(
        """
        SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.colorArgb AS category_color,
               a.name AS account_name,
               (SELECT a2.name FROM transactions t2 JOIN accounts a2 ON a2.id = t2.accountId
                 WHERE t.transferGroupId IS NOT NULL AND t2.transferGroupId = t.transferGroupId AND t2.id != t.id
                 LIMIT 1) AS counter_account_name
        FROM transactions t
        JOIN accounts a ON a.id = t.accountId
        LEFT JOIN categories c ON c.id = t.categoryId
        WHERE t.ledgerId = :ledgerId AND t.type != 'TRANSFER_IN'
          AND (:query = '' OR t.note LIKE '%' || :query || '%' OR c.name LIKE '%' || :query || '%' OR a.name LIKE '%' || :query || '%')
        ORDER BY t.occurredAt DESC, t.id DESC
        LIMIT :limit
        """,
    )
    fun observeRows(ledgerId: Long, query: String, limit: Int): Flow<List<TransactionRow>>

    /**
     * Advanced search. Every filter is optional through a sentinel: empty text, full time /
     * amount range, or the `all…` flag for list filters (Room cannot bind an "optional IN").
     */
    @Query(
        """
        SELECT t.*, c.name AS category_name, c.icon AS category_icon, c.colorArgb AS category_color,
               a.name AS account_name,
               (SELECT a2.name FROM transactions t2 JOIN accounts a2 ON a2.id = t2.accountId
                 WHERE t.transferGroupId IS NOT NULL AND t2.transferGroupId = t.transferGroupId AND t2.id != t.id
                 LIMIT 1) AS counter_account_name
        FROM transactions t
        JOIN accounts a ON a.id = t.accountId
        LEFT JOIN categories c ON c.id = t.categoryId
        WHERE t.ledgerId = :ledgerId AND t.type != 'TRANSFER_IN'
          AND (:query = '' OR t.note LIKE '%' || :query || '%' OR c.name LIKE '%' || :query || '%' OR a.name LIKE '%' || :query || '%')
          AND t.occurredAt >= :fromMillis AND t.occurredAt < :toMillis
          AND t.amountRial >= :minRial AND t.amountRial <= :maxRial
          AND (:allTypes = 1 OR t.type IN (:types))
          AND (:allCategories = 1 OR t.categoryId IN (:categoryIds))
          AND (:allAccounts = 1 OR t.accountId IN (:accountIds))
        ORDER BY t.occurredAt DESC, t.id DESC
        LIMIT :limit
        """,
    )
    fun observeFiltered(
        ledgerId: Long, query: String, fromMillis: Long, toMillis: Long, minRial: Long, maxRial: Long,
        allTypes: Boolean, types: List<String>, allCategories: Boolean, categoryIds: List<Long>,
        allAccounts: Boolean, accountIds: List<Long>, limit: Int,
    ): Flow<List<TransactionRow>>

    @Query(
        """
        SELECT COALESCE(SUM(amountRial), 0) FROM transactions
        WHERE ledgerId = :ledgerId AND type = :type AND occurredAt >= :fromMillis AND occurredAt < :toMillis
        """,
    )
    fun observeSum(ledgerId: Long, type: TransactionType, fromMillis: Long, toMillis: Long): Flow<Long>

    // ---------------------------------------------------------------- balance recompute support

    /** Balance immediately before [fromMillis] (strictly earlier rows), or null if none. */
    @Query(
        """
        SELECT balanceAfterRial FROM transactions
        WHERE accountId = :accountId AND occurredAt < :fromMillis
        ORDER BY occurredAt DESC, id DESC LIMIT 1
        """,
    )
    suspend fun balanceBefore(accountId: Long, fromMillis: Long): Long?

    @Query(
        """
        SELECT id, occurredAt, type, amountRial FROM transactions
        WHERE accountId = :accountId AND occurredAt >= :fromMillis
        ORDER BY occurredAt, id
        """,
    )
    suspend fun entriesFrom(accountId: Long, fromMillis: Long): List<LedgerEntryRow>

    @Query("UPDATE transactions SET balanceAfterRial = :balance WHERE id = :id")
    suspend fun setBalanceAfter(id: Long, balance: Long)

    // ---------------------------------------------------------------- CRUD

    @Insert suspend fun insert(tx: TransactionEntity): Long
    @Update suspend fun update(tx: TransactionEntity)

    @Query("DELETE FROM transactions WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("SELECT * FROM transactions WHERE id = :id")
    suspend fun getById(id: Long): TransactionEntity?

    @Query("SELECT * FROM transactions WHERE transferGroupId = :groupId")
    suspend fun getTransferLegs(groupId: String): List<TransactionEntity>

    /** Fiscal-year reset: wipes movements, keeps accounts & categories. */
    @Query("DELETE FROM transactions WHERE ledgerId = :ledgerId")
    suspend fun deleteAllInLedger(ledgerId: Long)
}
