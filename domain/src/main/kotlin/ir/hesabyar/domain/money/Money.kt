package ir.hesabyar.domain.money

import ir.hesabyar.domain.text.PersianText
import kotlin.math.abs

/**
 * All money is stored as [Long] **Rial** (the unit banks report), never as floating point.
 * The UI shows Toman (= Rial / 10). Keeping Rial in storage means an SMS amount such as
 * 1,234,565 Rial is never rounded away.
 */
object Money {

    fun rialToToman(rial: Long): Long = rial / 10
    fun tomanToRial(toman: Long): Long = Math.multiplyExact(toman, 10L)

    /** 1250000 → "1,250,000" */
    fun group(value: Long): String {
        val digits = abs(value).toString()
        val sb = StringBuilder()
        val firstGroup = digits.length % 3
        digits.forEachIndexed { i, c ->
            if (i > 0 && (i - firstGroup) % 3 == 0) sb.append(',')
            sb.append(c)
        }
        return if (value < 0) "-$sb" else sb.toString()
    }

    /** 12_500_000 Rial → "۱,۲۵۰,۰۰۰" (Toman, Persian digits). */
    fun formatToman(rial: Long, persianDigits: Boolean = true): String {
        val s = group(rialToToman(rial))
        return if (persianDigits) PersianText.toPersianDigits(s) else s
    }

    /** Same as [formatToman] with the unit suffix: "۱,۲۵۰,۰۰۰ تومان". */
    fun formatTomanWithUnit(rial: Long): String = formatToman(rial) + " تومان"

    /** Signed display used in lists: "+۵۰۰,۰۰۰" / "−۲۵,۰۰۰". */
    fun formatSignedToman(deltaRial: Long): String {
        val body = formatToman(abs(deltaRial))
        return when {
            deltaRial > 0 -> "+$body"
            deltaRial < 0 -> "−$body"
            else -> body
        }
    }

    /** Parses "1,250,000" / "۱٬۲۵۰٬۰۰۰" / "1250000" into a Long, or null. */
    fun parseGrouped(text: String): Long? {
        val clean = PersianText.toLatinDigits(text).replace(Regex("[,٬،\\s]"), "")
        if (clean.isEmpty() || clean.length > 18 || !clean.all { it.isDigit() }) return null
        return clean.toLongOrNull()
    }
}
