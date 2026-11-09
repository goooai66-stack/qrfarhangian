package ir.hesabyar.domain

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.due.InstallmentSchedule
import ir.hesabyar.domain.due.ReminderPlanner
import ir.hesabyar.domain.due.SayadId
import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.split.SplitCalculator
import ir.hesabyar.domain.split.SplitCalculator.Participant
import ir.hesabyar.domain.voice.PersianNumberParser
import ir.hesabyar.domain.voice.VoiceTransactionParser
import ir.hesabyar.domain.voice.VoiceTransactionParser.CategoryCandidate
import ir.hesabyar.domain.voice.VoiceTransactionParser.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Step2Test {

    // ------------------------------------------------------------ Persian numbers
    @Test fun numberWords() {
        val cases = mapOf(
            "پانصد هزار" to 500_000L,
            "دو میلیون و سیصد هزار" to 2_300_000L,
            "یک و نیم میلیون" to 1_500_000L,
            "بیست و پنج هزار و پونصد" to 25_500L,
            "بیست‌وپنج هزار" to 25_000L,
            "۲.۵ میلیون" to 2_500_000L,
            "۲٫۵ میلیون" to 2_500_000L,
            "500 هزار" to 500_000L,
            "1,250,000" to 1_250_000L,
            "صد و بیست هزار" to 120_000L,
            "دو صد" to 200L,
            "هزار و پانصد" to 1_500L,
            "یک میلیارد و دویست میلیون" to 1_200_000_000L,
            "نیم میلیون" to 500_000L,
            "شیشصد و پنجاه هزار" to 650_000L,
        )
        cases.forEach { (text, expected) -> assertEquals(text, expected, PersianNumberParser.parseLargest(text)) }
        assertNull(PersianNumberParser.parseLargest("خرید نان"))
    }

    @Test fun largestNumberIsTheAmount() {
        assertEquals(300_000L, PersianNumberParser.parseLargest("دو تا پیتزا سیصد هزار تومن"))
    }

    // ------------------------------------------------------------ voice → transaction
    private val expense = listOf(
        CategoryCandidate(1, "سوپرمارکت"), CategoryCandidate(2, "رستوران و کافه"), CategoryCandidate(3, "بنزین و خودرو"),
        CategoryCandidate(4, "حمل‌ونقل"), CategoryCandidate(5, "قبوض"),
    )
    private val income = listOf(CategoryCandidate(10, "حقوق"), CategoryCandidate(11, "فروش"))

    @Test fun voiceExpenseWithBank() {
        val r = VoiceTransactionParser.parse("پانصد هزار تومان خرید میوه از کارت ملت", expense, income)
        assertEquals(500_000L, r.amountToman)
        assertEquals(Kind.EXPENSE, r.kind)
        assertEquals(listOf(Bank.MELLAT), r.banks)
        assertEquals(1L, r.categoryId)
    }

    @Test fun voiceIncome() {
        val r = VoiceTransactionParser.parse("دو میلیون و سیصد هزار تومن حقوق واریز شد به بلو", expense, income)
        assertEquals(2_300_000L, r.amountToman)
        assertEquals(Kind.INCOME, r.kind)
        assertEquals(listOf(Bank.BLU), r.banks)
        assertEquals(10L, r.categoryId)
    }

    @Test fun voiceTransferBetweenBanks() {
        val r = VoiceTransactionParser.parse("انتقال یک و نیم میلیون از ملت به بلو", expense, income)
        assertEquals(Kind.TRANSFER, r.kind)
        assertEquals(1_500_000L, r.amountToman)
        assertEquals(listOf(Bank.MELLAT, Bank.BLU), r.banks)
        assertNull(r.categoryId)
    }

    @Test fun voiceCashAndSynonymsAndRial() {
        val r = VoiceTransactionParser.parse("۲۵۰ هزار تومن بنزین نقدی", expense, income)
        assertEquals(250_000L, r.amountToman)
        assertTrue(r.cash)
        assertEquals(3L, r.categoryId)
        assertEquals(4L, VoiceTransactionParser.parse("بیست هزار تومن اسنپ", expense, income).categoryId)
        assertEquals(50_000L, VoiceTransactionParser.parse("پانصد هزار ریال قبض برق", expense, income).amountToman)
    }

    // ------------------------------------------------------------ installments & reminders
    @Test fun installmentScheduleClampsTo30And29() {
        val dates = InstallmentSchedule.build(JalaliDate(1404, 5, 31), count = 8)
        assertEquals(JalaliDate(1404, 5, 31), dates[0])
        assertEquals(JalaliDate(1404, 6, 31), dates[1])
        assertEquals(JalaliDate(1404, 7, 30), dates[2])
        assertEquals(JalaliDate(1404, 12, 29), dates[7]) // 1404 not leap
        assertEquals(JalaliDate(1403, 12, 30), InstallmentSchedule.build(JalaliDate(1403, 11, 30), 2)[1]) // 1403 leap
    }

    @Test fun reminderOffsets() {
        assertEquals(3, ReminderPlanner.offsetFor(100, 103))
        assertEquals(1, ReminderPlanner.offsetFor(100, 101))
        assertEquals(0, ReminderPlanner.offsetFor(100, 100))
        assertEquals(-1, ReminderPlanner.offsetFor(100, 99))
        assertNull(ReminderPlanner.offsetFor(100, 102))
        assertNull(ReminderPlanner.offsetFor(100, 90))
    }

    @Test fun nextDailyCheck() {
        val morning = JalaliDate.toEpochMillis(JalaliDate(1404, 8, 1), 7, 0)
        val nine = JalaliDate.toEpochMillis(JalaliDate(1404, 8, 1), 9, 0)
        assertEquals(nine, ReminderPlanner.nextCheckAt(morning))
        assertEquals(JalaliDate.toEpochMillis(JalaliDate(1404, 8, 2), 9, 0), ReminderPlanner.nextCheckAt(nine))
    }

    @Test fun sayad() {
        assertEquals("1234567890123456", SayadId.normalize("۱۲۳۴-۵۶۷۸-۹۰۱۲-۳۴۵۶"))
        assertNull(SayadId.normalize("12345"))
    }

    // ------------------------------------------------------------ split bill
    @Test fun splitRemainderGoesToPayer() {
        val shares = SplitCalculator.split(1_000_000, listOf(Participant("me"), Participant("ali"), Participant("sara")), payerKey = "me")
        assertEquals(1_000_000L, shares.sumOf { it.amountRial })
        assertEquals(330_000L, shares.first { it.key == "ali" }.amountRial)
        assertEquals(340_000L, shares.first { it.key == "me" }.amountRial)
    }

    @Test fun splitByWeight() {
        val shares = SplitCalculator.split(3_000_000, listOf(Participant("me", 2), Participant("ali", 1)), payerKey = "ali")
        assertEquals(2_000_000L, shares.first { it.key == "me" }.amountRial)
        assertEquals(1_000_000L, shares.first { it.key == "ali" }.amountRial)
    }
}
