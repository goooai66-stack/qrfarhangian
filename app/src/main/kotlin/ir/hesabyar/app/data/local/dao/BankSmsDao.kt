package ir.hesabyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import ir.hesabyar.app.data.local.entity.BankSmsEntity
import ir.hesabyar.app.data.local.entity.SmsStatus
import kotlinx.coroutines.flow.Flow

@Dao
interface BankSmsDao {
    /** Returns -1 when the same SMS was already stored (unique bodyHash). */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(sms: BankSmsEntity): Long

    @Query("SELECT * FROM bank_sms WHERE status IN ('PENDING','SELF_TRANSFER') ORDER BY occurredAt DESC")
    fun observeInbox(): Flow<List<BankSmsEntity>>

    @Query("SELECT * FROM bank_sms WHERE id = :id")
    suspend fun getById(id: Long): BankSmsEntity?

    @Query("SELECT * FROM bank_sms WHERE occurredAt BETWEEN :from AND :to AND status = 'PENDING'")
    suspend fun pendingBetween(from: Long, to: Long): List<BankSmsEntity>

    @Query("UPDATE bank_sms SET status = :status, transactionId = :txId WHERE id = :id")
    suspend fun setStatus(id: Long, status: SmsStatus, txId: Long?)

    @Query("UPDATE bank_sms SET status = 'SELF_TRANSFER', selfTransferPairId = :pairId WHERE id = :id")
    suspend fun markSelfTransfer(id: Long, pairId: Long)

    @Query("UPDATE bank_sms SET matchedAccountId = :accountId WHERE id = :id")
    suspend fun setMatchedAccount(id: Long, accountId: Long)

    /** Privacy: raw bodies of handled SMS are purged after [olderThan]; parsed fields remain. */
    @Query("UPDATE bank_sms SET body = '' WHERE status IN ('CONFIRMED','DISMISSED') AND receivedAt < :olderThan")
    suspend fun purgeBodies(olderThan: Long)
}
