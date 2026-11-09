package ir.hesabyar.domain.calendar

import java.util.Calendar
import java.util.TimeZone

/**
 * Solar Hijri (Jalali) date.
 *
 * Conversion uses the Borkowski / jalaali-js algorithm: the 33-year arithmetic cycle corrected
 * by the table of astronomical "break" years. It matches the official Iranian calendar for
 * years -61 … 3177 — unlike the naive `year % 33` rule used by many apps, which is wrong for
 * years such as 1403 (leap) vs 1404.
 */
data class JalaliDate(val year: Int, val month: Int, val day: Int) : Comparable<JalaliDate> {

    init {
        require(month in 1..12) { "month out of range: $month" }
        require(day in 1..monthLength(year, month)) { "day out of range: $year/$month/$day" }
    }

    /** Days since 1970-01-01 (same convention as java.time.LocalDate.toEpochDay). */
    fun toEpochDay(): Long = (toJdn(year, month, day) - EPOCH_JDN).toLong()

    fun plusDays(days: Long): JalaliDate = fromEpochDay(toEpochDay() + days)

    fun plusMonths(months: Int): JalaliDate {
        val total = (year * 12 + (month - 1)) + months
        val y = Math.floorDiv(total, 12)
        val m = Math.floorMod(total, 12) + 1
        return JalaliDate(y, m, minOf(day, monthLength(y, m)))
    }

    val dayOfWeek: JalaliWeekday
        get() = JalaliWeekday.entries[Math.floorMod(toEpochDay() + 5, 7L).toInt()] // 1970-01-01 was Thursday (پنجشنبه)

    override fun compareTo(other: JalaliDate): Int = toEpochDay().compareTo(other.toEpochDay())

    /** "1403/08/15" */
    fun format(separator: Char = '/'): String =
        "$year$separator${month.toString().padStart(2, '0')}$separator${day.toString().padStart(2, '0')}"

    /** "۱۵ آبان ۱۴۰۳" */
    fun formatLong(): String = ir.hesabyar.domain.text.PersianText.toPersianDigits("$day ${MONTH_NAMES[month - 1]} $year")

    override fun toString(): String = format()

