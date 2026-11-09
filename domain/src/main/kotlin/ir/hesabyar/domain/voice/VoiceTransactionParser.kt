package ir.hesabyar.domain.voice

import ir.hesabyar.domain.sms.Bank
import ir.hesabyar.domain.text.PersianText

/**
 * «پانصد هزار تومان خرید میوه از کارت ملت» →
 *   amount 500,000 Toman · EXPENSE · bank MELLAT · category «سوپرمارکت».
 * Pure text → intent; speech-to-text itself is done by the platform recognizer.
 */
object VoiceTransactionParser {

    enum class Kind { EXPENSE, INCOME, TRANSFER }

    data class CategoryCandidate(val id: Long, val name: String)

    data class Result(
        val amountToman: Long?,
        val kind: Kind,
        /** Banks in the order spoken. For a transfer: [from, to]. */
        val banks: List<Bank>,
        val cash: Boolean,
        val categoryId: Long?,
        val transcript: String,
    )

    private val transferWords = listOf("انتقال", "منتقل", "کارت به کارت", "جابجا", "جابه جا")
    private val incomeWords = listOf("درآمد", "حقوق", "واریز", "گرفتم", "دریافت", "فروش", "فروختم", "طلبم را", "سود", "پاداش", "عیدی")
    private val cashWords = listOf("نقد", "نقدی", "کیف پول", "کیف", "دستی")

    /** canonical fragment of a seeded category name → spoken synonyms. */
    private val synonyms: Map<String, List<String>> = mapOf(
        "سوپرمارکت" to listOf("میوه", "سبزی", "نان", "نون", "شیر", "سوپر", "سوپرمارکت", "بقالی", "خواربار", "هایپر", "گوشت", "مرغ", "برنج", "میوه فروشی"),
        "رستوران" to listOf("رستوران", "کافه", "شام", "ناهار", "نهار", "صبحانه", "پیتزا", "فست فود", "ساندویچ", "قهوه", "غذا", "کباب"),
        "بنزین" to listOf("بنزین", "سوخت", "کارواش", "تعمیر ماشین", "پارکینگ", "عوارض", "مکانیک", "لاستیک"),
        "حمل" to listOf("تاکسی", "اسنپ", "تپسی", "مترو", "اتوبوس", "کرایه", "بلیط", "آژانس"),
        "قبوض" to listOf("قبض", "برق", "آب", "گاز", "تلفن"),
        "شارژ" to listOf("شارژ", "اینترنت", "بسته اینترنت"),
        "اجاره" to listOf("اجاره", "رهن", "شارژ ساختمان"),
        "درمان" to listOf("دارو", "داروخانه", "دکتر", "پزشک", "دندانپزشک", "آزمایش", "بیمارستان"),
        "پوشاک" to listOf("لباس", "کفش", "مانتو", "شلوار", "پیراهن", "کیف"),
        "آموزش" to listOf("کتاب", "کلاس", "شهریه", "دوره", "مدرسه"),
        "تفریح" to listOf("سینما", "تفریح", "سفر", "بازی", "پارک", "کنسرت"),
        "هدیه" to listOf("هدیه", "کادو", "خیریه", "صدقه", "نذری"),
        "حقوق" to listOf("حقوق", "دستمزد", "مزد"),
        "فروش" to listOf("فروش", "فروختم"),
        "خرید کالا" to listOf("جنس", "کالا", "بار"),
    )

    fun parse(transcript: String, categories: List<CategoryCandidate> = emptyList(), incomeCategories: List<CategoryCandidate> = emptyList()): Result {
        val text = PersianText.normalize(transcript).lowercase()
        var amount = PersianNumberParser.parseLargest(text)
        if (amount != null && containsWord(text, "ریال")) amount /= 10

        val kind = when {
            transferWords.any { text.contains(it) } -> Kind.TRANSFER
            incomeWords.any { containsWord(text, it) } -> Kind.INCOME
            else -> Kind.EXPENSE
        }
        val pool = if (kind == Kind.INCOME) incomeCategories else categories
        return Result(
            amountToman = amount?.takeIf { it > 0 },
            kind = kind,
            banks = Bank.mentions(text),
            cash = cashWords.any { containsWord(text, it) },
            categoryId = if (kind == Kind.TRANSFER) null else matchCategory(text, pool),
            transcript = transcript.trim(),
        )
    }

    fun matchCategory(text: String, candidates: List<CategoryCandidate>): Long? {
        var best: CategoryCandidate? = null
        var bestScore = 0
        for (c in candidates) {
            val name = PersianText.normalize(c.name).lowercase()
            val score = when {
                containsWord(text, name) -> 3
                synonyms.any { (key, words) -> name.contains(key) && words.any { containsWord(text, it) } } -> 2
                else -> 0
            }
            if (score > bestScore) { best = c; bestScore = score }
        }
        return best?.id
    }

    private fun containsWord(text: String, word: String): Boolean {
        var from = 0
        while (true) {
            val i = text.indexOf(word, from)
            if (i < 0) return false
            val before = if (i == 0) ' ' else text[i - 1]
            val after = text.getOrElse(i + word.length) { ' ' }
            if (!before.isLetter() && !after.isLetter()) return true
            from = i + 1
        }
    }
}
