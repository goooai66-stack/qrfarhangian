package ir.hesabyar.domain

import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.export.XlsxWriter
import ir.hesabyar.domain.export.XlsxWriter.Cell
import ir.hesabyar.domain.ledger.TransactionType
import ir.hesabyar.domain.report.ReportBuilder
import ir.hesabyar.domain.report.ReportBuilder.Entry
import ir.hesabyar.domain.security.BackupCrypto
import ir.hesabyar.domain.security.PinAttemptPolicy
import ir.hesabyar.domain.security.PinHasher
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.ZipInputStream
import javax.xml.parsers.DocumentBuilderFactory

class Step5Test {

    private fun at(y: Int, m: Int, d: Int) = JalaliDate.toEpochMillis(JalaliDate(y, m, d), 12, 0)

    // ------------------------------------------------------------ reports
    private val entries = listOf(
        Entry(at(1404, 8, 2), TransactionType.INCOME, 300_000_000, 10),
        Entry(at(1404, 8, 3), TransactionType.EXPENSE, 50_000_000, 1),
        Entry(at(1404, 8, 5), TransactionType.EXPENSE, 30_000_000, 2),
        Entry(at(1404, 8, 9), TransactionType.EXPENSE, 20_000_000, 1),
        Entry(at(1404, 8, 9), TransactionType.TRANSFER_OUT, 999_000_000, null),   // never counted
        Entry(at(1404, 7, 20), TransactionType.EXPENSE, 80_000_000, 1),
        Entry(at(1404, 3, 1), TransactionType.INCOME, 100_000_000, 10),           // outside 6-month window
    )

    @Test fun periodReportExcludesTransfers() {
        val r = ReportBuilder.period(
            entries, JalaliDate(1404, 8, 1), JalaliDate(1404, 8, 30),
            previousEntries = entries.filter { JalaliDate.fromEpochMillis(it.occurredAtMillis).month == 7 },
            today = JalaliDate(1404, 8, 10),
        )
        assertEquals(300_000_000L, r.incomeRial)
        assertEquals(100_000_000L, r.expenseRial)
        assertEquals(200_000_000L, r.netRial)
        assertEquals(66.666, r.savingsRatePercent!!, 0.01)
        assertEquals(10_000_000L, r.dailyAverageExpenseRial)        // 100M over 10 elapsed days
        assertEquals(25.0, r.expenseChangePercent!!, 0.001)          // 80M → 100M
        assertEquals(4, r.transactionCount)
        assertEquals(listOf(1L, 2L), r.expenseSlices.map { it.categoryId })
        assertEquals(70.0, r.expenseSlices[0].percent, 0.001)
    }

    @Test fun monthlyBucketsZeroFilledOldestFirst() {
        val m = ReportBuilder.monthly(entries, JalaliDate(1404, 8, 15), months = 6)
        assertEquals(6, m.size)
        assertEquals(3 to 3, m.first().year - 1401 to m.first().month)  // 1404/03 … 1404/08
        assertEquals(100_000_000L, m.first().incomeRial)
        assertEquals(80_000_000L, m[4].expenseRial)
        assertEquals(100_000_000L, m[5].expenseRial)
        assertEquals("آبان", m[5].label)
    }

    @Test fun slicesMergeTailIntoOther() {
        val many = (1L..8L).map { Entry(at(1404, 8, 1), TransactionType.EXPENSE, it * 1000, it) }
        val s = ReportBuilder.slices(many, max = 4)
        assertEquals(4, s.size)
        assertEquals(listOf(8L, 7L, 6L), s.take(3).map { it.categoryId })
        assertTrue(s.last().isOther)
        assertEquals(15_000L, s.last().amountRial)
        assertEquals(100.0, s.sumOf { it.percent }, 0.0001)
    }

    @Test fun presetsAcrossYearBoundary() {
        val r = ReportBuilder.range(ReportBuilder.Preset.LAST_MONTH, JalaliDate(1405, 1, 10))
        assertEquals(JalaliDate(1404, 12, 1), r[0])
        assertEquals(JalaliDate(1404, 12, 29), r[1])
        val year = ReportBuilder.range(ReportBuilder.Preset.THIS_YEAR, JalaliDate(1403, 5, 5))
        assertEquals(JalaliDate(1403, 12, 30), year[1]) // leap year
    }