    companion object {
        val MONTH_NAMES = listOf(
            "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
            "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
        )

        val TEHRAN: TimeZone = TimeZone.getTimeZone("Asia/Tehran")

        private const val EPOCH_JDN = 2440588 // JDN of 1970-01-01

        private val BREAKS = intArrayOf(
            -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210,
            1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
        )

        fun isLeapYear(jy: Int): Boolean = jalCal(jy).leap == 0

        fun monthLength(jy: Int, jm: Int): Int = when {
            jm <= 6 -> 31
            jm <= 11 -> 30
            isLeapYear(jy) -> 30
            else -> 29
        }

        fun isValid(jy: Int, jm: Int, jd: Int): Boolean =
            jy in (BREAKS.first())..(BREAKS.last() - 1) && jm in 1..12 && jd in 1..monthLength(jy, jm)

        fun fromEpochDay(epochDay: Long): JalaliDate {
            val (y, m, d) = fromJdn((epochDay + EPOCH_JDN).toInt())
            return JalaliDate(y, m, d)
        }

        fun fromGregorian(gy: Int, gm: Int, gd: Int): JalaliDate {
            val (y, m, d) = fromJdn(g2d(gy, gm, gd))
            return JalaliDate(y, m, d)
        }

        fun fromEpochMillis(millis: Long, zone: TimeZone = TEHRAN): JalaliDate {
            val offset = zone.getOffset(millis)
            return fromEpochDay(Math.floorDiv(millis + offset, 86_400_000L))
        }

        fun today(zone: TimeZone = TEHRAN, nowMillis: Long = System.currentTimeMillis()) =
            fromEpochMillis(nowMillis, zone)

        /** Epoch millis of `date hour:minute` in [zone] (Iran has had no DST since 1401). */
        fun toEpochMillis(date: JalaliDate, hour: Int = 0, minute: Int = 0, second: Int = 0, zone: TimeZone = TEHRAN): Long {
            val epochDay = date.toEpochDay()
            val cal = Calendar.getInstance(zone)
            cal.clear()
            // Convert epochDay → Gregorian Y/M/D via JDN, then let Calendar resolve offsets.
            val (gy, gm, gd) = d2g((epochDay + EPOCH_JDN).toInt())
            cal.set(gy, gm - 1, gd, hour, minute, second)
            return cal.timeInMillis
        }

        fun toGregorian(date: JalaliDate): Triple<Int, Int, Int> = d2g(toJdn(date.year, date.month, date.day))

        // ---------------------------------------------------------------- algorithm

        private class JalCal(val leap: Int, val gy: Int, val march: Int)

        private fun div(a: Int, b: Int): Int = a / b      // truncating, as in the reference
        private fun mod(a: Int, b: Int): Int = a - (a / b) * b

        private fun jalCal(jy: Int): JalCal {
            require(jy >= BREAKS.first() && jy < BREAKS.last()) { "Jalali year out of range: $jy" }
            val gy = jy + 621
            var leapJ = -14
            var jp = BREAKS[0]
            var jump = 0
            for (i in 1 until BREAKS.size) {
                val jm = BREAKS[i]
                jump = jm - jp
                if (jy < jm) break
                leapJ += div(jump, 33) * 8 + div(mod(jump, 33), 4)
                jp = jm
            }
            var n = jy - jp
            leapJ += div(n, 33) * 8 + div(mod(n, 33) + 3, 4)
            if (mod(jump, 33) == 4 && jump - n == 4) leapJ += 1
            val leapG = div(gy, 4) - div((div(gy, 100) + 1) * 3, 4) - 150
            val march = 20 + leapJ - leapG
            if (jump - n < 6) n = n - jump + div(jump + 4, 33) * 33
            var leap = mod(mod(n + 1, 33) - 1, 4)
            if (leap == -1) leap = 4
            return JalCal(leap, gy, march)
        }

        private fun toJdn(jy: Int, jm: Int, jd: Int): Int {
            val r = jalCal(jy)
            return g2d(r.gy, 3, r.march) + (jm - 1) * 31 - div(jm, 7) * (jm - 7) + jd - 1
        }

        private fun fromJdn(jdn: Int): Triple<Int, Int, Int> {
            val gy = d2g(jdn).first
            var jy = gy - 621
            val r = jalCal(jy)
            val jdn1f = g2d(gy, 3, r.march)
            var k = jdn - jdn1f
            if (k >= 0) {
                if (k <= 185) return Triple(jy, 1 + div(k, 31), mod(k, 31) + 1)
                k -= 186
            } else {
                jy -= 1
                k += 179
                if (r.leap == 1) k += 1
            }
            return Triple(jy, 7 + div(k, 30), mod(k, 30) + 1)
        }

        private fun g2d(gy: Int, gm: Int, gd: Int): Int {
            var d = div((gy + div(gm - 8, 6) + 100100) * 1461, 4) +
                div(153 * mod(gm + 9, 12) + 2, 5) + gd - 34840408
            d = d - div(div(gy + 100100 + div(gm - 8, 6), 100) * 3, 4) + 752
            return d
        }

        private fun d2g(jdn: Int): Triple<Int, Int, Int> {
            var j = 4 * jdn + 139361631
            j += div(div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908
            val i = div(mod(j, 1461), 4) * 5 + 308
            val gd = div(mod(i, 153), 5) + 1
            val gm = mod(div(i, 153), 12) + 1
            val gy = div(j, 1461) - 100100 + div(8 - gm, 6)
            return Triple(gy, gm, gd)
        }
    }
}

enum class JalaliWeekday(val persianName: String) {
    SATURDAY("شنبه"), SUNDAY("یکشنبه"), MONDAY("دوشنبه"), TUESDAY("سه‌شنبه"),
    WEDNESDAY("چهارشنبه"), THURSDAY("پنجشنبه"), FRIDAY("جمعه"),
}
