package ir.hesabyar.domain

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.sms.BankSmsParser
import ir.hesabyar.domain.sms.IgnoreReason
import ir.hesabyar.domain.sms.ParsedBankSms
import ir.hesabyar.domain.sms.SmsParseResult
import ir.hesabyar.domain.sms.TxChannel
import ir.hesabyar.domain.sms.TxDirection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * Samples follow the public structure of each bank's SMS (label/value lines). Account numbers
 * and amounts are fictitious. Add every new real-world format the beta testers report here.
 */
class BankSmsParserTest {

    private val parser = BankSmsParser()
    private val received = JalaliDate.toEpochMillis(JalaliDate(1403, 8, 15), 14, 25)

    private fun parse(body: String, sender: String = "98200"): ParsedBankSms =
        when (val r = parser.parse(sender, body, received)) {
            is SmsParseResult.Parsed -> r.sms
            is SmsParseResult.Ignored -> { fail("ignored: ${r.reason}"); throw IllegalStateException() }
        }

    private fun ignoredReason(body: String): IgnoreReason? =
        (parser.parse("98200", body, received) as? SmsParseResult.Ignored)?.reason

    private fun assertTime(sms: ParsedBankSms, date: JalaliDate, h: Int, m: Int) {
        assertTrue("date should come from SMS", sms.dateFromSms)
        assertEquals(JalaliDate.toEpochMillis(date, h, m), sms.occurredAtMillis)
    }

    @Test fun mellatWithdrawal() {
        val s = parse("بانک ملت\nبرداشت1,500,000\nاز حساب 123456789\nمانده 12,345,678\n1403/08/15-14:23")
        assertEquals(Bank.MELLAT, s.bank)
        assertEquals(TxDirection.DEBIT, s.direction)
        assertEquals(1_500_000L, s.amountRial)
        assertEquals(12_345_678L, s.balanceRial)
        assertEquals("6789", s.accountHint)
        assertTime(s, JalaliDate(1403, 8, 15), 14, 23)
        assertTrue(s.confidence >= BankSmsParser.MIN_AUTO_CONFIDENCE)
    }

    @Test fun melliArabicLettersPersianDigitsCompactDate() {
        val s = parse("بانك ملي ايران\nبرداشت:۵۰۰,۰۰۰\nحساب:۰۱۰۱۲۳۴۵۶۷۰۰۸\nمانده:۳,۲۵۰,۰۰۰\n۰۸۱۵-۱۴:۲۳")
        assertEquals(Bank.MELLI, s.bank)
        assertEquals(TxDirection.DEBIT, s.direction)
        assertEquals(500_000L, s.amountRial)
        assertEquals(3_250_000L, s.balanceRial)
        assertEquals("7008", s.accountHint)
        assertTime(s, JalaliDate(1403, 8, 15), 14, 23)
    }

    @Test fun saderatTrailingMinusSign() {
        val s = parse("بانک صادرات ایران\nانتقال از 0212345678001\n1,000,000-\nمانده 5,000,000\n1403/08/15 14:20")
        assertEquals(Bank.SADERAT, s.bank)
        assertEquals(TxDirection.DEBIT, s.direction)
        assertEquals(1_000_000L, s.amountRial)
        assertEquals("8001", s.accountHint)
        assertEquals(TxChannel.TRANSFER, s.channel)
    }

    @Test fun tejaratDepositLeadingPlus() {
        val s = parse("بانک تجارت\nحساب: 123-456-789\n+25,000,000\nمانده: 40,100,000\n1403/08/15 09:00")
        assertEquals(Bank.TEJARAT, s.bank)
        assertEquals(TxDirection.CREDIT, s.direction)
        assertEquals(25_000_000L, s.amountRial)
    }

    @Test fun samanShortYearAndDashedAccount() {
        val s = parse("سامان\nبرداشت از 849-40-1234567-1\nمبلغ 2,500,000\nمانده 10,000,000\n03/08/15 14:23")
        assertEquals(Bank.SAMAN, s.bank)
        assertEquals(TxDirection.DEBIT, s.direction)
        assertEquals(2_500_000L, s.amountRial)
        assertEquals("5671", s.accountHint)
        assertTime(s, JalaliDate(1403, 8, 15), 14, 23)
    }

    @Test fun bluDepositNoLabelBeforeAmount() {
        val s = parse("بلو\nواریز پول\n۵۰۰,۰۰۰ ریال\nمانده: ۲,۳۰۰,۰۰۰ ریال\n۱۴:۰۵ - ۱۴۰۳/۰۸/۱۵")
        assertEquals(Bank.BLU, s.bank)
        assertEquals(TxDirection.CREDIT, s.direction)
        assertEquals(500_000L, s.amountRial)
        assertEquals(2_300_000L, s.balanceRial)
        assertTime(s, JalaliDate(1403, 8, 15), 14, 5)
    }

    @Test fun tomanUnitConvertedToRial() {
        val s = parse("ویپاد\nخرید ۲۵۰,۰۰۰ تومان\nکارت ...۴۴۲۱\nمانده ۱,۲۰۰,۰۰۰ تومان")
        assertEquals(Bank.WEPOD, s.bank)
        assertEquals(2_500_000L, s.amountRial)
        assertEquals(12_000_000L, s.balanceRial)
        assertEquals("4421", s.accountHint)
        assertEquals(TxChannel.PURCHASE, s.channel)
        assertFalse(s.dateFromSms)
        assertEquals(received, s.occurredAtMillis)
    }

