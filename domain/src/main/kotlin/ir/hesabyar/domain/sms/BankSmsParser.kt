package ir.hesabyar.domain.sms

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.text.PersianText
import java.util.TimeZone

/**
 * Offline parser for Iranian bank transaction SMS. 100% on-device, regex only, no network.
 *
 * Instead of one brittle template per bank (which breaks every time a bank edits its SMS), the
 * engine is *label driven*: every Iranian bank SMS is a handful of `label value` pairs —
 * «برداشت ۱,۵۰۰,۰۰۰», «مانده: ۱۲,۰۰۰,۰۰۰», «حساب ۰۱۰۱...۰۰۸», «۱۴۰۳/۰۸/۱۵-۱۴:۲۳» — in any
 * order, with or without colons, on one line or many. The label vocabulary below covers
 * Melli, Mellat, Saderat, Tejarat, Sepah, Pasargad, Parsian, Saman, Maskan, Resalat, Keshavarzi,
 * Refah, Blu, Wepod and the other banks in [Bank]. Bank-specific quirks (trailing sign
 * «۱,۰۰۰,۰۰۰-», MMDD-HH:MM dates, Toman units) are handled as generic variants so a new bank
 * usually works without code changes.
 *
 * Pipeline:
 *  1. normalize (digits, Arabic letters, bidi marks)   4. account / card hint
 *  2. drop OTP & failed operations                      5. Jalali date + time
 *  3. amount (+sign, unit) and balance                  6. direction, channel, confidence
 */
