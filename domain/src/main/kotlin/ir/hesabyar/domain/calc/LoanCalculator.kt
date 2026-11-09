package ir.hesabyar.domain.calc

import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode

/**
 * Bank loan installments, both formulas used in Iran:
 *
 *  - NEW (annuity, «فرمول جدید / پلکانی‌نشده»): A = P·i·(1+i)ⁿ / ((1+i)ⁿ − 1), i = rate/12.
 *    What banks apply today; interest is charged on the remaining principal each month.
 *  - OLD («فرمول قدیم»): interest = P × rate × (n + 1) / 2400, installment = (P + interest) / n.
 *    Still quoted by some lenders and shops; it under-states the true cost for long terms.
 */
object LoanCalculator {

    enum class Method { NEW_ANNUITY, OLD_FLAT }

    data class Result(
        val method: Method,
        val installmentRial: Long,
        val totalPaymentRial: Long,
        val principalRial: Long,
    ) {
        val totalInterestRial: Long get() = totalPaymentRial - principalRial
    }

    data class Row(val number: Int, val paymentRial: Long, val interestRial: Long, val principalRial: Long, val remainingRial: Long)

    fun calculate(principalRial: Long, annualRatePercent: BigDecimal, months: Int, method: Method): Result {
        require(principalRial > 0 && months in 1..600 && annualRatePercent.signum() >= 0) { "invalid loan input" }
        val p = BigDecimal(principalRial)
        return when (method) {
            Method.OLD_FLAT -> {
                val interest = p * annualRatePercent * BigDecimal(months + 1) / BigDecimal(2400)
                val installment = (p + interest).divide(BigDecimal(months), 0, RoundingMode.HALF_UP).toLong()
                Result(method, installment, installment * months, principalRial)
            }
            Method.NEW_ANNUITY -> {
                val installment = annuity(p, annualRatePercent, months)
                Result(method, installment, installment * months, principalRial)
            }
        }
    }

    /** Month-by-month split of each annuity payment into interest and principal. */
    fun schedule(principalRial: Long, annualRatePercent: BigDecimal, months: Int): List<Row> {
        val i = monthlyRate(annualRatePercent)
        val payment = annuity(BigDecimal(principalRial), annualRatePercent, months)
        var remaining = principalRial
        return (1..months).map { n ->
            val interest = (BigDecimal(remaining) * i).setScale(0, RoundingMode.HALF_UP).toLong()
            val pay = if (n == months) remaining + interest else payment
            val principalPart = pay - interest
            remaining -= principalPart
            Row(n, pay, interest, principalPart, remaining)
        }
    }

    private fun monthlyRate(annualPercent: BigDecimal) = annualPercent.divide(BigDecimal(1200), MathContext.DECIMAL128)

    private fun annuity(p: BigDecimal, annualPercent: BigDecimal, n: Int): Long {
        val i = monthlyRate(annualPercent)
        if (i.signum() == 0) return p.divide(BigDecimal(n), 0, RoundingMode.HALF_UP).toLong()
        val f = (BigDecimal.ONE + i).pow(n, MathContext.DECIMAL128)
        return (p * i * f).divide(f - BigDecimal.ONE, 0, RoundingMode.HALF_UP).toLong()
    }
}
