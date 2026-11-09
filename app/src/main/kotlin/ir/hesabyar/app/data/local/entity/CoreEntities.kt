package ir.hesabyar.app.data.local.entity

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import ir.hesabyar.domain.ledger.TransactionType
import ir.hesabyar.domain.sms.Bank

/*
 * Conventions for every table:
 *  - money: Long Rial (`…Rial`), never Float/Double
 *  - instants: epoch millis (`…At`); calendar days: epoch day (`…EpochDay`), converted to Jalali in the UI
 *  - enums are stored by name (Room built-in), so reordering an enum never corrupts data
 */

enum class LedgerKind { PERSONAL, BUSINESS }

/** «دفتر»: personal/family vs. small business. Free: 2, more via rewarded unlock. */
@Entity(tableName = "ledgers")
data class LedgerEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    val kind: LedgerKind,
    val colorArgb: Long,
    val sortOrder: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
)

enum class AccountKind { BANK, CASH, WALLET }

@Entity(
    tableName = "accounts",
    foreignKeys = [ForeignKey(entity = LedgerEntity::class, parentColumns = ["id"], childColumns = ["ledgerId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("ledgerId"), Index("cardLast4"), Index("smsSender")],
)
data class AccountEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val name: String,
    val kind: AccountKind,
    val bank: Bank? = null,
    /** Last 4 digits of card *or* account number, matched against ParsedBankSms.accountHint. */
    val cardLast4: String? = null,
    val accountNumberMasked: String? = null,
    /** Learned on first confirmation: SMS sender id → this account. */
    val smsSender: String? = null,
    val openingBalanceRial: Long = 0,
    /** Cache of the chronologically last balanceAfter; rewritten by every recompute. */
    val currentBalanceRial: Long = 0,
    val colorArgb: Long,
    val isArchived: Boolean = false,
    val sortOrder: Int = 0,
    val createdAt: Long = System.currentTimeMillis(),
)

enum class CategoryKind { EXPENSE, INCOME }

@Entity(
    tableName = "categories",
    foreignKeys = [ForeignKey(entity = LedgerEntity::class, parentColumns = ["id"], childColumns = ["ledgerId"], onDelete = ForeignKey.CASCADE)],
    indices = [Index("ledgerId")],
)
data class CategoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val name: String,
    /** Emoji glyph — zero bytes of icon assets in the APK. */
    val icon: String,
    val colorArgb: Long,
    val kind: CategoryKind,
    /** Comma separated; SMS channel names (PURCHASE, BILL…) or words for auto-suggestion. */
    val matchKeywords: String = "",
    val sortOrder: Int = 0,
    val isArchived: Boolean = false,
)

enum class TxSource { MANUAL, SMS, VOICE, INSTALLMENT, CHEQUE, SAVINGS_GOAL, SPLIT }

/**
 * One row per account movement. An internal transfer is two rows (TRANSFER_OUT on the source,
 * TRANSFER_IN on the destination) sharing [transferGroupId], so every account has its own exact
 * running balance and reports can exclude transfers with one predicate.
 */
@Entity(
    tableName = "transactions",
    foreignKeys = [
        ForeignKey(entity = AccountEntity::class, parentColumns = ["id"], childColumns = ["accountId"], onDelete = ForeignKey.CASCADE),
        ForeignKey(entity = CategoryEntity::class, parentColumns = ["id"], childColumns = ["categoryId"], onDelete = ForeignKey.SET_NULL),
    ],
    indices = [
        Index(value = ["accountId", "occurredAt", "id"]),
        Index(value = ["ledgerId", "occurredAt"]),
        Index("categoryId"),
        Index("transferGroupId"),
        Index("smsId"),
    ],
)
data class TransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val ledgerId: Long,
    val accountId: Long,
    val type: TransactionType,
    /** Always positive; the sign comes from [type]. */
    val amountRial: Long,
    /** Running balance of [accountId] right after this row, in chronological order. */
    val balanceAfterRial: Long = 0,
    val categoryId: Long? = null,
    val occurredAt: Long,
    val note: String = "",
    val source: TxSource = TxSource.MANUAL,
    val smsId: Long? = null,
    val transferGroupId: String? = null,
    val personId: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
)

enum class SmsStatus { PENDING, CONFIRMED, DISMISSED, SELF_TRANSFER }

/**
 * Parsed bank SMS waiting in the «صندوق پیامک» for one-tap confirmation.
 * OTP messages never reach this table (dropped in the parser).
 */
@Entity(
    tableName = "bank_sms",
    indices = [Index(value = ["bodyHash"], unique = true), Index("status"), Index("occurredAt")],
)
data class BankSmsEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val sender: String,
    val body: String,
    /** SHA-256(sender|body|timestamp/1000): the receiver and the inbox import never double count. */
    val bodyHash: String,
    val receivedAt: Long,
    val bank: Bank,
    val isDebit: Boolean,
    val amountRial: Long,
    val balanceRial: Long?,
    val accountHint: String?,
    val occurredAt: Long,
    val channel: String,
    val confidence: Float,
    val status: SmsStatus = SmsStatus.PENDING,
    val matchedAccountId: Long? = null,
    val selfTransferPairId: Long? = null,
    val transactionId: Long? = null,
)
