package ir.hesabyar.app.export

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.TextUtils
import androidx.core.content.res.ResourcesCompat
import ir.hesabyar.app.R
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.AccountKind
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.repository.TransactionFilter
import ir.hesabyar.app.data.repository.TransactionRepository
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.export.XlsxWriter
import ir.hesabyar.domain.export.XlsxWriter.Cell
import ir.hesabyar.domain.ledger.TransactionType
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.report.ReportBuilder
import ir.hesabyar.domain.text.PersianText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.Locale

/** Excel (.xlsx) and PDF reports for the accountant, both fully Persian/RTL and offline. */
class ReportExporter(private val context: Context, private val db: AppDatabase, private val transactions: TransactionRepository) {

    private data class Data(
        val ledgerName: String,
        val from: JalaliDate,
        val to: JalaliDate,
        val rows: List<TransactionRow>, // chronological
        val accounts: List<AccountEntity>,
        val categories: Map<Long, CategoryEntity>,
        val report: ReportBuilder.PeriodReport,
    )

    private suspend fun load(ledgerId: Long, from: JalaliDate, to: JalaliDate): Data {
        val ledger = db.ledgerDao().listAll().first { it.id == ledgerId }
        val rows = transactions.observeFiltered(ledgerId, TransactionFilter(from = from, to = to), limit = 1_000_000).first().reversed()
        val categories = db.categoryDao().observeByLedger(ledgerId).first().associateBy { it.id }
        val report = ReportBuilder.period(rows.map { ReportBuilder.Entry(it.tx.occurredAt, it.tx.type, it.tx.amountRial, it.tx.categoryId) }, from, to)
        return Data(ledger.name, from, to, rows, db.accountDao().listByLedger(ledgerId), categories, report)
    }

    private fun fileStem(d: Data) = "hesabyar-${d.from.format('-')}_${d.to.format('-')}"

    // ================================================================== Excel

    suspend fun excel(ledgerId: Long, from: JalaliDate, to: JalaliDate): ExportedFile = withContext(Dispatchers.Default) {
        val d = load(ledgerId, from, to)
        val r = d.report
        val summary = mutableListOf<List<Cell>>(
            listOf(Cell.Header("گزارش مالی حساب‌یار"), Cell.Text(d.ledgerName)),
            listOf(Cell.Text("بازه"), Cell.Text("${d.from} تا ${d.to}")),
            listOf(Cell.Text("درآمد (تومان)"), Cell.Number(r.incomeRial / 10)),
            listOf(Cell.Text("هزینه (تومان)"), Cell.Number(r.expenseRial / 10)),
            listOf(Cell.Text("خالص (تومان)"), Cell.Number(r.netRial / 10)),
            listOf(Cell.Text("میانگین هزینه روزانه (تومان)"), Cell.Number(r.dailyAverageExpenseRial / 10)),
            listOf(Cell.Text("تعداد تراکنش"), Cell.Number(r.transactionCount.toLong())),
            emptyList(),
            listOf(Cell.Header("دسته هزینه"), Cell.Header("مبلغ (تومان)"), Cell.Header("درصد")),
        )
        ReportBuilder.slices(d.rows.filter { it.tx.type == TransactionType.EXPENSE }.map { ReportBuilder.Entry(it.tx.occurredAt, it.tx.type, it.tx.amountRial, it.tx.categoryId) }, max = 1000)
            .forEach { s -> summary += listOf(Cell.Text(categoryName(d, s.categoryId)), Cell.Number(s.amountRial / 10), Cell.Text("%.1f%%".format(Locale.US, s.percent))) }

        val txSheet = mutableListOf(
            listOf("تاریخ", "ساعت", "نوع", "دسته", "حساب", "طرف انتقال", "مبلغ (تومان)", "مانده پس از تراکنش (تومان)", "توضیحات").map { Cell.Header(it) },
        )
        d.rows.forEach { row ->
            val tx = row.tx
            val signed = if (tx.type == TransactionType.TRANSFER_OUT) tx.amountRial else tx.type.signedAmount(tx.amountRial)
            txSheet += listOf(
                Cell.Text(JalaliDate.fromEpochMillis(tx.occurredAt).format()), Cell.Text(time(tx.occurredAt)), Cell.Text(typeLabel(tx.type)),
                Cell.Text(row.categoryName.orEmpty()), Cell.Text(row.accountName), Cell.Text(row.counterAccountName.orEmpty()),
                Cell.Number(signed / 10), Cell.Number(tx.balanceAfterRial / 10), Cell.Text(tx.note),
            )
        }

        val accSheet = mutableListOf(listOf("حساب", "نوع", "بانک", "موجودی فعلی (تومان)").map { Cell.Header(it) })
        d.accounts.forEach { a ->
            accSheet += listOf(Cell.Text(a.name), Cell.Text(accountKind(a.kind)), Cell.Text(a.bank?.persianName.orEmpty()), Cell.Number(a.currentBalanceRial / 10))
        }

        val out = ByteArrayOutputStream()
        XlsxWriter.write(
            listOf(
                XlsxWriter.Sheet("خلاصه", summary, listOf(30, 22, 10)),
                XlsxWriter.Sheet("تراکنش‌ها", txSheet, listOf(12, 7, 10, 18, 20, 18, 16, 20, 30)),
                XlsxWriter.Sheet("حساب‌ها", accSheet, listOf(26, 10, 16, 20)),
            ),
            out,
        )
        ExportedFile(fileStem(d) + ".xlsx", ExportedFile.MIME_XLSX, out.toByteArray())
    }

