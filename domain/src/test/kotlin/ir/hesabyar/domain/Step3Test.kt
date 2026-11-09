package ir.hesabyar.domain

import ir.hesabyar.domain.calc.GoldCalculator
import ir.hesabyar.domain.calc.GoldCalculator.Wage
import ir.hesabyar.domain.calc.LoanCalculator
import ir.hesabyar.domain.calc.LoanCalculator.Method
import ir.hesabyar.domain.rates.RateSanity
import ir.hesabyar.domain.savings.InflationShield
import ir.hesabyar.domain.savings.InflationShield.Deposit
import ir.hesabyar.domain.text.PersianText
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

class Step3Test {

    private fun bd(s: String) = BigDecimal(s)

    // ------------------------------------------------------------ gold
    @Test fun goldGuildFormula() {
        // 10 g × 7,000,000 Toman/g, wage 15%, profit 7%, VAT 9% on (wage + profit)
        val q = GoldCalculator.quote(GoldCalculator.Input(bd("10"), 70_000_000, Wage.Percent(bd("15")), bd("7"), bd("9")))
        assertEquals(700_000_000L, q.goldValueRial)
        assertEquals(105_000_000L, q.wageRial)
        assertEquals(56_350_000L, q.profitRial)
        assertEquals(14_521_500L, q.taxRial)
        assertEquals(875_871_500L, q.totalRial)
    }

    @Test fun goldProfitCappedAtSevenPercentAndVatNotOnGold() {
        val capped = GoldCalculator.quote(GoldCalculator.Input(bd("1"), 10_000_000, Wage.Percent(BigDecimal.ZERO), bd("12"), bd("9")))
        assertEquals(bd("7"), capped.profitPercentApplied)
        assertEquals(700_000L, capped.profitRial)
        assertEquals(63_000L, capped.taxRial) // 9% of profit only — the gold itself is VAT-free
        val fixed = GoldCalculator.quote(GoldCalculator.Input(bd("2.5"), 10_000_000, Wage.Fixed(3_000_000), BigDecimal.ZERO, BigDecimal.ZERO))
        assertEquals(28_000_000L, fixed.totalRial)
        val perGram = GoldCalculator.quote(GoldCalculator.Input(bd("2"), 10_000_000, Wage.PerGram(500_000), BigDecimal.ZERO, BigDecimal.ZERO))
        assertEquals(1_000_000L, perGram.wageRial)
    }

    @Test fun goldBudgetInverse() {
        assertEquals(bd("10.000"), GoldCalculator.gramsForBudget(875_871_500, 70_000_000, bd("15"), bd("7"), bd("9")))
        assertEquals(68_000_000L, GoldCalculator.buyBackValueRial(bd("1"), 70_000_000, bd("2.857142857")).let { (it / 1000) * 1000 })
    }

    // ------------------------------------------------------------ loans
    @Test fun loanOldFormula() {
        val r = LoanCalculator.calculate(1_000_000_000, bd("18"), 36, Method.OLD_FLAT)
        assertEquals(35_486_111L, r.installmentRial)       // (P + P·18·37/2400) / 36
        assertEquals(277_499_996L, r.totalInterestRial)    // rounding of the installment
    }

    @Test fun loanNewAnnuityFormulaAndSchedule() {
        val r = LoanCalculator.calculate(1_000_000_000, bd("18"), 36, Method.NEW_ANNUITY)
        assertTrue("installment ${r.installmentRial}", r.installmentRial in 36_152_000L..36_153_000L)
        val rows = LoanCalculator.schedule(1_000_000_000, bd("18"), 36)
        assertEquals(36, rows.size)
        assertEquals(15_000_000L, rows[0].interestRial)     // 1.5% of 1e9
        assertEquals(0L, rows.last().remainingRial)
        assertEquals(1_000_000_000L, rows.sumOf { it.principalRial })
        // The old formula under-states cost on long loans.
        assertTrue(LoanCalculator.calculate(1_000_000_000, bd("23"), 60, Method.OLD_FLAT).installmentRial <
            LoanCalculator.calculate(1_000_000_000, bd("23"), 60, Method.NEW_ANNUITY).installmentRial)
    }

    @Test fun zeroInterestLoan() {
        assertEquals(10_000_000L, LoanCalculator.calculate(120_000_000, BigDecimal.ZERO, 12, Method.NEW_ANNUITY).installmentRial)
    }

    // ------------------------------------------------------------ inflation shield
    @Test fun shieldReport() {
        // Goal: 10 g. Bought 2 g at 5,000,000 T/g then 1 g at 6,000,000 T/g. Gold is now 7,000,000 T/g.
        val deposits = listOf(Deposit(100_000_000, 50_000_000, 1), Deposit(60_000_000, 60_000_000, 2))
        val r = InflationShield.report(10_000, deposits, currentPriceRial = 70_000_000, todayEpochDay = 0, deadlineEpochDay = 213)
        assertEquals(3_000L, r.ownedMilli)
        assertEquals(160_000_000L, r.totalDepositedRial)
        assertEquals(210_000_000L, r.currentValueRial)
        assertEquals(50_000_000L, r.inflationGainRial)
        assertEquals(2_285L, r.cashEquivalentMilli)          // 16,000,000 T of cash buys only 2.285 g today
        assertEquals(715L, r.unitsSavedMilli)
        assertEquals(490_000_000L, r.remainingRialAtCurrentPrice)
        assertEquals(70_000_000L, r.monthlyNeededRial)       // 7 months left
        assertEquals(0.3f, r.progress, 0.0001f)
        assertFalse(r.reached)

        val curve = InflationShield.curve(deposits, 70_000_000)
        assertEquals(listOf(2_000L, 3_000L), curve.map { it.ownedMilli })
        assertEquals(listOf(1_428L, 2_285L), curve.map { it.cashEquivalentMilli })
    }

    // ------------------------------------------------------------ rates & parsing
    @Test fun rateSanity() {
        assertEquals(RateSanity.Verdict.INVALID, RateSanity.check(0, 100))
        assertEquals(RateSanity.Verdict.SUSPICIOUS_JUMP, RateSanity.check(1_000, 100)) // Toman/Rial mix-up
        assertEquals(RateSanity.Verdict.OK, RateSanity.check(105, 100))
        assertEquals(RateSanity.Verdict.INVALID, RateSanity.check(5, null, RateSanity.Bounds(10, 1_000)))
        assertTrue(RateSanity.isStale(0, 7 * 3_600_000L))
    }

    @Test fun decimals() {
        assertEquals(bd("2.5"), PersianText.parseDecimal("۲٫۵"))
        assertEquals(bd("0.75"), PersianText.parseDecimal(".75"))
        assertEquals(bd("12"), PersianText.parseDecimal("۱۲"))
        assertNull(PersianText.parseDecimal("1.2.3"))
        assertNull(PersianText.parseDecimal("abc"))
    }
}
