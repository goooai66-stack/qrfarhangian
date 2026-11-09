package ir.hesabyar.domain.calc

import java.math.BigDecimal
import java.math.RoundingMode

/**
 * State machine + evaluator behind the built-in calculator keyboard.
 *
 * The user types in Toman: `250000+18000×2` → 286,000. Standard precedence (× ÷ before + −),
 * exact decimal arithmetic, result rounded half-up to a whole Toman. A trailing operator is
 * ignored so the live preview never flickers to an error while typing.
 */
class AmountExpression private constructor(val raw: String) {

    enum class Op(val symbol: Char) { PLUS('+'), MINUS('−'), TIMES('×'), DIVIDE('÷') }

    val isEmpty: Boolean get() = raw.isEmpty()
    val hasOperator: Boolean get() = raw.any { it.isOperator() }

    fun appendDigit(d: Char): AmountExpression {
        require(d in '0'..'9')
        val current = lastNumber()
        if (current == "0") return AmountExpression(raw.dropLast(1) + d) // no leading zeros
        if (current.length >= MAX_DIGITS) return this
        return AmountExpression(raw + d)
    }

    /** The «000» key. */
    fun appendTripleZero(): AmountExpression {
        val current = lastNumber()
        if (current.isEmpty() || current == "0") return this
        if (current.length + 3 > MAX_DIGITS) return this
        return AmountExpression("${raw}000")
    }

    fun appendOperator(op: Op): AmountExpression = when {
        raw.isEmpty() -> this
        raw.last().isOperator() -> AmountExpression(raw.dropLast(1) + op.symbol)
        else -> AmountExpression(raw + op.symbol)
    }

    fun backspace(): AmountExpression = AmountExpression(raw.dropLast(1))
    fun clear(): AmountExpression = EMPTY

    /** «=» : collapses the expression into its result. */
    fun collapse(): AmountExpression {
        val v = evaluate() ?: return this
        return if (v <= 0) EMPTY else AmountExpression(v.toString())
    }

    /** Result in Toman, or null for an empty / invalid (e.g. ÷0) expression. */
    fun evaluate(): Long? {
        val expr = raw.trimEnd { it.isOperator() }
        if (expr.isEmpty()) return null
        val numbers = mutableListOf<BigDecimal>()
        val ops = mutableListOf<Char>()
        val sb = StringBuilder()
        for (c in expr) {
            if (c.isOperator()) {
                if (sb.isEmpty()) return null
                numbers += BigDecimal(sb.toString()); sb.clear(); ops += c
            } else sb.append(c)
        }
        if (sb.isEmpty()) return null
        numbers += BigDecimal(sb.toString())

        // Pass 1: × and ÷
        val n2 = mutableListOf(numbers[0])
        val o2 = mutableListOf<Char>()
        for (i in ops.indices) {
            val rhs = numbers[i + 1]
            when (ops[i]) {
                '×' -> n2[n2.lastIndex] = n2.last().multiply(rhs)
                '÷' -> {
                    if (rhs.signum() == 0) return null
                    n2[n2.lastIndex] = n2.last().divide(rhs, 6, RoundingMode.HALF_UP)
                }
                else -> { o2 += ops[i]; n2 += rhs }
            }
        }
        // Pass 2: + and −
        var acc = n2[0]
        for (i in o2.indices) acc = if (o2[i] == '+') acc.add(n2[i + 1]) else acc.subtract(n2[i + 1])
        val rounded = acc.setScale(0, RoundingMode.HALF_UP)
        if (rounded.abs() > BigDecimal(MAX_RESULT)) return null
        return rounded.toLong()
    }

    private fun lastNumber(): String = raw.takeLastWhile { it.isDigit() }
    private fun Char.isOperator() = this == '+' || this == '−' || this == '×' || this == '÷'

    override fun toString() = raw

    companion object {
        private const val MAX_DIGITS = 13
        private const val MAX_RESULT = 999_999_999_999_999L
        val EMPTY = AmountExpression("")
        fun of(raw: String) = AmountExpression(raw)
        fun ofValue(toman: Long) = if (toman <= 0) EMPTY else AmountExpression(toman.toString())
    }
}
