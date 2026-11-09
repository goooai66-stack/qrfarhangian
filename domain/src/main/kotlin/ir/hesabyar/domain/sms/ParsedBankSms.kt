package ir.hesabyar.domain.sms

enum class TxDirection { DEBIT, CREDIT }

/** Best-guess channel; used to pre-select a category in the one-tap confirmation card. */
enum class TxChannel { PURCHASE, ATM, TRANSFER, BILL, SALARY, INTEREST, FEE, LOAN, CHEQUE, UNKNOWN }

data class ParsedBankSms(
    val bank: Bank,
    val direction: TxDirection,
    val amountRial: Long,
    val balanceRial: Long?,
    /** Last 4 digits of the card/account if present — the key used to match the user's account. */
    val accountHint: String?,
    /** Full (possibly masked) account/card token as written in the SMS. */
    val accountRaw: String?,
    /** Time stated in the SMS, or the receive time when the SMS has none. */
    val occurredAtMillis: Long,
    val dateFromSms: Boolean,
    val channel: TxChannel,
    /** 0..1 — below [BankSmsParser.MIN_AUTO_CONFIDENCE] the app asks the user to review. */
    val confidence: Float,
)

sealed interface SmsParseResult {
    data class Parsed(val sms: ParsedBankSms) : SmsParseResult
    data class Ignored(val reason: IgnoreReason) : SmsParseResult
}

enum class IgnoreReason {
    /** OTP / dynamic password / verification code — never stored, never shown. */
    SECURITY_CODE,
    NOT_A_BANK_MESSAGE,
    NO_AMOUNT,
    PROMOTIONAL,
    /** Declined / failed operations: no money moved. */
    FAILED_OPERATION,
}
