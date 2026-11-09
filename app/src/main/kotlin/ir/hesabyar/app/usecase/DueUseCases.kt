package ir.hesabyar.app.usecase

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.local.entity.ChequeDirection
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.ChequeStatus
import ir.hesabyar.app.data.local.entity.DebtDirection
import ir.hesabyar.app.data.local.entity.DebtEntity
import ir.hesabyar.app.data.local.entity.InstallmentEntity
import ir.hesabyar.app.data.local.entity.InstallmentStatus
import ir.hesabyar.app.data.local.entity.LoanEntity
import ir.hesabyar.app.data.local.entity.LoanStatus
import ir.hesabyar.app.data.local.entity.PersonEntity
import ir.hesabyar.app.data.local.entity.TxSource
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.data.repository.TransactionDraft
import ir.hesabyar.app.data.repository.TransactionRepository
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.due.InstallmentSchedule
import ir.hesabyar.domain.due.SayadId
import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.split.SplitCalculator
import java.util.UUID

/** Thrown for user-fixable input problems; [message] is shown as-is (Persian). */
class DueValidationException(message: String) : IllegalArgumentException(message)

data class ChequeDraft(
    val id: Long? = null,
    val ledgerId: Long,
    val direction: ChequeDirection,
    val amountRial: Long,
    val dueDate: JalaliDate,
    val counterparty: String,
    val sayadId: String = "",
    val serial: String = "",
    val bank: Bank? = null,
    val accountId: Long? = null,
    val note: String = "",
    val reminders: Boolean = true,
)

data class LoanDraft(
    val ledgerId: Long,
    val title: String,
    val lender: String,
    val principalRial: Long,
    val installmentRial: Long,
    val count: Int,
    val firstDue: JalaliDate,
    /** For loans entered mid-way: the first N installments are marked paid without transactions. */
    val alreadyPaid: Int = 0,
    val accountId: Long? = null,
    val autoDeduct: Boolean = true,
    val reminders: Boolean = true,
)

data class SplitDraft(
    val ledgerId: Long,
    val title: String,
    val totalRial: Long,
    /** name → weight; must contain [ME]. */
    val participants: List<Pair<String, Int>>,
    val payer: String,
    /** When I paid: account to debit for the whole bill (null = do not record a transaction). */
    val accountId: Long? = null,
    val categoryId: Long? = null,
) {
    companion object { const val ME = "من" }
}

/**
 * Cheques, loans and debts. Every money-moving action goes through [TransactionRepository] so
 * balances stay chronologically correct; [onDuesChanged] lets reminders re-evaluate at once.
 */