    // ------------------------------------------------------------ xlsx
    @Test fun xlsxIsValidZipWithWellFormedXml() {
        val out = ByteArrayOutputStream()
        XlsxWriter.write(
            listOf(
                XlsxWriter.Sheet("تراکنش‌ها", listOf(listOf(Cell.Header("تاریخ"), Cell.Header("مبلغ")), listOf(Cell.Text("۱۴۰۴/۰۸/۰۳ <&>"), Cell.Number(1_250_000))), listOf(14, 16)),
                XlsxWriter.Sheet("خلاصه: آبان/۱۴۰۴", listOf(listOf(Cell.Text("x"), Cell.Empty, Cell.Number(-5)))),
            ),
            out,
        )
        val entries = mutableMapOf<String, String>()
        ZipInputStream(ByteArrayInputStream(out.toByteArray())).use { z ->
            while (true) { val e = z.nextEntry ?: break; entries[e.name] = z.readBytes().toString(Charsets.UTF_8) }
        }
        assertTrue(entries.keys.containsAll(listOf("[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/styles.xml", "xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml")))
        val factory = DocumentBuilderFactory.newInstance()
        entries.values.forEach { factory.newDocumentBuilder().parse(ByteArrayInputStream(it.toByteArray())) } // throws if malformed
        assertTrue(entries["xl/worksheets/sheet1.xml"]!!.contains("rightToLeft=\"1\""))
        assertTrue(entries["xl/worksheets/sheet1.xml"]!!.contains("&lt;&amp;&gt;"))
        assertTrue(entries["xl/workbook.xml"]!!.contains("خلاصه  آبان ۱۴۰۴"))
        assertEquals("AA", XlsxWriter.columnName(26))
    }

    // ------------------------------------------------------------ security
    @Test fun pinHashing() {
        val h = PinHasher.hash("1384")
        assertTrue(PinHasher.verify("1384", h))
        assertFalse(PinHasher.verify("1385", h))
        assertFalse(PinHasher.verify("12a4", h))
        assertFalse(PinHasher.hash("1384").hashHex == h.hashHex) // salted
    }

    @Test fun pinThrottling() {
        var p = PinAttemptPolicy()
        repeat(4) { p = p.onFailure(0) }
        assertFalse(p.isLocked(0))
        p = p.onFailure(0)
        assertTrue(p.isLocked(1_000))
        assertEquals(30_000L, p.remainingMillis(0))
        p = p.onFailure(30_000)
        assertEquals(60_000L, p.remainingMillis(30_000))
        repeat(10) { p = p.onFailure(0) }
        assertEquals(PinAttemptPolicy.MAX_DELAY_MS, p.remainingMillis(0))
        assertFalse(p.onSuccess().isLocked(0))
    }

    @Test fun backupEncryptionRoundTripAndTamperDetection() {
        val plain = """{"format":"hesabyar-backup","note":"سلام"}""".toByteArray()
        val enc = BackupCrypto.encrypt(plain, "رمز-قوی-۱۲۳".toCharArray(), iterations = 2_000)
        assertTrue(BackupCrypto.isEncrypted(enc))
        assertFalse(BackupCrypto.isEncrypted(plain))
        assertArrayEquals(plain, BackupCrypto.decrypt(enc, "رمز-قوی-۱۲۳".toCharArray()))
        try { BackupCrypto.decrypt(enc, "wrong-pass".toCharArray()); fail() } catch (_: BackupCrypto.WrongPasswordOrCorrupt) {}
        val tampered = enc.copyOf().also { it[it.size - 1] = (it[it.size - 1] + 1).toByte() }
        try { BackupCrypto.decrypt(tampered, "رمز-قوی-۱۲۳".toCharArray()); fail() } catch (_: BackupCrypto.WrongPasswordOrCorrupt) {}
        try { BackupCrypto.decrypt(plain, "x".toCharArray()); fail() } catch (_: BackupCrypto.NotEncrypted) {}
    }

    @Test fun nullSavingsRateWithoutIncome() {
        assertNull(ReportBuilder.period(emptyList(), JalaliDate(1404, 1, 1), JalaliDate(1404, 1, 31)).savingsRatePercent)
    }
}
