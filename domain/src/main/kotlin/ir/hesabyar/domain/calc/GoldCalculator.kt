package ir.hesabyar.domain.calc

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode

/**
 * Iranian retail gold price («فاکتور طلافروشی»), the guild formula:
 *
 *   gold   = weight × price-per-gram (18k)
 *   wage   = gold × wage%                 (or a fixed amount / per-gram amount)
 *   profit = (gold + wage) × profit%      (seller profit, capped at 7%)
 *   tax    = (wage + profit) × VAT%       (VAT is charged on wage + profit only, never on the gold)
 *   total  = gold + wage + profit + tax
 */
object GoldCalculator {

    val MAX_PROFIT_PERCENT: BigDecimal = BigDecimal(7)
    val DEFAULT_VAT_PERCENT: BigDecimal = BigDecimal(9)

    sealed interface Wage {
        data class Percent(val percent: BigDecimal) : Wage
        /** Total wage for the piece, in Rial. */
        data class Fixed(val rial: Long) : Wage
        /** Wage per gram, in Rial (common for coins and bullion-like items). */
        data class PerGram(val rialPerGram: Long) : Wage
    }

    data class Input(
        val weightGrams: BigDecimal,
        val pricePerGramRial: Long,
        val wage: Wage,
        val profitPercent: BigDecimal = MAX_PROFIT_PERCENT,
        val vatPercent: BigDecimal = DEFAULT_VAT_PERCENT,
        val enforceProfitCap: Boolean = true,
    )

    data class Quote(
        val goldValueRial: Long,
        val wageRial: Long,
        val profitRial: Long,
        val taxRial: Long,
        val profitPercentApplied: BigDecimal,
    ) {
        val totalRial: Long get() = goldValueRial + wageRial + profitRial + taxRial
        /** Effective price of one gram including everything — handy for comparing two shops. */
        fun effectivePerGramRial(weight: BigDecimal): Long =
            if (weight.signum() == 0) 0 else BigDecimal(totalRial).divide(weight, 0, RoundingMode.HALF_UP).toLong()
    }

    fun quote(input: Input): Quote {
        require(input.weightGrams.signum() >= 0 && input.pricePerGramRial >= 0) { "negative input" }
        val profitPct = if (input.enforceProfitCap) input.profitPercent.min(MAX_PROFIT_PERCENT) else input.profitPercent
        val gold = input.weightGrams * BigDecimal(input.pricePerGramRial)
        val wage = when (val w = input.wage) {
            is Wage.Percent -> gold * pct(w.percent)
            is Wage.Fixed -> BigDecimal(w.rial)
            is Wage.PerGram -> input.weightGrams * BigDecimal(w.rialPerGram)
        }
        val profit = (gold + wage) * pct(profitPct.max(BigDecimal.ZERO))
        val tax = (wage + profit) * pct(input.vatPercent.max(BigDecimal.ZERO))
        return Quote(r(gold), r(wage), r(profit), r(tax), profitPct)
    }

    /** «با این بودجه چند گرم؟» — inverse of [quote] for a percentage wage. Grams to 3 decimals (milligram). */
    fun gramsForBudget(budgetRial: Long, pricePerGramRial: Long, wagePercent: BigDecimal, profitPercent: BigDecimal = MAX_PROFIT_PERCENT, vatPercent: BigDecimal = DEFAULT_VAT_PERCENT): BigDecimal {
        if (pricePerGramRial <= 0 || budgetRial <= 0) return BigDecimal.ZERO
        val w = pct(wagePercent)
        val p = pct(profitPercent.min(MAX_PROFIT_PERCENT))
        val v = pct(vatPercent)
        val wagePlusProfit = w + (BigDecimal.ONE + w) * p
        val factor = BigDecimal.ONE + wagePlusProfit + wagePlusProfit * v
        return BigDecimal(budgetRial).divide(BigDecimal(pricePerGramRial) * factor, MathContext.DECIMAL64).setScale(3, RoundingMode.DOWN)
    }

    /** What a gold shop pays when buying back (no wage/profit refunded), minus an optional deduction. */
    fun buyBackValueRial(weightGrams: BigDecimal, pricePerGramRial: Long, deductionPercent: BigDecimal = BigDecimal.ZERO): Long =
        r(weightGrams * BigDecimal(pricePerGramRial) * (BigDecimal.ONE - pct(deductionPercent)))

    private fun pct(p: BigDecimal) = p.divide(BigDecimal(100), MathContext.DECIMAL64)
    private fun r(v: BigDecimal) = v.setScale(0, RoundingMode.HALF_UP).toLong()
}
