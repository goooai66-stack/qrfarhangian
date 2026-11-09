package ir.hesabyar.app.usecase

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.entity.SmsStatus
import ir.hesabyar.app.data.local.entity.TxSource
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.data.repository.TransactionDraft
import ir.hesabyar.app.data.repository.TransactionRepository

/** One tap on a category chip in the SMS card → a real transaction. */
class ConfirmBankSmsUseCase(
    private val db: AppDatabase,
    private val transactions: TransactionRepository,
) {
    private val smsDao = db.bankSmsDao()
    private val accountDao = db.accountDao()

    suspend fun confirm(smsId: Long, categoryId: Long?): Long? = db.withTransaction {
        val sms = smsDao.getById(smsId) ?: return@withTransaction null
        if (sms.status == SmsStatus.CONFIRMED || sms.status == SmsStatus.DISMISSED) return@withTransaction sms.transactionId
        val accountId = sms.matchedAccountId ?: return@withTransaction null
        val account = accountDao.getById(accountId) ?: return@withTransaction null

        val pair = sms.selfTransferPairId?.let { smsDao.getById(it) }
        if (sms.status == SmsStatus.SELF_TRANSFER && pair?.matchedAccountId != null) {
            val debit = if (sms.isDebit) sms else pair
            val credit = if (sms.isDebit) pair else sms
            val fromAccount = accountDao.getById(debit.matchedAccountId!!) ?: return@withTransaction null
            val txId = transactions.save(
                TransactionDraft(
                    ledgerId = fromAccount.ledgerId, kind = DraftKind.TRANSFER, amountRial = credit.amountRial,
                    accountId = fromAccount.id, toAccountId = credit.matchedAccountId, occurredAt = debit.occurredAt,
                    note = "انتقال بین حساب‌های من", source = TxSource.SMS, smsId = debit.id,
                ),
            )
            smsDao.setStatus(debit.id, SmsStatus.CONFIRMED, txId)
            smsDao.setStatus(credit.id, SmsStatus.CONFIRMED, txId)
            return@withTransaction txId
        }

        val txId = transactions.save(
            TransactionDraft(
                ledgerId = account.ledgerId, kind = if (sms.isDebit) DraftKind.EXPENSE else DraftKind.INCOME,
                amountRial = sms.amountRial, accountId = accountId, categoryId = categoryId,
                occurredAt = sms.occurredAt, source = TxSource.SMS, smsId = sms.id,
            ),
        )
        accountDao.learnSender(accountId, sms.sender)
        smsDao.setStatus(sms.id, SmsStatus.CONFIRMED, txId)
        txId
    }

    /** «این انتقال نیست»: unpair and treat both SMS as ordinary expense/income. */
    suspend fun splitSelfTransfer(smsId: Long) = db.withTransaction {
        val sms = smsDao.getById(smsId) ?: return@withTransaction
        listOfNotNull(sms.id, sms.selfTransferPairId).forEach { smsDao.setStatus(it, SmsStatus.PENDING, null) }
    }

    suspend fun dismiss(smsId: Long) = smsDao.setStatus(smsId, SmsStatus.DISMISSED, null)
}
