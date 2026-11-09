package ir.hesabyar.domain.savings

import kotlin.math.ceil

/**
 * «سپر ضدتورم»: savings goals denominated in a real asset (grams of 18k gold, USD, USDT) instead
 * of Toman. Every Toman deposit is converted at that day's price, so progress is measured in
 * purchasing power, and the report shows what holding the asset saved versus holding cash.
 *
 * Units are milli-units (1 gram = 1000) in Long: exact, no Double drift.
 */
object InflationShield {

    data class Deposit(val amountRial: Long, val unitPriceRial: Long, val atMillis: Long)

    data class Report(
        val targetMilli: Long,
        val ownedMilli: Long,
        val totalDepositedRial: Long,
        val currentValueRial: Long,
        /** Units the same Toman would buy *today* if it had been kept as cash. */
        val cashEquivalentMilli: Long,
        val remainingRialAtCurrentPrice: Long,
        val monthlyNeededRial: Long?,
    ) {
        val progress: Float get() = if (targetMilli <= 0) 0f else (ownedMilli.toFloat() / targetMilli).coerceIn(0f, 1f)
        /** Positive = the shield worked: the asset outgrew cash. */
        val inflationGainRial: Long get() = currentValueRial - totalDepositedRial
        val inflationGainPercent: Double get() = if (totalDepositedRial == 0L) 0.0 else inflationGainRial * 100.0 / totalDepositedRial
        val unitsSavedMilli: Long get() = ownedMilli - cashEquivalentMilli
        val reached: Boolean get() = ownedMilli >= targetMilli
    }

    /** Point i of the comparison chart: after deposit i, owned units vs. what the cash would buy today. */
    data class CurvePoint(val index: Int, val atMillis: Long, val ownedMilli: Long, val cashEquivalentMilli: Long)

    fun milliUnitsFor(amountRial: Long, unitPriceRial: Long): Long {
        require(unitPriceRial > 0) { "price must be positive" }
        return Math.multiplyExact(amountRial, 1000L) / unitPriceRial
    }

    fun report(
        targetMilli: Long,
        deposits: List<Deposit>,
        currentPriceRial: Long,
        todayEpochDay: Long? = null,
        deadlineEpochDay: Long? = null,
    ): Report {
        val owned = deposits.sumOf { milliUnitsFor(it.amountRial, it.unitPriceRial) }
        val deposited = deposits.sumOf { it.amountRial }
        val value = if (currentPriceRial > 0) owned * currentPriceRial / 1000 else 0
        val cashEq = if (currentPriceRial > 0) milliUnitsFor(deposited, currentPriceRial) else 0
        val remainingMilli = (targetMilli - owned).coerceAtLeast(0)
        val remainingRial = remainingMilli * currentPriceRial / 1000
        val monthly = if (deadlineEpochDay != null && todayEpochDay != null && remainingRial > 0) {
            val months = ceil((deadlineEpochDay - todayEpochDay).coerceAtLeast(1) / 30.44).toLong().coerceAtLeast(1)
            ceil(remainingRial.toDouble() / months).toLong()
        } else null
        return Report(targetMilli, owned, deposited, value, cashEq, remainingRial, monthly)
    }

    fun curve(deposits: List<Deposit>, currentPriceRial: Long): List<CurvePoint> {
        var owned = 0L
        var deposited = 0L
        return deposits.sortedBy { it.atMillis }.mapIndexed { i, d ->
            owned += milliUnitsFor(d.amountRial, d.unitPriceRial)
            deposited += d.amountRial
            CurvePoint(i, d.atMillis, owned, if (currentPriceRial > 0) milliUnitsFor(deposited, currentPriceRial) else 0)
        }
    }
}
