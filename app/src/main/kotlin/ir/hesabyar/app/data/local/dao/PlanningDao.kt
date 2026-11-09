package ir.hesabyar.app.data.local.dao

import androidx.room.ColumnInfo
import androidx.room.Dao
import androidx.room.Embedded
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.ChequeStatus
import ir.hesabyar.app.data.local.entity.DebtEntity
import ir.hesabyar.app.data.local.entity.InstallmentEntity
import ir.hesabyar.app.data.local.entity.InstallmentStatus
import ir.hesabyar.app.data.local.entity.LoanEntity
import ir.hesabyar.app.data.local.entity.LoanStatus
import ir.hesabyar.app.data.local.entity.PersonEntity
import ir.hesabyar.app.data.local.entity.SavingsDepositEntity
import ir.hesabyar.app.data.local.entity.SavingsGoalEntity
import kotlinx.coroutines.flow.Flow

data class LoanSummary(
    @Embedded val loan: LoanEntity,
    @ColumnInfo(name = "paid_count") val paidCount: Int,
    @ColumnInfo(name = "next_due_day") val nextDueEpochDay: Long?,
    @ColumnInfo(name = "next_installment_id") val nextInstallmentId: Long?,
)

data class InstallmentRow(
    @Embedded val installment: InstallmentEntity,
    @ColumnInfo(name = "loan_title") val loanTitle: String,
    @ColumnInfo(name = "loan_total") val totalInstallments: Int,
    @ColumnInfo(name = "loan_ledger") val ledgerId: Long,
)

data class DebtRow(
    @Embedded val debt: DebtEntity,
    @ColumnInfo(name = "person_name") val personName: String,
)

@Dao
interface PlanningDao {

    // ============================================================ cheques
    @Query("SELECT * FROM cheques WHERE ledgerId = :ledgerId ORDER BY (status = 'PENDING') DESC, dueEpochDay")
    fun observeCheques(ledgerId: Long): Flow<List<ChequeEntity>>

    @Query("SELECT * FROM cheques WHERE ledgerId = :ledgerId AND dueEpochDay BETWEEN :fromDay AND :toDay")
    fun observeChequesBetween(ledgerId: Long, fromDay: Long, toDay: Long): Flow<List<ChequeEntity>>

    @Query("SELECT * FROM cheques WHERE status = 'PENDING' AND remindersEnabled = 1 AND dueEpochDay BETWEEN :fromDay AND :toDay")
    suspend fun chequesDueBetween(fromDay: Long, toDay: Long): List<ChequeEntity>

    @Query("SELECT * FROM cheques WHERE id = :id")
    suspend fun getCheque(id: Long): ChequeEntity?

    @Query("SELECT COUNT(*) FROM cheques WHERE sayadId = :sayadId AND id != :exceptId")
    suspend fun countSayad(sayadId: String, exceptId: Long): Int

    @Insert suspend fun insertCheque(cheque: ChequeEntity): Long
    @Update suspend fun updateCheque(cheque: ChequeEntity)

    @Query("UPDATE cheques SET status = :status, transactionId = :txId WHERE id = :id")
    suspend fun setChequeStatus(id: Long, status: ChequeStatus, txId: Long?)

    @Query("DELETE FROM cheques WHERE id = :id")
    suspend fun deleteCheque(id: Long)

    // ============================================================ loans & installments
    @Query(
        """
        SELECT l.*,
          (SELECT COUNT(*) FROM installments i WHERE i.loanId = l.id AND i.status = 'PAID') AS paid_count,
          (SELECT MIN(i.dueEpochDay) FROM installments i WHERE i.loanId = l.id AND i.status = 'DUE') AS next_due_day,
          (SELECT i.id FROM installments i WHERE i.loanId = l.id AND i.status = 'DUE' ORDER BY i.number LIMIT 1) AS next_installment_id
        FROM loans l WHERE l.ledgerId = :ledgerId
        ORDER BY (l.status = 'ACTIVE') DESC, next_due_day
        """,
    )
    fun observeLoanSummaries(ledgerId: Long): Flow<List<LoanSummary>>

    @Query(
        """
        SELECT i.*, l.title AS loan_title, l.totalInstallments AS loan_total, l.ledgerId AS loan_ledger
        FROM installments i JOIN loans l ON l.id = i.loanId
        WHERE l.ledgerId = :ledgerId AND i.dueEpochDay BETWEEN :fromDay AND :toDay
        ORDER BY i.dueEpochDay
        """,
    )
    fun observeInstallmentsBetween(ledgerId: Long, fromDay: Long, toDay: Long): Flow<List<InstallmentRow>>