class DueUseCases(
    private val db: AppDatabase,
    private val transactions: TransactionRepository,
    private val onDuesChanged: suspend () -> Unit,
) {
    private val dao = db.planningDao()

    // ============================================================ cheques

    suspend fun saveCheque(d: ChequeDraft): Long {
        if (d.amountRial <= 0) throw DueValidationException("مبلغ چک را وارد کنید")
        if (d.counterparty.isBlank()) throw DueValidationException(if (d.direction == ChequeDirection.RECEIVED) "نام صادرکننده را وارد کنید" else "نام گیرنده را وارد کنید")
        val sayad = d.sayadId.takeIf { it.isNotBlank() }?.let { SayadId.normalize(it) ?: throw DueValidationException("شناسه صیادی باید ۱۶ رقم باشد") }
        val id = db.withTransaction {
            if (sayad != null && dao.countSayad(sayad, d.id ?: -1) > 0) throw DueValidationException("چکی با این شناسه صیادی قبلاً ثبت شده است")
            val existing = d.id?.let { dao.getCheque(it) }
            val entity = ChequeEntity(
                id = existing?.id ?: 0, ledgerId = d.ledgerId, direction = d.direction, amountRial = d.amountRial,
                dueEpochDay = d.dueDate.toEpochDay(), counterpartyName = d.counterparty.trim(), sayadId = sayad,
                serial = d.serial.trim().ifBlank { null }, bank = d.bank, accountId = d.accountId,
                status = existing?.status ?: ChequeStatus.PENDING, transactionId = existing?.transactionId,
                note = d.note.trim(), remindersEnabled = d.reminders, createdAt = existing?.createdAt ?: System.currentTimeMillis(),
            )
            if (existing == null) dao.insertCheque(entity) else { dao.updateCheque(entity); entity.id }
        }
        onDuesChanged()
        return id
    }

    /** پاس شد: posts the money to the linked account (received → income, issued → expense). */
    suspend fun clearCheque(id: Long): Long? = db.withTransaction {
        val c = dao.getCheque(id) ?: return@withTransaction null
        if (c.status != ChequeStatus.PENDING) return@withTransaction c.transactionId
        val txId = c.accountId?.let { accountId ->
            val received = c.direction == ChequeDirection.RECEIVED
            transactions.save(
                TransactionDraft(
                    ledgerId = c.ledgerId, kind = if (received) DraftKind.INCOME else DraftKind.EXPENSE, amountRial = c.amountRial,
                    accountId = accountId, categoryId = if (received) categoryByKey(c.ledgerId, CategoryKind.INCOME, "CHEQUE") else null,
                    occurredAt = System.currentTimeMillis(), source = TxSource.CHEQUE,
                    note = (if (received) "وصول چک " else "پرداخت چک ") + c.counterpartyName,
                ),
            )
        }
        dao.setChequeStatus(id, ChequeStatus.CLEARED, txId)
        txId
    }

    suspend fun bounceCheque(id: Long) = setChequeStatusReverting(id, ChequeStatus.BOUNCED)
    suspend fun reopenCheque(id: Long) = setChequeStatusReverting(id, ChequeStatus.PENDING)

    /** Any status change away from CLEARED removes the posted transaction (and re-derives balances). */
    private suspend fun setChequeStatusReverting(id: Long, status: ChequeStatus) {
        db.withTransaction {
            val c = dao.getCheque(id) ?: return@withTransaction
            c.transactionId?.let { transactions.delete(it) }
            dao.setChequeStatus(id, status, null)
        }
        onDuesChanged()
    }

    suspend fun deleteCheque(id: Long) = db.withTransaction { dao.deleteCheque(id) }

    // ============================================================ loans

    suspend fun createLoan(d: LoanDraft): Long {
        if (d.title.isBlank()) throw DueValidationException("عنوان وام را وارد کنید")
        if (d.installmentRial <= 0) throw DueValidationException("مبلغ هر قسط را وارد کنید")
        if (d.count !in 1..600) throw DueValidationException("تعداد اقساط باید بین ۱ تا ۶۰۰ باشد")
        if (d.alreadyPaid !in 0..d.count) throw DueValidationException("تعداد اقساط پرداخت‌شده بیشتر از کل اقساط است")
        val id = db.withTransaction {
            val loanId = dao.insertLoan(
                LoanEntity(
                    ledgerId = d.ledgerId, title = d.title.trim(), lender = d.lender.trim(),
                    principalRial = if (d.principalRial > 0) d.principalRial else d.installmentRial * d.count,
                    installmentAmountRial = d.installmentRial, totalInstallments = d.count, dueDayOfMonth = d.firstDue.day,
                    firstDueEpochDay = d.firstDue.toEpochDay(), accountId = d.accountId, autoDeductOnConfirm = d.autoDeduct,
                    remindersEnabled = d.reminders,
                    status = if (d.alreadyPaid == d.count) LoanStatus.SETTLED else LoanStatus.ACTIVE,
                ),
            )
            val now = System.currentTimeMillis()
            dao.insertInstallments(
                InstallmentSchedule.build(d.firstDue, d.count).mapIndexed { i, date ->
                    val paid = i < d.alreadyPaid
                    InstallmentEntity(
                        loanId = loanId, number = i + 1, dueEpochDay = date.toEpochDay(), amountRial = d.installmentRial,
                        status = if (paid) InstallmentStatus.PAID else InstallmentStatus.DUE, paidAt = if (paid) now else null,
                    )
                },
            )
            loanId
        }
        onDuesChanged()
        return id
    }

    /** «پرداخت شد»: marks paid and, when auto-deduct is on, debits the loan's account. */
    suspend fun payInstallment(installmentId: Long): Long? {
        val tx = db.withTransaction {
            val inst = dao.getInstallment(installmentId) ?: return@withTransaction null
            if (inst.status == InstallmentStatus.PAID) return@withTransaction inst.transactionId
            val loan = dao.getLoan(inst.loanId) ?: return@withTransaction null
            val txId = if (loan.autoDeductOnConfirm && loan.accountId != null) {
                transactions.save(
                    TransactionDraft(
                        ledgerId = loan.ledgerId, kind = DraftKind.EXPENSE, amountRial = inst.amountRial, accountId = loan.accountId,
                        categoryId = categoryByKey(loan.ledgerId, CategoryKind.EXPENSE, "LOAN"), occurredAt = System.currentTimeMillis(),
                        source = TxSource.INSTALLMENT, note = "قسط ${inst.number} از ${loan.totalInstallments} — ${loan.title}",
                    ),
                )
            } else null
            dao.setInstallmentStatus(inst.id, InstallmentStatus.PAID, System.currentTimeMillis(), txId)
            if (dao.countUnpaid(loan.id) == 0) dao.setLoanStatus(loan.id, LoanStatus.SETTLED)
            txId
        }
        onDuesChanged()
        return tx
    }

    suspend fun undoInstallment(installmentId: Long) = db.withTransaction {
        val inst = dao.getInstallment(installmentId) ?: return@withTransaction
        inst.transactionId?.let { transactions.delete(it) }
        dao.setInstallmentStatus(inst.id, InstallmentStatus.DUE, null, null)
        dao.setLoanStatus(inst.loanId, LoanStatus.ACTIVE)
    }

    /** Removes the plan; transactions already posted for paid installments stay in the books. */
    suspend fun deleteLoan(loanId: Long) = db.withTransaction { dao.deleteLoan(loanId) }

    // ============================================================ debts & split bills

    suspend fun addDebt(ledgerId: Long, personName: String, direction: DebtDirection, amountRial: Long, due: JalaliDate?, note: String): Long {
        if (personName.isBlank()) throw DueValidationException("نام شخص را وارد کنید")
        if (amountRial <= 0) throw DueValidationException("مبلغ را وارد کنید")
        val id = db.withTransaction {
            val personId = personId(ledgerId, personName)
            dao.insertDebt(DebtEntity(ledgerId = ledgerId, personId = personId, direction = direction, amountRial = amountRial, dueEpochDay = due?.toEpochDay(), note = note.trim()))
        }
        onDuesChanged()
        return id
    }

    /** Records a (partial) settlement; with an account it also books the cash movement. */
    suspend fun settleDebt(debtId: Long, amountRial: Long, accountId: Long?) = db.withTransaction {
        val d = dao.getDebt(debtId) ?: return@withTransaction
        val pay = amountRial.coerceIn(1, d.amountRial - d.settledRial)
        if (accountId != null) {
            val person = dao.listPeople(d.ledgerId).firstOrNull { it.id == d.personId }?.name.orEmpty()
            transactions.save(
                TransactionDraft(
                    ledgerId = d.ledgerId, kind = if (d.direction == DebtDirection.THEY_OWE_ME) DraftKind.INCOME else DraftKind.EXPENSE,
                    amountRial = pay, accountId = accountId, occurredAt = System.currentTimeMillis(),
                    source = if (d.splitGroupId != null) TxSource.SPLIT else TxSource.MANUAL, note = "تسویه با $person",
                ),
            )
        }
        dao.setDebtSettled(d.id, d.settledRial + pay)
    }

    suspend fun deleteDebt(debtId: Long) = db.withTransaction { dao.deleteDebt(debtId) }

    /**
     * دنگ. If I paid: everyone else owes me their share (and the whole bill can be booked as an
     * expense from my account). If someone else paid: I owe that person my share only.
     */
    suspend fun splitBill(d: SplitDraft): List<SplitCalculator.Share> {
        val names = d.participants.map { it.first.trim() }
        if (d.totalRial <= 0) throw DueValidationException("مبلغ کل را وارد کنید")
        if (names.size < 2) throw DueValidationException("حداقل دو نفر لازم است")
        if (names.any { it.isBlank() }) throw DueValidationException("نام همه‌ی افراد را وارد کنید")
        if (names.toSet().size != names.size) throw DueValidationException("نام تکراری در فهرست افراد هست")
        if (SplitDraft.ME !in names) throw DueValidationException("خودتان («من») باید در فهرست باشید")
        if (d.payer !in names) throw DueValidationException("پرداخت‌کننده باید یکی از افراد باشد")

        val shares = SplitCalculator.split(d.totalRial, d.participants.map { SplitCalculator.Participant(it.first.trim(), it.second) }, d.payer)
        db.withTransaction {
            val group = UUID.randomUUID().toString()
            val note = d.title.trim().ifBlank { "دنگ" }
            if (d.payer == SplitDraft.ME) {
                shares.filter { it.key != SplitDraft.ME && it.amountRial > 0 }.forEach { s ->
                    dao.insertDebt(DebtEntity(ledgerId = d.ledgerId, personId = personId(d.ledgerId, s.key), direction = DebtDirection.THEY_OWE_ME, amountRial = s.amountRial, note = note, splitGroupId = group))
                }
                d.accountId?.let { acc ->
                    transactions.save(
                        TransactionDraft(ledgerId = d.ledgerId, kind = DraftKind.EXPENSE, amountRial = d.totalRial, accountId = acc, categoryId = d.categoryId, occurredAt = System.currentTimeMillis(), source = TxSource.SPLIT, note = "$note (کل صورتحساب)"),
                    )
                }
            } else {
                val mine = shares.first { it.key == SplitDraft.ME }.amountRial
                if (mine > 0) dao.insertDebt(DebtEntity(ledgerId = d.ledgerId, personId = personId(d.ledgerId, d.payer), direction = DebtDirection.I_OWE_THEM, amountRial = mine, note = note, splitGroupId = group))
            }
        }
        onDuesChanged()
        return shares
    }

    // ============================================================ helpers

    private suspend fun personId(ledgerId: Long, name: String): Long =
        dao.findPerson(ledgerId, name.trim())?.id ?: dao.insertPerson(PersonEntity(ledgerId = ledgerId, name = name.trim()))

    private suspend fun categoryByKey(ledgerId: Long, kind: CategoryKind, key: String): Long? =
        db.categoryDao().listByKind(ledgerId, kind).firstOrNull { key in it.matchKeywords.split(',') }?.id
}
