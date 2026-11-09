package ir.hesabyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.domain.sms.Bank
import kotlinx.coroutines.flow.Flow

@Dao
interface LedgerDao {
    @Query("SELECT * FROM ledgers ORDER BY sortOrder, id")
    fun observeAll(): Flow<List<LedgerEntity>>

    @Query("SELECT * FROM ledgers ORDER BY sortOrder, id")
    suspend fun listAll(): List<LedgerEntity>

    @Query("SELECT COUNT(*) FROM ledgers")
    suspend fun count(): Int

    @Insert suspend fun insert(ledger: LedgerEntity): Long
}

@Dao
interface AccountDao {
    @Query("SELECT * FROM accounts WHERE ledgerId = :ledgerId AND isArchived = 0 ORDER BY sortOrder, id")
    fun observeByLedger(ledgerId: Long): Flow<List<AccountEntity>>

    @Query("SELECT * FROM accounts WHERE id = :id")
    suspend fun getById(id: Long): AccountEntity?

    @Query("SELECT * FROM accounts WHERE ledgerId = :ledgerId AND isArchived = 0")
    suspend fun listByLedger(ledgerId: Long): List<AccountEntity>

    /** All user accounts across ledgers: an SMS belongs to whichever ledger owns the card. */
    @Query("SELECT * FROM accounts WHERE isArchived = 0")
    suspend fun listAll(): List<AccountEntity>

    @Query("SELECT * FROM accounts WHERE ledgerId = :ledgerId AND bank = :bank AND isArchived = 0")
    suspend fun findByBank(ledgerId: Long, bank: Bank): List<AccountEntity>

    @Insert suspend fun insert(account: AccountEntity): Long
    @Update suspend fun update(account: AccountEntity)

    @Query("UPDATE accounts SET currentBalanceRial = :balance WHERE id = :id")
    suspend fun setCurrentBalance(id: Long, balance: Long)

    @Query("UPDATE accounts SET smsSender = :sender WHERE id = :id AND smsSender IS NULL")
    suspend fun learnSender(id: Long, sender: String)
}

@Dao
interface CategoryDao {
    @Query("SELECT * FROM categories WHERE ledgerId = :ledgerId AND isArchived = 0 ORDER BY kind, sortOrder, id")
    fun observeByLedger(ledgerId: Long): Flow<List<CategoryEntity>>

    @Query("SELECT * FROM categories WHERE ledgerId = :ledgerId AND kind = :kind AND isArchived = 0 ORDER BY sortOrder, id")
    suspend fun listByKind(ledgerId: Long, kind: CategoryKind): List<CategoryEntity>

    @Insert suspend fun insertAll(categories: List<CategoryEntity>)
}
