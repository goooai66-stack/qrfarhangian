package ir.hesabyar.app.sms

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.AccountKind
import ir.hesabyar.app.data.local.entity.BankSmsEntity
import ir.hesabyar.app.data.local.entity.LedgerKind
import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.sms.BankSmsParser
import ir.hesabyar.domain.sms.ParsedBankSms
import ir.hesabyar.domain.sms.SelfTransferDetector
import ir.hesabyar.domain.sms.SmsParseResult
import ir.hesabyar.domain.sms.TxDirection
import java.security.MessageDigest

/**
 * Shared pipeline for live SMS (receiver) and historical import (inbox scan):
 * parse → dedupe → match/create account → pair self-transfers → store as PENDING.
 */
class SmsIngestor(
    private val db: AppDatabase,
    private val parser: BankSmsParser,
    private val detector: SelfTransferDetector,
) {
    private val smsDao = db.bankSmsDao()
    private val accountDao = db.accountDao()

    /** @return the stored inbox item, or null if ignored (OTP, promo, duplicate…). */
    suspend fun ingest(sender: String, body: String, timestampMillis: Long): BankSmsEntity? = db.withTransaction {
        val accounts = accountDao.listAll()
        val senderHints = accounts.mapNotNull { a -> a.smsSender?.let { s -> a.bank?.let { s to it } } }.toMap()
        val parsed = (parser.parse(sender, body, timestampMillis, senderHints) as? SmsParseResult.Parsed)?.sms
            ?: return@withTransaction null

        val accountId = matchAccount(parsed, sender, accounts) ?: createAccountFor(parsed, sender)
        val id = smsDao.insert(
            BankSmsEntity(
                sender = sender, body = body, bodyHash = hash(sender, body, timestampMillis), receivedAt = timestampMillis,
                bank = parsed.bank, isDebit = parsed.direction == TxDirection.DEBIT, amountRial = parsed.amountRial,
                balanceRial = parsed.balanceRial, accountHint = parsed.accountHint, occurredAt = parsed.occurredAtMillis,
                channel = parsed.channel.name, confidence = parsed.confidence, matchedAccountId = accountId,
            ),
        )
        if (id == -1L) return@withTransaction null // duplicate

        val me = SelfTransferDetector.Candidate(id, accountId, parsed.direction, parsed.amountRial, parsed.occurredAtMillis)
        val window = 2 * 60_000L
        val recent = smsDao.pendingBetween(parsed.occurredAtMillis - window, parsed.occurredAtMillis + window).map {
            SelfTransferDetector.Candidate(it.id, it.matchedAccountId, if (it.isDebit) TxDirection.DEBIT else TxDirection.CREDIT, it.amountRial, it.occurredAt)
        }
        detector.findCounterpart(me, recent)?.let { other ->
            smsDao.markSelfTransfer(id, other.id)
            smsDao.markSelfTransfer(other.id, id)
        }
        smsDao.getById(id)
    }

    private fun matchAccount(p: ParsedBankSms, sender: String, accounts: List<AccountEntity>): Long? {
        val hint = p.accountHint
        if (hint != null) accounts.firstOrNull { it.cardLast4 == hint }?.let { return it.id }
        accounts.filter { it.smsSender == sender && (hint == null || it.cardLast4 == null) }.singleOrNull()?.let { return it.id }
        if (hint == null && p.bank != Bank.UNKNOWN) accounts.filter { it.bank == p.bank }.singleOrNull()?.let { return it.id }
        return null
    }

    /**
     * First SMS from an unknown card: create the account automatically so the user never has to
     * set anything up. When the SMS reports a balance, the opening balance is back-computed so that,
     * once confirmed, the app's balance equals the bank's to the Rial.
     */
    private suspend fun createAccountFor(p: ParsedBankSms, sender: String): Long {
        val ledgers = db.ledgerDao().listAll()
        val ledgerId = (ledgers.firstOrNull { it.kind == LedgerKind.PERSONAL } ?: ledgers.first()).id
        val signed = if (p.direction == TxDirection.DEBIT) -p.amountRial else p.amountRial
        val opening = p.balanceRial?.let { it - signed } ?: 0L
        val name = buildString {
            append(if (p.bank == Bank.UNKNOWN) "حساب بانکی" else p.bank.persianName)
            p.accountHint?.let { append(" •••• ").append(it) }
        }
        return accountDao.insert(
            AccountEntity(
                ledgerId = ledgerId, name = name, kind = AccountKind.BANK, bank = p.bank, cardLast4 = p.accountHint,
                accountNumberMasked = p.accountRaw, smsSender = sender, openingBalanceRial = opening,
                currentBalanceRial = opening, colorArgb = 0xFF1B2A4A,
            ),
        )
    }

    private fun hash(sender: String, body: String, ts: Long): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest("$sender|$body|${ts / 1000}".toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