    // ================================================================== PDF (A4, RTL)

    suspend fun pdf(ledgerId: Long, from: JalaliDate, to: JalaliDate): ExportedFile = withContext(Dispatchers.Default) {
        val d = load(ledgerId, from, to)
        val regular = ResourcesCompat.getFont(context, R.font.vazirmatn_regular) ?: Typeface.DEFAULT
        val bold = ResourcesCompat.getFont(context, R.font.vazirmatn_bold) ?: Typeface.DEFAULT_BOLD
        val pdf = PdfRenderer(regular, bold)
        val r = d.report

        pdf.title("گزارش مالی — ${d.ledgerName}")
        pdf.line(fa("بازه: ${d.from.formatLong()} تا ${d.to.formatLong()} • تهیه‌شده در ${JalaliDate.today().formatLong()}"), size = 9f, color = GREY)
        pdf.gap(10f)
        pdf.statRow(
            listOf(
                "درآمد" to Money.formatToman(r.incomeRial), "هزینه" to Money.formatToman(r.expenseRial),
                "خالص" to Money.formatToman(r.netRial),
                "نرخ پس‌انداز" to (r.savingsRatePercent?.let { fa("%.1f".format(Locale.US, it)) + "٪" } ?: "—"),
            ),
        )
        pdf.gap(14f)

        pdf.heading("هزینه به تفکیک دسته")
        r.expenseSlices.forEach { s -> pdf.barRow(categoryName(d, s.categoryId), s.percent.toFloat(), Money.formatToman(s.amountRial), fa("%.1f".format(Locale.US, s.percent)) + "٪") }
        if (r.expenseSlices.isEmpty()) pdf.line("هزینه‌ای در این بازه ثبت نشده است.", size = 9f, color = GREY)
        pdf.gap(14f)

        pdf.heading(fa("تراکنش‌ها (${d.rows.size})"))
        val cols = listOf("تاریخ" to 62f, "نوع" to 48f, "دسته" to 92f, "حساب" to 96f, "مبلغ (تومان)" to 84f, "توضیحات" to 0f)
        pdf.tableHeader(cols)
        d.rows.forEach { row ->
            val tx = row.tx
            val amount = if (tx.type == TransactionType.TRANSFER_OUT) Money.formatToman(tx.amountRial) else Money.formatSignedToman(tx.type.signedAmount(tx.amountRial))
            pdf.tableRow(
                cols,
                listOf(
                    fa(JalaliDate.fromEpochMillis(tx.occurredAt).format()), typeLabel(tx.type), row.categoryName.orEmpty(),
                    if (row.counterAccountName != null) "${row.accountName} ← ${row.counterAccountName}" else row.accountName,
                    amount, tx.note,
                ),
                amountColor = when { tx.type == TransactionType.INCOME -> GREEN; tx.type == TransactionType.EXPENSE -> CORAL; else -> NAVY },
            )
        }
        pdf.gap(14f)
        pdf.line("این گزارش به‌صورت آفلاین روی گوشی ساخته شده است — حساب‌یار", size = 8f, color = GREY)
        ExportedFile(fileStem(d) + ".pdf", ExportedFile.MIME_PDF, pdf.finish())
    }