    @Test fun pasargadPurchaseMaskedCard() {
        val s = parse("بانک پاسارگاد\nخرید از فروشگاه\nکارت: 5022-29**-****-1234\nمبلغ: 1,850,000 ریال\nموجودی: 7,000,000\n1403/08/15 13:59")
        assertEquals(Bank.PASARGAD, s.bank)
        assertEquals(TxDirection.DEBIT, s.direction)
        assertEquals(1_850_000L, s.amountRial)
        assertEquals("1234", s.accountHint)
        assertEquals(TxChannel.PURCHASE, s.channel)
    }

    @Test fun balanceLabelContainingWithdrawWordDoesNotFlipDirection() {
        val s = parse("بانک سپه\nواریز حقوق\nمبلغ: 150,000,000\nمانده قابل برداشت: 151,000,000\n1403/08/15")
        assertEquals(Bank.SEPAH, s.bank)
        assertEquals(TxDirection.CREDIT, s.direction)
        assertEquals(TxChannel.SALARY, s.channel)
        assertEquals(151_000_000L, s.balanceRial)
    }

    @Test fun keshavarziAndRefahAndMaskan() {
        assertEquals(Bank.KESHAVARZI, parse("بانک کشاورزی\nبرداشت: 300,000\nمانده: 1,000,000").bank)
        assertEquals(Bank.REFAH, parse("بانک رفاه کارگران\nواریز: 300,000\nمانده: 1,000,000").bank)
        assertEquals(Bank.MASKAN, parse("بانک مسکن\nکسر: 300,000\nمانده: 1,000,000").bank)
        assertEquals(Bank.RESALAT, parse("قرض الحسنه رسالت\nبرداشت 300,000\nمانده 1,000,000").bank)
        assertEquals(Bank.PARSIAN, parse("پارسیان\nبرداشت 300,000\nمانده 1,000,000").bank)
    }

    @Test fun negativeBalanceOverdraft() {
        val s = parse("بانک ملت\nبرداشت 2,000,000\nمانده -500,000")
        assertEquals(-500_000L, s.balanceRial)
        assertEquals(TxDirection.DEBIT, s.direction)
    }

    @Test fun senderHintWinsOverText() {
        val r = parser.parse("+98999", "برداشت 2,000,000\nمانده 3,000,000", received, mapOf("+98999" to Bank.SINA))
        assertEquals(Bank.SINA, (r as SmsParseResult.Parsed).sms.bank)
    }

    // ---------------------------------------------------------------- ignored

    @Test fun otpMessagesAreDropped() {
        assertEquals(IgnoreReason.SECURITY_CODE, ignoredReason("بانک ملت\nرمز پویا: 48213977\nمبلغ 1,000,000\nمهلت 2 دقیقه"))
        assertEquals(IgnoreReason.SECURITY_CODE, ignoredReason("رمز یکبار مصرف شما 552190"))
        assertEquals(IgnoreReason.SECURITY_CODE, ignoredReason("کد تأیید: 4471"))
        assertEquals(IgnoreReason.SECURITY_CODE, ignoredReason("بانك سامان\nرمز دوم پويا ۱۲۳۴۵۶"))
        assertEquals(IgnoreReason.SECURITY_CODE, ignoredReason("Your OTP is 993311"))
    }

    @Test fun trackingCodeIsNotMistakenForOtp() {
        val s = parse("بانک ملت\nبرداشت 1,000,000\nکد پیگیری: 123456\nمانده 2,000,000")
        assertEquals(1_000_000L, s.amountRial)
    }

    @Test fun failedAndPromotional() {
        assertEquals(IgnoreReason.FAILED_OPERATION, ignoredReason("بانک ملت\nخرید ناموفق 1,000,000\nموجودی کافی نیست"))
        assertEquals(IgnoreReason.PROMOTIONAL, ignoredReason("۵۰,۰۰۰ تومان تخفیف ویژه برای شما! لغو11"))
        assertEquals(IgnoreReason.NO_AMOUNT, ignoredReason("بانک ملت\nکاربر گرامی، ساعات کاری شعب تغییر کرد"))
        assertEquals(IgnoreReason.NOT_A_BANK_MESSAGE, ignoredReason("سفارش شما به مبلغ 450,000 ریال ثبت شد"))
    }

    @Test fun dateInFutureFallsBackToReceiveTime() {
        val s = parse("بانک ملت\nبرداشت 1,000,000\nمانده 2,000,000\n1403/09/20 10:00")
        assertFalse(s.dateFromSms)
        assertEquals(received, s.occurredAtMillis)
    }

    @Test fun monthDayOnlyInfersPreviousYearAcrossNowruz() {
        val nowruz = JalaliDate.toEpochMillis(JalaliDate(1404, 1, 1), 10, 0)
        val r = parser.parse("x", "بانک ملت\nبرداشت 1,000,000\nمانده 2,000,000\n12/29 23:50", nowruz) as SmsParseResult.Parsed
        assertEquals(JalaliDate.toEpochMillis(JalaliDate(1403, 12, 29), 23, 50), r.sms.occurredAtMillis)
    }

    @Test fun accountNumberIsNeverTheAmount() {
        val s = parse("بانک صادرات\nانتقال از 0212345678001\nمبلغ 700,000\nمانده 900,000")
        assertEquals(700_000L, s.amountRial)
        assertEquals(900_000L, s.balanceRial)
        assertEquals("8001", s.accountHint)
    }
}
