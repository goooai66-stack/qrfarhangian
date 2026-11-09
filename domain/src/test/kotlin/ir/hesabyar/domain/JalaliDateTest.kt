package ir.hesabyar.domain

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.calendar.JalaliWeekday
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JalaliDateTest {

    @Test fun nowruzDates() {
        assertEquals(JalaliDate(1403, 1, 1), JalaliDate.fromGregorian(2024, 3, 20))
        assertEquals(JalaliDate(1404, 1, 1), JalaliDate.fromGregorian(2025, 3, 21))
        assertEquals(JalaliDate(1405, 1, 1), JalaliDate.fromGregorian(2026, 3, 21))
        assertEquals(JalaliDate(1399, 1, 1), JalaliDate.fromGregorian(2020, 3, 20))
    }

    @Test fun leapYears() {
        // 1403 is leap (1403/12/30 = 2025-03-20); 1404 is not; 1399 and 1408 are.
        assertTrue(JalaliDate.isLeapYear(1399))
        assertTrue(JalaliDate.isLeapYear(1403))
        assertFalse(JalaliDate.isLeapYear(1404))
        assertTrue(JalaliDate.isLeapYear(1408))
        assertEquals(JalaliDate(1403, 12, 30), JalaliDate.fromGregorian(2025, 3, 20))
        assertEquals(29, JalaliDate.monthLength(1404, 12))
    }

    @Test fun roundTripEveryDayOfAFewYears() {
        val start = JalaliDate(1398, 1, 1).toEpochDay()
        val end = JalaliDate(1410, 12, 29).toEpochDay()
        var prev: JalaliDate? = null
        for (d in start..end) {
            val j = JalaliDate.fromEpochDay(d)
            assertEquals(d, j.toEpochDay())
            if (prev != null) assertTrue(j > prev)
            prev = j
        }
    }

    @Test fun knownGregorian() {
        assertEquals(JalaliDate(1403, 8, 15), JalaliDate.fromGregorian(2024, 11, 5))
        assertEquals(Triple(2026, 11, 9), JalaliDate.toGregorian(JalaliDate(1405, 8, 18)))
    }

    @Test fun weekday() {
        // 2024-03-20 was a Wednesday.
        assertEquals(JalaliWeekday.WEDNESDAY, JalaliDate(1403, 1, 1).dayOfWeek)
    }

    @Test fun plusMonthsClampsDay() {
        assertEquals(JalaliDate(1404, 7, 30), JalaliDate(1404, 6, 31).plusMonths(1))
        assertEquals(JalaliDate(1405, 1, 31), JalaliDate(1404, 12, 29).plusMonths(1).let { JalaliDate(it.year, it.month, 31) })
    }

    @Test fun epochMillisTehran() {
        val millis = JalaliDate.toEpochMillis(JalaliDate(1403, 8, 15), 14, 23)
        assertEquals(JalaliDate(1403, 8, 15), JalaliDate.fromEpochMillis(millis))
    }
}