    /**
     * Tiny flowing-layout PDF writer: draws right-to-left text with StaticLayout (correct bidi for
     * Persian with embedded numbers), starts a new A4 page automatically and repeats table headers.
     */
    private class PdfRenderer(private val regular: Typeface, private val bold: Typeface) {
        private val doc = PdfDocument()
        private var pageNo = 0
        private lateinit var page: PdfDocument.Page
        private lateinit var canvas: Canvas
        private var y = 0f
        private var lastHeader: List<Pair<String, Float>>? = null

        init { newPage() }

        private fun newPage() {
            if (pageNo > 0) doc.finishPage(page)
            pageNo++
            page = doc.startPage(PdfDocument.PageInfo.Builder(W, H, pageNo).create())
            canvas = page.canvas
            y = M
            text(fa("صفحه $pageNo"), H - M + 6, M, W - 2 * M, 8f, GREY, regular, Layout.Alignment.ALIGN_OPPOSITE)
        }

        private fun ensure(h: Float) {
            if (y + h > H - M - 14) {
                newPage()
                lastHeader?.let { drawHeader(it) }
            }
        }

        /** Draws [s] inside the box whose *right* edge is W−M−rightOffset (RTL flow). */
        private fun text(s: String, top: Float, rightInset: Float, width: Float, size: Float, color: Int, face: Typeface, align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL, maxLines: Int = 1): Float {
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = face; textSize = size; this.color = color }
            val w = width.toInt().coerceAtLeast(1)
            val layout = StaticLayout.Builder.obtain(s, 0, s.length, paint, w)
                .setAlignment(align).setTextDirection(TextDirectionHeuristics.RTL)
                .setMaxLines(maxLines).setEllipsize(TextUtils.TruncateAt.END).setIncludePad(false).build()
            canvas.save()
            canvas.translate(W - rightInset - w, top)
            layout.draw(canvas)
            canvas.restore()
            return layout.height.toFloat()
        }

        fun title(s: String) { ensure(30f); y += text(s, y, M, W - 2 * M, 18f, NAVY, bold) + 4 }
        fun heading(s: String) { ensure(28f); y += text(s, y, M, W - 2 * M, 12f, NAVY, bold) + 6 }
        fun line(s: String, size: Float = 10f, color: Int = INK) { ensure(size + 8); y += text(s, y, M, W - 2 * M, size, color, regular) + 3 }
        fun gap(h: Float) { y += h }