    @Query(
        """
        SELECT i.*, l.title AS loan_title, l.totalInstallments AS loan_total, l.ledgerId AS loan_ledger
        FROM installments i JOIN loans l ON l.id = i.loanId
        WHERE i.status = 'DUE' AND l.status = 'ACTIVE' AND l.remindersEnabled = 1 AND i.dueEpochDay BETWEEN :fromDay AND :toDay
        """,
    )
    suspend fun installmentsDueBetween(fromDay: Long, toDay: Long): List<InstallmentRow>

    @Query("SELECT * FROM installments WHERE loanId = :loanId ORDER BY number")
    fun observeInstallments(loanId: Long): Flow<List<InstallmentEntity>>

    @Query("SELECT * FROM installments WHERE id = :id")
    suspend fun getInstallment(id: Long): InstallmentEntity?

    @Query("SELECT * FROM loans WHERE id = :id")
    suspend fun getLoan(id: Long): LoanEntity?

    @Query("SELECT COUNT(*) FROM installments WHERE loanId = :loanId AND status != 'PAID'")
    suspend fun countUnpaid(loanId: Long): Int

    @Insert suspend fun insertLoan(loan: LoanEntity): Long
    @Insert suspend fun insertInstallments(items: List<InstallmentEntity>)

    @Query("UPDATE installments SET status = :status, paidAt = :paidAt, transactionId = :txId WHERE id = :id")
    suspend fun setInstallmentStatus(id: Long, status: InstallmentStatus, paidAt: Long?, txId: Long?)

    @Query("UPDATE loans SET status = :status WHERE id = :id")
    suspend fun setLoanStatus(id: Long, status: LoanStatus)

    @Query("DELETE FROM loans WHERE id = :id")
    suspend fun deleteLoan(id: Long)

    // ============================================================ people & debts
    @Query("SELECT * FROM people WHERE ledgerId = :ledgerId ORDER BY name")
    fun observePeople(ledgerId: Long): Flow<List<PersonEntity>>

    @Query("SELECT * FROM people WHERE ledgerId = :ledgerId ORDER BY name")
    suspend fun listPeople(ledgerId: Long): List<PersonEntity>

    @Query("SELECT * FROM people WHERE ledgerId = :ledgerId AND name = :name LIMIT 1")
    suspend fun findPerson(ledgerId: Long, name: String): PersonEntity?

    @Insert suspend fun insertPerson(person: PersonEntity): Long

    @Query(
        """
        SELECT d.*, p.name AS person_name FROM debts d JOIN people p ON p.id = d.personId
        WHERE d.ledgerId = :ledgerId ORDER BY (d.settledRial < d.amountRial) DESC, d.createdAt DESC
        """,
    )
    fun observeDebts(ledgerId: Long): Flow<List<DebtRow>>

    @Query(
        """
        SELECT d.*, p.name AS person_name FROM debts d JOIN people p ON p.id = d.personId
        WHERE d.settledRial < d.amountRial AND d.dueEpochDay BETWEEN :fromDay AND :toDay
        """,
    )
    suspend fun debtsDueBetween(fromDay: Long, toDay: Long): List<DebtRow>

    @Query("SELECT * FROM debts WHERE id = :id")
    suspend fun getDebt(id: Long): DebtEntity?

    @Insert suspend fun insertDebt(debt: DebtEntity): Long
    @Insert suspend fun insertDebts(debts: List<DebtEntity>)

    @Query("UPDATE debts SET settledRial = :settled WHERE id = :id")
    suspend fun setDebtSettled(id: Long, settled: Long)

    @Query("DELETE FROM debts WHERE id = :id")
    suspend fun deleteDebt(id: Long)

    // ============================================================ savings goals (step 3)
    @Insert suspend fun insertGoal(goal: SavingsGoalEntity): Long
    @Insert suspend fun insertDeposit(deposit: SavingsDepositEntity): Long

    @Query("SELECT * FROM savings_goals WHERE ledgerId = :ledgerId AND isActive = 1")
    fun observeGoals(ledgerId: Long): Flow<List<SavingsGoalEntity>>
}
