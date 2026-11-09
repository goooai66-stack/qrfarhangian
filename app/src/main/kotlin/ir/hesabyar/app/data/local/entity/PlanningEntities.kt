package ir.hesabyar.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import ir.hesabyar.domain.sms.Bank

// ============================================================== cheques (چک صیادی)

enum class ChequeDirection { RECEIVED, ISSUED }
enum class ChequeStatus { PENDING, CLEARED, BOUNCED, CANCELLED, ENDORSED }

@Entity(
    tableName = "cheques",
    foreignKeys = [ForeignKey(entity = LedgerEntity::class, parentColumns = ["id"], childColumns = ["ledgerId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("ledgerId"), Index("dueEpochDay"), Index("status"), Index(value = ["sayadId"], unique = true)],
)
data class ChequeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val direction: ChequeDirection,
    val amountRial: Long,
    val dueEpochDay: Long,
    val counterpartyName: String,
    /** 16-digit Sayad id (شناسه صیادی). Nullable for old non-Sayad cheques. */
    val sayadId: String? = null,
    val serial: String? = null,
    val bank: Bank? = null,
    val accountId: Long? = null,
    val status: ChequeStatus = ChequeStatus.PENDING,
    val transactionId: Long? = null,
    val note: String = "",
    val remindersEnabled: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
)

// ============================================================== loans & installments (اقساط)

enum class LoanStatus { ACTIVE, SETTLED }

@Entity(
    tableName = "loans",
    foreignKeys = [ForeignKey(entity = LedgerEntity::class, parentColumns = ["id"], childColumns = ["ledgerId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("ledgerId")],
)
data class LoanEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val title: String,
    val lender: String,
    val principalRial: Long,
    val installmentAmountRial: Long,
    val totalInstallments: Int,
    /** Jalali day-of-month the installment is due (1..31, clamped to month length). */
    val dueDayOfMonth: Int,
    val firstDueEpochDay: Long,
    val annualRatePercent: Double? = null,
    /** Account to debit when the user confirms an installment payment. */
    val accountId: Long? = null,
    val autoDeductOnConfirm: Boolean = true,
    val status: LoanStatus = LoanStatus.ACTIVE,
    val remindersEnabled: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
)

enum class InstallmentStatus { DUE, PAID, SKIPPED }

@Entity(
    tableName = "installments",
    foreignKeys = [ForeignKey(entity = LoanEntity::class, parentColumns = ["id"], childColumns = ["loanId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index(value = ["loanId", "number"], unique = true), Index("dueEpochDay"), Index("status")],
)
data class InstallmentEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val loanId: Long,
    /** 1-based: "۱۲ از ۳۶" */
    val number: Int,
    val dueEpochDay: Long,
    val amountRial: Long,
    val status: InstallmentStatus = InstallmentStatus.DUE,
    val paidAt: Long? = null,
    val transactionId: Long? = null,
)

// ============================================================== people, debts, split bills (دنگ)

@Entity(
    tableName = "people",
    foreignKeys = [ForeignKey(entity = LedgerEntity::class, parentColumns = ["id"], childColumns = ["ledgerId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("ledgerId")],
)
data class PersonEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val name: String,
    val phone: String? = null,
)

enum class DebtDirection { THEY_OWE_ME, I_OWE_THEM }

@Entity(
    tableName = "debts",
    foreignKeys = [ForeignKey(entity = PersonEntity::class, parentColumns = ["id"], childColumns = ["personId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("personId"), Index("splitGroupId"), Index("ledgerId")],
)
data class DebtEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val personId: Long,
    val direction: DebtDirection,
    val amountRial: Long,
    val settledRial: Long = 0,
    val dueEpochDay: Long? = null,
    val note: String = "",
    /** Set when created by the split-bill calculator: all shares of one bill. */
    val splitGroupId: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
)

// ============================================================== inflation-proof savings (سپر ضدتورم)

enum class SavingsUnit { GOLD_18K_GRAM, USD, USDT }

@Entity(
    tableName = "savings_goals",
    foreignKeys = [ForeignKey(entity = LedgerEntity::class, parentColumns = ["id"], childColumns = ["ledgerId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("ledgerId")],
)
data class SavingsGoalEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val title: String,
    /** The goal is denominated in a real asset, not in Toman: "50 grams of 18k gold". */
    val unit: SavingsUnit,
    /** Milli-units (grams×1000, dollars×1000) — integer math, no Double drift. */
    val targetMilliUnits: Long,
    val deadlineEpochDay: Long? = null,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
)

@Entity(
    tableName = "savings_deposits",
    foreignKeys = [ForeignKey(entity = SavingsGoalEntity::class, parentColumns = ["id"], childColumns = ["goalId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("goalId")],
)
data class SavingsDepositEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val goalId: Long,
    val amountRial: Long,
    /** Price of one unit on deposit day — the basis of "inflation gain/loss" analytics. */
    val unitPriceRialAtDeposit: Long,
    val milliUnitsAcquired: Long,
    val depositedAt: Long,
    val transactionId: Long? = null,
)

// ============================================================== market rates cache

enum class RateKey(val persianName: String) {
    GOLD_18K_GRAM("طلای ۱۸ عیار (گرم)"),
    COIN_EMAMI("سکه امامی"),
    COIN_HALF("نیم‌سکه"),
    COIN_QUARTER("ربع‌سکه"),
    USD("دلار"),
    USDT("تتر"),
}

/** Last known price per instrument; the dashboard works offline from this cache. */
@Entity(tableName = "rates")
data class RateEntity(
    @PrimaryKey val key: RateKey,
    val priceRial: Long,
    val changePercent: Double? = null,
    val fetchedAt: Long,
    val source: String,
)
