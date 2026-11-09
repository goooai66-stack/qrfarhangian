package ir.hesabyar.app.usecase

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.AccountKind
import ir.hesabyar.app.data.local.entity.SavingsDepositEntity
import ir.hesabyar.app.data.local.entity.SavingsGoalEntity
import ir.hesabyar.app.data.local.entity.SavingsUnit
import ir.hesabyar.app.data.local.entity.TxSource
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.data.repository.TransactionDraft
import ir.hesabyar.app.data.repository.TransactionRepository
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.savings.InflationShield
import java.math.BigDecimal

/**
 * Inflation-proof goals. A deposit can move real money: it is booked as a *transfer* from the
 * chosen account into the goal's own wallet account — buying gold is converting cash to an asset,
 * not an expense, so it must not inflate the expense report.
 */
class SavingsUseCases(private val db: AppDatabase, private val transactions: TransactionRepository) {

    private val dao = db.planningDao()

    suspend fun createGoal(ledgerId: Long, title: String, unit: SavingsUnit, targetUnits: BigDecimal, deadline: JalaliDate?): Long {
        if (title.isBlank()) throw DueValidationException("عنوان هدف را وارد کنید")
        if (targetUnits.signum() <= 0) throw DueValidationException("مقدار هدف را وارد کنید")
        return dao.insertGoal(
            SavingsGoalEntity(
                ledgerId = ledgerId, title = title.trim(), unit = unit,
                targetMilliUnits = targetUnits.movePointRight(3).toLong(), deadlineEpochDay = deadline?.toEpochDay(),
            ),
        )
    }

    suspend fun deposit(goalId: Long, amountRial: Long, unitPriceRial: Long, fromAccountId: Long?, atMillis: Long = System.currentTimeMillis()): Long {
        if (amountRial <= 0) throw DueValidationException("مبلغ را وارد کنید")
        if (unitPriceRial <= 0) throw DueValidationException("قیمت واحد را وارد کنید (نرخ روز در دسترس نیست)")
        return db.withTransaction {
            val goal = dao.getGoal(goalId) ?: throw DueValidationException("هدف پیدا نشد")
            val txId = fromAccountId?.let { from ->
                val wallet = goal.accountId ?: db.accountDao().insert(
                    AccountEntity(ledgerId = goal.ledgerId, name = "سپر ضدتورم: ${goal.title}", kind = AccountKind.WALLET, colorArgb = 0xFFC5A059),
                ).also { dao.setGoalAccount(goal.id, it) }
                transactions.save(
                    TransactionDraft(
                        ledgerId = goal.ledgerId, kind = DraftKind.TRANSFER, amountRial = amountRial, accountId = from,
                        toAccountId = wallet, occurredAt = atMillis, source = TxSource.SAVINGS_GOAL, note = "پس‌انداز «${goal.title}»",
                    ),
                )
            }
            dao.insertDeposit(
                SavingsDepositEntity(
                    goalId = goalId, amountRial = amountRial, unitPriceRialAtDeposit = unitPriceRial,
                    milliUnitsAcquired = InflationShield.milliUnitsFor(amountRial, unitPriceRial), depositedAt = atMillis, transactionId = txId,
                ),
            )
        }
    }

    suspend fun deleteDeposit(depositId: Long) = db.withTransaction {
        val d = dao.getDeposit(depositId) ?: return@withTransaction
        d.transactionId?.let { transactions.delete(it) }
        dao.deleteDeposit(depositId)
    }

    suspend fun archiveGoal(goalId: Long) = dao.archiveGoal(goalId)
}
