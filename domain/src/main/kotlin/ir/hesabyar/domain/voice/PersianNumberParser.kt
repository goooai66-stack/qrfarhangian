package ir.hesabyar.domain.voice

import ir.hesabyar.domain.text.PersianText
import java.math.BigDecimal
import java.math.RoundingMode

/**
 * Spoken / written Persian numbers → value.
 *
 * «پانصد هزار» = 500,000 · «دو میلیون و سیصد هزار» = 2,300,000 · «یک و نیم میلیون» = 1,500,000
 * «بیست و پنج هزار و پونصد» = 25,500 · «۲.۵ میلیون» = 2,500,000 · «500 هزار» = 500,000
 * Colloquial forms that speech recognizers emit (پونصد، شیش، یه، ملیون) are included.
 */
object PersianNumberParser {

    private val small: Map<String, Int> = buildMap {
        put("صفر", 0); put("یک", 1); put("یه", 1); put("دو", 2); put("سه", 3); put("چهار", 4); put("چار", 4)
        put("پنج", 5); put("شش", 6); put("شیش", 6); put("هفت", 7); put("هشت", 8); put("نه", 9)
        put("ده", 10); put("یازده", 11); put("دوازده", 12); put("سیزده", 13); put("چهارده", 14)
        put("پانزده", 15); put("پونزده", 15); put("شانزده", 16); put("شونزده", 16); put("هفده", 17)
        put("هجده", 18); put("هیجده", 18); put("نوزده", 19)
        put("بیست", 20); put("سی", 30); put("چهل", 40); put("پنجاه", 50); put("شصت", 60)
        put("هفتاد", 70); put("هشتاد", 80); put("نود", 90)
        put("صد", 100); put("یکصد", 100); put("دویست", 200); put("سیصد", 300); put("چهارصد", 400)
        put("پانصد", 500); put("پونصد", 500); put("ششصد", 600); put("شیشصد", 600); put("هفتصد", 700)
        put("هشتصد", 800); put("نهصد", 900)
    }

    private val multipliers: Map<String, Long> = mapOf(
        "هزار" to 1_000L,
        "میلیون" to 1_000_000L, "ملیون" to 1_000_000L, "میلیونی" to 1_000_000L,
        "میلیارد" to 1_000_000_000L, "ملیارد" to 1_000_000_000L,
    )

    private val digitToken = Regex("""^\d{1,3}(,\d{3})+$|^\d+([.]\d+)?$""")

    data class Span(val startToken: Int, val endToken: Int, val value: BigDecimal)

    fun tokenize(text: String): List<String> =
        PersianText.normalize(text).lowercase()
            .replace(Regex("""[^\p{L}\d.,]+"""), " ")
            .split(' ')
            .filter { it.isNotBlank() }
            .flatMap { splitGluedConjunction(it) }

    /** «وپنج» → «و», «پنج»; «بیست‌وپنج» arrives as «بیست وپنج» after ZWNJ normalization. */
    private fun splitGluedConjunction(t: String): List<String> =
        if (t.length > 1 && t.startsWith("و") && isNumberWord(t.substring(1))) listOf("و", t.substring(1)) else listOf(t)

    private fun isNumberWord(t: String) = t in small || t in multipliers || t == "نیم" || digitToken.matches(t.trimEnd(',', '.'))

    /** All number phrases in order of appearance. */
    fun spans(tokens: List<String>): List<Span> {
        val out = mutableListOf<Span>()
        var i = 0
        while (i < tokens.size) {
            if (!isNumberWord(tokens[i])) { i++; continue }
            var j = i
            val run = mutableListOf<String>()
            while (j < tokens.size) {
                val t = tokens[j]
                if (isNumberWord(t)) { run += t; j++ }
                else if (t == "و" && j + 1 < tokens.size && isNumberWord(tokens[j + 1]) && run.isNotEmpty()) j++
                else break
            }
            evaluate(run)?.let { out += Span(i, j, it) }
            i = j
        }
        return out
    }

    private fun evaluate(run: List<String>): BigDecimal? {
        var total = BigDecimal.ZERO
        var current = BigDecimal.ZERO
        var any = false
        for (raw in run) {
            val t = raw.trimEnd(',', '.')
            when {
                digitToken.matches(t) -> { current += BigDecimal(t.replace(",", "")); any = true }
                t == "نیم" -> { current += BigDecimal("0.5"); any = true }
                t == "صد" && current > BigDecimal.ZERO && current < BigDecimal.TEN -> { current *= BigDecimal(100); any = true }
                t in small -> { current += BigDecimal(small.getValue(t)); any = true }
                t in multipliers -> {
                    if (current.signum() == 0) current = BigDecimal.ONE
                    total += current * BigDecimal(multipliers.getValue(t))
                    current = BigDecimal.ZERO
                    any = true
                }
            }
        }
        return if (any) total + current else null
    }

    /** Largest number phrase in [text] (the amount is almost always the biggest number said). */
    fun parseLargest(text: String): Long? =
        spans(tokenize(text)).maxByOrNull { it.value }?.value?.setScale(0, RoundingMode.HALF_UP)?.toLong()
}
