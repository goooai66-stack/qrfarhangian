package ir.hesabyar.app.ui.common

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.text.PersianText
import java.util.Calendar

/** «امروز ۱۴:۲۳» / «دیروز ۰۹:۱۰» / «۱۲ آبان» / «۱۲ آبان ۱۴۰۲» */
fun formatWhen(millis: Long, now: Long = System.currentTimeMillis()): String {
    val day = JalaliDate.fromEpochMillis(millis)
    val today = JalaliDate.fromEpochMillis(now)
    val diff = today.toEpochDay() - day.toEpochDay()
    val cal = Calendar.getInstance(JalaliDate.TEHRAN).apply { timeInMillis = millis }
    val time = "%02d:%02d".format(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))
    val text = when {
        diff == 0L -> "امروز $time"
        diff == 1L -> "دیروز $time"
        day.year == today.year -> "${day.day} ${JalaliDate.MONTH_NAMES[day.month - 1]}"
        else -> "${day.day} ${JalaliDate.MONTH_NAMES[day.month - 1]} ${day.year}"
    }
    return PersianText.toPersianDigits(text)
}

fun formatToday(now: Long = System.currentTimeMillis()): String {
    val d = JalaliDate.fromEpochMillis(now)
    return "${d.dayOfWeek.persianName} ${d.formatLong()}"
}
