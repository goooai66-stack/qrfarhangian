package ir.hesabyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.InstallmentEntity
import ir.hesabyar.app.data.local.entity.LoanEntity
import ir.hesabyar.app.data.local.entity.SavingsDepositEntity
import ir.hesabyar.app.data.local.entity.SavingsGoalEntity
import kotlinx.coroutines.flow.Flow

/** Step-1 surface for due dates & goals; screens and use cases arrive in step 2–3. */
@Dao
interface PlanningDao {
    @Query("SELECT * FROM cheques WHERE ledgerId = :ledgerId AND status = 'PENDING' ORDER BY dueEpochDay")
    fun observePendingCheques(ledgerId: Long): Flow<List<ChequeEntity>>

    @Query("SELECT * FROM cheques WHERE status = 'PENDING' AND remindersEnabled = 1 AND dueEpochDay BETWEEN :fromDay AND :toDay")
    suspend fun chequesDueBetween(fromDay: Long, toDay: Long): List<ChequeEntity>

    @Insert suspend fun insertCheque(cheque: ChequeEntity): Long
    @Update suspend fun updateCheque(cheque: ChequeEntity)

    @Insert suspend fun insertLoan(loan: LoanEntity): Long
    @Insert suspend fun insertInstallments(items: List<InstallmentEntity>)

    @Query("SELECT * FROM installments WHERE status = 'DUE' AND dueEpochDay BETWEEN :fromDay AND :toDay ORDER BY dueEpochDay")
    suspend fun installmentsDueBetween(fromDay: Long, toDay: Long): List<InstallmentEntity>

    @Query("SELECT COUNT(*) FROM installments WHERE loanId = :loanId AND status = 'PAID'")
    fun observePaidCount(loanId: Long): Flow<Int>

    @Insert suspend fun insertGoal(goal: SavingsGoalEntity): Long
    @Insert suspend fun insertDeposit(deposit: SavingsDepositEntity): Long

    @Query("SELECT * FROM savings_goals WHERE ledgerId = :ledgerId AND isActive = 1")
    fun observeGoals(ledgerId: Long): Flow<List<SavingsGoalEntity>>
}
