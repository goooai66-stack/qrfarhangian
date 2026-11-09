package ir.hesabyar.app.usecase

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.AppDatabase

/**
 * «شروع سال مالی جدید» for one ledger: deletes every transaction, keeps accounts, categories,
 * cheques, loans, debts and savings goals. Balances either restart from zero (as specified) or
 * carry over as each account's new opening balance. Links from cheques/installments/deposits/SMS
 * to the deleted rows are cleared so nothing points at a missing transaction.
 */
class FiscalYearReset(private val db: AppDatabase) {

    suspend operator fun invoke(ledgerId: Long, carryOverBalances: Boolean) = db.withTransaction {
        val accounts = db.accountDao().listAllInLedger(ledgerId)
        db.transactionDao().deleteAllInLedger(ledgerId)
        val planning = db.planningDao()
        planning.clearChequeTxRefs(ledgerId)
        planning.clearInstallmentTxRefs(ledgerId)
        planning.clearDepositTxRefs(ledgerId)
        planning.clearSmsTxRefs(ledgerId)
        accounts.forEach { a ->
            val opening = if (carryOverBalances) a.currentBalanceRial else 0L
            db.accountDao().update(a.copy(openingBalanceRial = opening, currentBalanceRial = opening))
        }
    }
}
