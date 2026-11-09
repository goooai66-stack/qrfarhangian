package ir.hesabyar.domain

import ir.hesabyar.domain.ads.AdFormat
import ir.hesabyar.domain.ads.AdPolicy
import ir.hesabyar.domain.ads.AppSurface
import ir.hesabyar.domain.ads.Entitlements
import ir.hesabyar.domain.ads.RewardedFeature
import ir.hesabyar.domain.calc.AmountExpression
import ir.hesabyar.domain.ledger.LedgerEntry
import ir.hesabyar.domain.ledger.LedgerMath
import ir.hesabyar.domain.ledger.TransactionType
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.rates.Coin
import ir.hesabyar.domain.rates.CoinMath
import ir.hesabyar.domain.sms.SelfTransferDetector
import ir.hesabyar.domain.sms.SelfTransferDetector.Candidate
import ir.hesabyar.domain.sms.TxDirection
import ir.hesabyar.domain.text.PersianText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class EngineTest {

    // ------------------------------------------------------------ money & text
    @Test fun formatting() {
        assertEquals("۱,۲۵۰,۰۰۰", Money.formatToman(12_500_000))
        assertEquals("0", Money.group(0))
        assertEquals("-1,000", Money.group(-1000))
        assertEquals(1_250_000L, Money.parseGrouped("۱٬۲۵۰٬۰۰۰"))
        assertEquals("بانک ملی 123", PersianText.normalize("بانك  ملي‏ ۱۲۳"))
    }

    // ------------------------------------------------------------ self transfer
    private val t0 = 1_700_000_000_000L
    private val detector = SelfTransferDetector()

    @Test fun pairsDebitAndCreditWithinTwoMinutes() {
        val debit = Candidate(1, accountId = 10, direction = TxDirection.DEBIT, amountRial = 5_000_000, occurredAtMillis = t0)
        val credit = Candidate(2, accountId = 20, direction = TxDirection.CREDIT, amountRial = 5_000_000, occurredAtMillis = t0 + 90_000)
        val unrelated = Candidate(3, accountId = 20, direction = TxDirection.CREDIT, amountRial = 4_999_000, occurredAtMillis = t0 + 10_000)
        assertEquals(2L, detector.findCounterpart(debit, listOf(unrelated, credit))?.id)
        assertEquals(1L, detector.findCounterpart(credit, listOf(debit))?.id) // either order
    }

    @Test fun noPairWhenSameAccountOrTooLateOrUnknownAccount() {
        val debit = Candidate(1, 10, TxDirection.DEBIT, 5_000_000, t0)
        assertNull(detector.findCounterpart(debit, listOf(Candidate(2, 10, TxDirection.CREDIT, 5_000_000, t0 + 5_000))))
        assertNull(detector.findCounterpart(debit, listOf(Candidate(2, 20, TxDirection.CREDIT, 5_000_000, t0 + 121_000))))
        assertNull(detector.findCounterpart(debit, listOf(Candidate(2, null, TxDirection.CREDIT, 5_000_000, t0 + 1_000))))
        assertNull(detector.findCounterpart(debit, listOf(Candidate(2, 20, TxDirection.CREDIT, 5_000_000, t0 + 1_000, alreadyResolved = true))))
    }

    // ------------------------------------------------------------ chronological balance
    @Test fun backdatedTransactionRecomputesLaterBalances() {
        val day = 86_400_000L
        val entries = mutableListOf(
            LedgerEntry(1, t0, TransactionType.INCOME, 10_000_000),
            LedgerEntry(2, t0 + 2 * day, TransactionType.EXPENSE, 1_000_000),
        )
        // Inserted later (id 3) but happened between 1 and 2.
        entries += LedgerEntry(3, t0 + day, TransactionType.EXPENSE, 4_000_000)
        val balances = LedgerMath.runningBalances(0, entries)
        assertEquals(listOf(1L, 3L, 2L), balances.keys.toList())
        assertEquals(10_000_000L, balances[1])
        assertEquals(6_000_000L, balances[3])
        assertEquals(5_000_000L, balances[2])
    }

    @Test fun transfersExcludedFromTotals() {
        val e = listOf(
            LedgerEntry(1, t0, TransactionType.INCOME, 100),
            LedgerEntry(2, t0, TransactionType.EXPENSE, 30),
            LedgerEntry(3, t0, TransactionType.TRANSFER_OUT, 50),
        )
        assertEquals(LedgerMath.PeriodTotals(100, 30), LedgerMath.totals(e))
        assertEquals(20L, LedgerMath.finalBalance(0, e))
    }

    // ------------------------------------------------------------ calculator keyboard
    @Test fun calculatorPrecedenceAndTripleZero() {
        var e = AmountExpression.EMPTY
        "250".forEach { e = e.appendDigit(it) }
        e = e.appendTripleZero().appendOperator(AmountExpression.Op.PLUS)
        "18".forEach { e = e.appendDigit(it) }
        e = e.appendTripleZero().appendOperator(AmountExpression.Op.TIMES).appendDigit('2')
        assertEquals("250000+18000×2", e.raw)
        assertEquals(286_000L, e.evaluate())
        assertEquals(286_000L, e.collapse().evaluate())
    }

    @Test fun calculatorEdgeCases() {
        assertNull(AmountExpression.of("100÷0").evaluate())
        assertEquals(100L, AmountExpression.of("100+").evaluate())              // trailing operator ignored
        assertEquals("5+", AmountExpression.of("5×").appendOperator(AmountExpression.Op.PLUS).raw) // operator replaced
        assertEquals(33L, AmountExpression.of("100÷3").evaluate())
        assertEquals("7", AmountExpression.of("0").appendDigit('7').raw)
        assertEquals("", AmountExpression.EMPTY.appendTripleZero().raw)
    }

    // ------------------------------------------------------------ ad policy
    @Test fun adFreeZonesAreAbsolute() {
        for (f in AdFormat.entries) {
            assertFalse(AdPolicy.isAllowed(AppSurface.APP_START, f, userInitiated = true))
            assertFalse(AdPolicy.isAllowed(AppSurface.TRANSACTION_FORM, f, userInitiated = true))
            assertFalse(AdPolicy.isAllowed(AppSurface.SMS_CONFIRMATION, f, userInitiated = true))
            assertFalse(AdPolicy.isAllowed(AppSurface.DUE_REMINDER_ALERT, f, userInitiated = true))
        }
        for (s in AppSurface.entries) assertFalse(AdPolicy.isAllowed(s, AdFormat.INTERSTITIAL, true))
        assertFalse(AdPolicy.isAllowed(AppSurface.DASHBOARD, AdFormat.BANNER))
        assertFalse(AdPolicy.isAllowed(AppSurface.DASHBOARD, AdFormat.NATIVE))
        assertFalse(AdPolicy.isAllowed(AppSurface.DASHBOARD, AdFormat.REWARDED, userInitiated = false))
        assertTrue(AdPolicy.isAllowed(AppSurface.DASHBOARD, AdFormat.REWARDED, userInitiated = true))
        assertTrue(AdPolicy.isAllowed(AppSurface.TRANSACTIONS_LIST, AdFormat.NATIVE))
        assertTrue(AdPolicy.isAllowed(AppSurface.REPORTS, AdFormat.BANNER))
    }

    @Test fun nativeAdAfterEveryTenRows() {
        val out = AdPolicy.interleave((1..25).toList(), 10, { "r$it" }, { "AD$it" })
        assertEquals(27, out.size)
        assertEquals("AD0", out[10])
        assertEquals("AD1", out[21])
        assertEquals(10, AdPolicy.interleave((1..10).toList(), 10, { it }, { -1 }).size) // no trailing ad
    }

    @Test fun rewardedEntitlements() {
        var e = Entitlements()
        assertFalse(e.isActive(RewardedFeature.VOICE_ASSISTANT, t0))
        e = e.grant(RewardedFeature.VOICE_ASSISTANT, t0)
        assertTrue(e.isActive(RewardedFeature.VOICE_ASSISTANT, t0 + 23 * 3_600_000L))
        assertFalse(e.isActive(RewardedFeature.VOICE_ASSISTANT, t0 + 25 * 3_600_000L))
        e = e.grant(RewardedFeature.EXPORT_EXCEL_PDF, t0)
        e = e.consume(RewardedFeature.EXPORT_EXCEL_PDF)!!
        assertNull(e.consume(RewardedFeature.EXPORT_EXCEL_PDF))
        assertEquals(3, e.grant(RewardedFeature.EXTRA_LEDGER, t0).ledgerQuota())
    }

    @Test fun coinBubble() {
        val gold18 = 70_000_000L // 7,000,000 Toman per gram
        val intrinsic = CoinMath.intrinsicValueRial(Coin.EMAMI, gold18)
        assertEquals(683_172_000L, intrinsic)
        assertEquals(116_828_000L, CoinMath.bubbleRial(Coin.EMAMI, 800_000_000L, gold18))
    }
}
