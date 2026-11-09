package ir.hesabyar.domain.due

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.text.PersianText
import java.util.Calendar
import java.util.TimeZone

/** Monthly installment dates on a fixed Jalali day, clamped to each month's real length. */
object InstallmentSchedule {
    /** «روز ۳۱ هر ماه» → 31 Shahrivar, 30 Mehr, … 29/30 Esfand depending on leap year. */
    fun build(firstDue: JalaliDate, count: Int, dueDay: Int = firstDue.day): List<JalaliDate> {
        require(count in 1..600) { "installment count out of range" }
        require(dueDay in 1..31)
        return (0 until count).map { i ->
            val month = JalaliDate(firstDue.year, firstDue.month, 1).plusMonths(i)
            JalaliDate(month.year, month.month, minOf(dueDay, JalaliDate.monthLength(month.year, month.month)))
        }
    }
}

/**
 * Reminder rule: notify 3 days before, 1 day before, on the due day, and once the day after
 * if still unpaid. A single daily check (default 09:00 Tehran) evaluates all items, so there is
 * exactly one alarm in the system regardless of how many cheques/installments exist.
 */
object ReminderPlanner {

    val OFFSETS = listOf(3, 1, 0, -1)

    fun offsetFor(todayEpochDay: Long, dueEpochDay: Long): Int? =
        (dueEpochDay - todayEpochDay).toInt().takeIf { it in OFFSETS }

    fun label(offset: Int): String = when (offset) {
        3 -> "۳ روز دیگر"
        1 -> "فردا"
        0 -> "امروز"
        -1 -> "دیروز سررسید شد"
        else -> PersianText.toPersianDigits("$offset روز")
    }

    /** Next [hour]:[minute] in [zone] strictly after [nowMillis]. */
    fun nextCheckAt(nowMillis: Long, hour: Int = 9, minute: Int = 0, zone: TimeZone = JalaliDate.TEHRAN): Long {
        val cal = Calendar.getInstance(zone).apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= nowMillis) cal.add(Calendar.DAY_OF_MONTH, 1)
        return cal.timeInMillis
    }
}

/** شناسه صیادی: exactly 16 digits (Persian/Latin input, spaces and dashes tolerated). */
object SayadId {
    fun normalize(input: String): String? {
        val digits = PersianText.toLatinDigits(input).filter { it.isDigit() }
        return digits.takeIf { it.length == 16 && input.none { c -> c.isLetter() } }
    }
}