        fun statRow(items: List<Pair<String, String>>) {
            ensure(46f)
            val boxW = (W - 2 * M - (items.size - 1) * 8f) / items.size
            items.forEachIndexed { i, (label, value) ->
                val right = M + i * (boxW + 8f)
                val left = W - right - boxW
                canvas.drawRoundRect(left, y, left + boxW, y + 42f, 6f, 6f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = BEIGE })
                text(label, y + 5, right + 6, boxW - 12, 8f, GREY, regular)
                text(value, y + 19, right + 6, boxW - 12, 12f, NAVY, bold)
            }
            y += 46f
        }

        fun barRow(label: String, percent: Float, amount: String, pct: String) {
            ensure(18f)
            val labelW = 130f; val amountW = 90f; val pctW = 40f
            text(label, y, M, labelW, 9f, INK, regular)
            val barRight = W - M - labelW - 6
            val barMax = W - 2 * M - labelW - amountW - pctW - 18
            val barLen = barMax * (percent / 100f).coerceIn(0f, 1f)
            canvas.drawRoundRect(barRight - barLen, y + 3, barRight, y + 11, 3f, 3f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = GOLD })
            text(pct, y, M + labelW + barMax + 12, pctW, 9f, GREY, regular)
            text(amount, y, W - 2 * M - amountW + M, amountW, 9f, INK, bold, Layout.Alignment.ALIGN_OPPOSITE)
            y += 16f
        }

        fun tableHeader(cols: List<Pair<String, Float>>) { lastHeader = cols; ensure(22f); drawHeader(cols) }

        private fun drawHeader(cols: List<Pair<String, Float>>) {
            canvas.drawRect(M, y, W - M, y + 18f, Paint().apply { color = BEIGE })
            var right = M
            widths(cols).forEachIndexed { i, w -> text(cols[i].first, y + 3, right + 3, w - 6, 8.5f, NAVY, bold); right += w }
            y += 20f
        }

        fun tableRow(cols: List<Pair<String, Float>>, cells: List<String>, amountColor: Int) {
            ensure(16f)
            var right = M
            widths(cols).forEachIndexed { i, w ->
                text(cells[i], y + 2, right + 3, w - 6, 8.5f, if (i == 4) amountColor else INK, if (i == 4) bold else regular)
                right += w
            }
            y += 15f
            canvas.drawLine(M, y, W - M, y, Paint().apply { color = HAIRLINE; strokeWidth = 0.5f })
            y += 1f
        }

        /** A width of 0 = "take the rest". */
        private fun widths(cols: List<Pair<String, Float>>): List<Float> {
            val fixed = cols.sumOf { it.second.toDouble() }.toFloat()
            return cols.map { if (it.second == 0f) (W - 2 * M - fixed) else it.second }
        }

        fun finish(): ByteArray {
            doc.finishPage(page)
            val out = ByteArrayOutputStream()
            doc.writeTo(out)
            doc.close()
            return out.toByteArray()
        }
    }

    // ================================================================== helpers

    private fun categoryName(d: Data, id: Long?): String = id?.let { d.categories[it]?.name } ?: if (id == null) "سایر / بدون دسته" else "—"

    private fun typeLabel(t: TransactionType) = when (t) {
        TransactionType.INCOME -> "درآمد"
        TransactionType.EXPENSE -> "هزینه"
        TransactionType.TRANSFER_OUT, TransactionType.TRANSFER_IN -> "انتقال"
        TransactionType.ADJUSTMENT_UP, TransactionType.ADJUSTMENT_DOWN -> "اصلاح"
    }

    private fun accountKind(k: AccountKind) = when (k) { AccountKind.BANK -> "بانکی"; AccountKind.CASH -> "نقدی"; AccountKind.WALLET -> "کیف پول" }

    private fun time(millis: Long): String {
        val c = Calendar.getInstance(JalaliDate.TEHRAN).apply { timeInMillis = millis }
        return "%02d:%02d".format(Locale.US, c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))
    }

    private companion object {
        const val W = 595 // A4 @ 72 dpi
        const val H = 842
        const val M = 36f
        val NAVY = Color.rgb(0x1B, 0x2A, 0x4A)
        val GOLD = Color.rgb(0xC5, 0xA0, 0x59)
        val GREEN = Color.rgb(0x2E, 0x8B, 0x57)
        val CORAL = Color.rgb(0xC2, 0x41, 0x2F)
        val INK = Color.rgb(0x1F, 0x24, 0x30)
        val GREY = Color.rgb(0x6B, 0x72, 0x80)
        val BEIGE = Color.rgb(0xF1, 0xEC, 0xE2)
        val HAIRLINE = Color.rgb(0xE9, 0xE3, 0xD7)
        fun fa(s: String) = PersianText.toPersianDigits(s)
    }
}