class BankSmsParser(
    private val zone: TimeZone = JalaliDate.TEHRAN,
) {

    fun parse(
        sender: String,
        body: String,
        receivedAtMillis: Long,
        senderHints: Map<String, Bank> = emptyMap(),
    ): SmsParseResult {
        val text = PersianText.normalize(body)
        val lower = text.lowercase()

        if (OtpFilter.isSecurityCode(lower)) return SmsParseResult.Ignored(IgnoreReason.SECURITY_CODE)
        if (FAILED_KEYWORDS.any { lower.contains(it) }) return SmsParseResult.Ignored(IgnoreReason.FAILED_OPERATION)

        val bank = Bank.detect(sender, lower, senderHints)

        val balanceMatch = BALANCE.find(text)
        val balanceRange = balanceMatch?.range
        val amount = findAmount(text, balanceRange) ?: return SmsParseResult.Ignored(IgnoreReason.NO_AMOUNT)
        val balance = balanceMatch?.let { m ->
            val v = parseNumber(m.groupValues[2]) ?: return@let null
            val unit = m.groupValues[3]
            val rial = if (unit == "تومان") v * 10 else v
            if (m.groupValues[1] == "-") -rial else rial
        }

        val account = findAccount(text, balanceRange)

        // Store / marketing SMS also contain amounts ("۵۰,۰۰۰ تومان تخفیف"). Without a known bank
        // or a balance line we refuse to treat them as money movement.
        val looksPromotional = PROMO_KEYWORDS.any { lower.contains(it) }
        if (balance == null && (bank == Bank.UNKNOWN || looksPromotional)) {
            return SmsParseResult.Ignored(if (looksPromotional) IgnoreReason.PROMOTIONAL else IgnoreReason.NOT_A_BANK_MESSAGE)
        }

        // Keyword search runs on the text *without* the balance segment, so that
        // «مانده قابل برداشت» is not mistaken for a withdrawal.
        val keywordText = if (balanceRange != null) lower.removeRange(balanceRange) else lower
        val (direction, directionFromSign) = resolveDirection(amount.sign, keywordText)

        val date = findDateTime(text, receivedAtMillis)

        var confidence = 0.4f
        if (bank != Bank.UNKNOWN) confidence += 0.15f
        confidence += when {
            directionFromSign -> 0.2f
            direction != null -> 0.15f
            else -> 0f
        }
        if (balance != null) confidence += 0.15f
        if (account != null) confidence += 0.05f
        if (date != null) confidence += 0.05f

        return SmsParseResult.Parsed(
            ParsedBankSms(
                bank = bank,
                // Unknown direction → DEBIT (the common case) with low confidence: the user confirms.
                direction = direction ?: TxDirection.DEBIT,
                amountRial = amount.rial,
                balanceRial = balance,
                accountHint = account?.let { lastDigits(it, 4) },
                accountRaw = account,
                occurredAtMillis = date ?: receivedAtMillis,
                dateFromSms = date != null,
                channel = resolveChannel(keywordText),
                confidence = confidence.coerceAtMost(1f),
            ),
        )
    }

    // ------------------------------------------------------------------ amount

    private data class Amount(val rial: Long, val sign: Char?, val range: IntRange)

    private fun findAmount(text: String, balanceRange: IntRange?): Amount? {
        fun overlapsBalance(r: IntRange) = balanceRange != null && r.first <= balanceRange.last && balanceRange.first <= r.last

        // 1) Labeled amount: «برداشت ۱,۵۰۰,۰۰۰» «مبلغ: 2,000,000 ریال» «واریز:+500,000»
        for (m in LABELED_AMOUNT.findAll(text)) {
            if (overlapsBalance(m.range)) continue
            val value = parseNumber(m.groupValues[2]) ?: continue
            if (value <= 0) continue
            val sign = m.groupValues[1].firstOrNull() ?: m.groupValues[4].firstOrNull()
            return Amount(applyUnit(value, m.groupValues[3]), sign, m.range)
        }
        // 2) Signed line: «1,000,000-» or «+250,000 ریال» (Saderat / Tejarat style)
        for (m in SIGNED_LINE.findAll(text)) {
            if (overlapsBalance(m.range)) continue
            // Groups: leading form (1 sign, 2 number, 3 unit) | trailing form (4 number, 5 unit, 6 sign)
            val leading = m.groupValues[2].isNotEmpty()
            val value = parseNumber(m.groupValues[if (leading) 2 else 4]) ?: continue
            if (value <= 0) continue
            val sign = m.groupValues[if (leading) 1 else 6].firstOrNull()
            val unit = m.groupValues[if (leading) 3 else 5]
            return Amount(applyUnit(value, unit), sign, m.range)
        }
        // 3) Any grouped number followed by a currency unit.
        for (m in UNIT_AMOUNT.findAll(text)) {
            if (overlapsBalance(m.range)) continue
            val value = parseNumber(m.groupValues[1]) ?: continue
            if (value <= 0) continue
            return Amount(applyUnit(value, m.groupValues[2]), null, m.range)
        }
        return null
    }

    private fun applyUnit(value: Long, unit: String): Long = if (unit == "تومان") value * 10 else value

    private fun parseNumber(raw: String): Long? {
        val digits = raw.replace(",", "")
        if (digits.isEmpty() || digits.length > 15) return null // > 15 digits: an account number, not money
        return digits.toLongOrNull()
    }

    // ------------------------------------------------------------------ account

    private fun findAccount(text: String, balanceRange: IntRange?): String? {
        for (m in ACCOUNT.findAll(text)) {
            if (balanceRange != null && m.range.first in balanceRange) continue
            val token = m.groupValues[1].trim('.', '-', '…')
            if (token.count { it.isDigit() } >= 4) return token
        }
        return null
    }

    private fun lastDigits(token: String, n: Int): String {
        val digits = token.filter { it.isDigit() }
        return if (digits.length <= n) digits else digits.substring(digits.length - n)
    }

    // ------------------------------------------------------------------ date

    private fun findDateTime(text: String, receivedAt: Long): Long? {
        val received = JalaliDate.fromEpochMillis(receivedAt, zone)
        var date: JalaliDate? = null
        var hour = -1
        var minute = 0

        FULL_DATE.find(text)?.let { m ->
            date = safeDate(m.groupValues[1].toInt(), m.groupValues[2].toInt(), m.groupValues[3].toInt())
        }
        if (date == null) SHORT_YEAR_DATE.find(text)?.let { m ->
            val yy = m.groupValues[1].toInt()
            val year = if (yy >= 50) 1300 + yy else 1400 + yy
            date = safeDate(year, m.groupValues[2].toInt(), m.groupValues[3].toInt())
        }
        if (date == null) COMPACT_DATE_TIME.find(text)?.let { m ->
            // Melli style: «0815-14:23»  → month 08, day 15
            date = inferYear(received, m.groupValues[1].toInt(), m.groupValues[2].toInt())
            hour = m.groupValues[3].toInt()
            minute = m.groupValues[4].toInt()
        }
        if (date == null) MONTH_DAY.find(text)?.let { m ->
            date = inferYear(received, m.groupValues[1].toInt(), m.groupValues[2].toInt())
        }
        val d = date ?: return null

        if (hour < 0) {
            TIME.find(text)?.let { m ->
                hour = m.groupValues[1].toInt()
                minute = m.groupValues[2].toInt()
            }
        }
        if (hour !in 0..23 || minute !in 0..59) { hour = 12; minute = 0 }

        val millis = JalaliDate.toEpochMillis(d, hour, minute, 0, zone)
        // Sanity window: SMS dates in the future or > 60 days old are almost certainly a misparse.
        val earliest = receivedAt - 60L * DAY_MS
        val latest = receivedAt + DAY_MS
        return millis.takeIf { it in earliest..latest }
    }

    private fun safeDate(y: Int, m: Int, d: Int): JalaliDate? =
        if (JalaliDate.isValid(y, m, d)) JalaliDate(y, m, d) else null

    /** SMS without year: pick the most recent past occurrence of month/day. */
    private fun inferYear(received: JalaliDate, month: Int, day: Int): JalaliDate? {
        val thisYear = safeDate(received.year, month, day)
        if (thisYear != null && thisYear.toEpochDay() <= received.toEpochDay() + 1) return thisYear
        return safeDate(received.year - 1, month, day)
    }

    // ------------------------------------------------------------------ direction & channel

    private fun resolveDirection(sign: Char?, text: String): Pair<TxDirection?, Boolean> {
        when (sign) {
            '-' -> return TxDirection.DEBIT to true
            '+' -> return TxDirection.CREDIT to true
        }
        var best: TxDirection? = null
        var bestIndex = Int.MAX_VALUE
        for (kw in CREDIT_KEYWORDS) {
            val i = text.indexOf(kw)
            if (i in 0 until bestIndex) { bestIndex = i; best = TxDirection.CREDIT }
        }
        for (kw in DEBIT_KEYWORDS) {
            val i = text.indexOf(kw)
            // Strict "<": on a tie the longer credit phrase («انتقال به حساب شما») wins.
            if (i in 0 until bestIndex) { bestIndex = i; best = TxDirection.DEBIT }
        }
        return best to false
    }

    private fun resolveChannel(text: String): TxChannel = when {
        CHANNEL_SALARY.any { text.contains(it) } -> TxChannel.SALARY
        CHANNEL_LOAN.any { text.contains(it) } -> TxChannel.LOAN
        CHANNEL_FEE.any { text.contains(it) } -> TxChannel.FEE
        CHANNEL_BILL.any { text.contains(it) } -> TxChannel.BILL
        CHANNEL_ATM.any { text.contains(it) } -> TxChannel.ATM
        CHANNEL_PURCHASE.any { text.contains(it) } -> TxChannel.PURCHASE
        CHANNEL_CHEQUE.any { text.contains(it) } -> TxChannel.CHEQUE
        CHANNEL_INTEREST.any { text.contains(it) } -> TxChannel.INTEREST
        CHANNEL_TRANSFER.any { text.contains(it) } -> TxChannel.TRANSFER
        else -> TxChannel.UNKNOWN
    }

    companion object {
        /** Below this, the SMS is shown as "needs review" instead of one-tap confirm. */
        const val MIN_AUTO_CONFIDENCE = 0.7f

        private const val DAY_MS = 86_400_000L

        /** Grouped (1,250,000) or plain (1250000) number. Never followed by a date/time separator. */
        private const val NUM = """(\d{1,3}(?:,\d{3})+|\d+)(?![/:\d])"""
        private const val UNIT = """(ریال|تومان|rial|irr|rls)?"""

        private val AMOUNT_LABELS = listOf(
            "مبلغ", "برداشت وجه", "واریز وجه", "برداشت", "واریز", "واریزی", "خرید", "انتقال", "انتقالی",
            "کسر", "پرداخت", "بدهکار", "بستانکار", "دریافت", "انتقال وجه", "کارت به کارت", "مبلغ تراکنش",
        ).sortedByDescending { it.length }.joinToString("|")

        private val LABELED_AMOUNT = Regex(
            """(?:$AMOUNT_LABELS)\s*[:=]?\s*([+-])?\s*$NUM[ ]*$UNIT[ ]*([+-](?=[ ]*$))?""",
            setOf(RegexOption.MULTILINE, RegexOption.IGNORE_CASE),
        )

        /** «+1,000,000» at line start, or «1,000,000-» / «1,000,000 ریال-» at line end. */
        private val SIGNED_LINE = Regex(
            """(?:^[ ]*([+-])[ ]*(\d{1,3}(?:,\d{3})+|\d+)(?![/:\d])[ ]*$UNIT[ ]*$|""" +
                """^[ ]*(\d{1,3}(?:,\d{3})+|\d+)(?![/:\d])[ ]*$UNIT[ ]*([+-])[ ]*$)""",
            setOf(RegexOption.MULTILINE, RegexOption.IGNORE_CASE),
        )

        private val UNIT_AMOUNT = Regex("""(\d{1,3}(?:,\d{3})+|\d+)[ ]*(ریال|تومان)""")

        private val BALANCE = Regex(
            """(?:مانده حساب|موجودی حساب|مانده قابل برداشت|موجودی قابل برداشت|مانده|موجودی|ماند)\s*[:=]?\s*([+-])?\s*$NUM[ ]*$UNIT""",
            RegexOption.IGNORE_CASE,
        )

        private val ACCOUNT = Regex(
            """(?:شماره حساب|شماره کارت|از حساب|به حساب|از کارت|به کارت|سپرده|حساب|کارت|(?<![\p{L}])ح\.?(?=\s*:)|(?<![\p{L}])از|(?<![\p{L}])به|card|acc)\s*[:]?\s*([0-9*xX.…][0-9*xX.…\-]{3,29})""",
            RegexOption.IGNORE_CASE,
        )

        private val FULL_DATE = Regex("""(?<!\d)(1[34]\d{2})[/\-.](\d{1,2})[/\-.](\d{1,2})(?!\d)""")
        private val SHORT_YEAR_DATE = Regex("""(?<![\d/])(\d{2})/(\d{1,2})/(\d{1,2})(?![\d/])""")
        private val COMPACT_DATE_TIME = Regex("""(?<!\d)(\d{2})(\d{2})[-_ ](\d{1,2}):(\d{2})(?!\d)""")
        private val MONTH_DAY = Regex("""(?<![\d/,])(\d{1,2})/(\d{1,2})(?![\d/])""")
        private val TIME = Regex("""(?<![\d,])([01]?\d|2[0-3]):([0-5]\d)(?::[0-5]\d)?(?!\d)""")

        private val CREDIT_KEYWORDS = listOf(
            "واریز", "بستانکار", "انتقال به حساب شما", "به حساب شما", "دریافت", "سود سپرده",
            "برگشت", "استرداد", "حقوق",
        )
        private val DEBIT_KEYWORDS = listOf(
            "برداشت", "خرید", "کسر", "پرداخت", "بدهکار", "انتقال", "کارت به کارت", "خودپرداز",
            "کارمزد", "قسط",
        )

        private val FAILED_KEYWORDS = listOf("ناموفق", "عدم موفقیت", "انجام نشد", "رد شد", "موجودی کافی نیست", "لغو شد")
        private val PROMO_KEYWORDS = listOf("تخفیف", "جشنواره", "قرعه کشی", "قرعه‌کشی", "لغو11", "http", "www.", "کد تخفیف", "هدیه")

        private val CHANNEL_SALARY = listOf("حقوق", "مستمری")
        private val CHANNEL_LOAN = listOf("قسط", "اقساط", "تسهیلات", "وام")
        private val CHANNEL_FEE = listOf("کارمزد")
        private val CHANNEL_BILL = listOf("قبض", "شارژ", "بسته اینترنت")
        private val CHANNEL_ATM = listOf("خودپرداز", "atm", "عابربانک")
        private val CHANNEL_PURCHASE = listOf("خرید", "پایانه", "pos", "فروشگاه")
        private val CHANNEL_CHEQUE = listOf("چک")
        private val CHANNEL_INTEREST = listOf("سود")
        private val CHANNEL_TRANSFER = listOf("انتقال", "کارت به کارت", "پایا", "ساتنا", "شبا", "پل")
    }
}
