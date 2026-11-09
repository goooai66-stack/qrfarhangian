package ir.hesabyar.domain.split

/**
 * «دنگ»: splits a bill by weights (1 = one share; a couple can be 2). Shares are rounded down
 * to [roundingRial] and the remainder goes to the payer, so the shares always sum exactly to the
 * total and nobody is asked for odd amounts like ۳۳,۳۳۳.۳ تومان.
 */
object SplitCalculator {

    data class Participant(val key: String, val weight: Int = 1)
    data class Share(val key: String, val amountRial: Long)

    fun split(totalRial: Long, participants: List<Participant>, payerKey: String, roundingRial: Long = 10_000): List<Share> {
        require(totalRial > 0) { "total must be positive" }
        require(participants.isNotEmpty()) { "no participants" }
        require(participants.all { it.weight > 0 }) { "weights must be positive" }
        require(participants.map { it.key }.toSet().size == participants.size) { "duplicate participant" }
        require(roundingRial > 0)

        val totalWeight = participants.sumOf { it.weight.toLong() }
        val raw = participants.map { p ->
            val exact = totalRial * p.weight / totalWeight
            Share(p.key, exact - exact % roundingRial)
        }
        val remainder = totalRial - raw.sumOf { it.amountRial }
        val payerIndex = participants.indexOfFirst { it.key == payerKey }.takeIf { it >= 0 } ?: 0
        return raw.mapIndexed { i, s -> if (i == payerIndex) s.copy(amountRial = s.amountRial + remainder) else s }
    }
}
