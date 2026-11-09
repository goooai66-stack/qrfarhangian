package ir.hesabyar.domain.sms

/**
 * Iranian banks and neobanks.
 *
 * [nameKeywords] are matched against the *normalized* SMS body (see PersianText.normalize) and
 * against the sender id. Order matters: neobanks are declared before their parent banks
 * (Blu → Saman, Wepod → Pasargad) because their messages may also mention the parent.
 *
 * Sender short-codes are deliberately not hard-coded: they differ per operator and change over
 * time. Instead, when the user confirms the first SMS from a sender, the app stores
 * sender → account (see AccountEntity.smsSenderHint) and passes it to the parser as a hint.
 */
enum class Bank(val persianName: String, vararg val nameKeywords: String) {
    BLU("بلوبانک", "بلو بانک", "بلوبانک", "blu bank", "blubank", "بلو"),
    WEPOD("ویپاد", "ویپاد", "wepod"),
    BANKINO("بانکینو", "بانکینو", "bankino"),
    MELLI("بانک ملی", "بانک ملی", "ملی ایران", "bank melli", "bmi"),
    MELLAT("بانک ملت", "بانک ملت", "bank mellat", "mellat", "ملت"),
    SADERAT("بانک صادرات", "بانک صادرات", "صادرات ایران", "saderat", "bsi", "صادرات"),
    TEJARAT("بانک تجارت", "بانک تجارت", "tejarat", "تجارت"),
    SEPAH("بانک سپه", "بانک سپه", "sepah", "سپه"),
    PASARGAD("بانک پاسارگاد", "بانک پاسارگاد", "pasargad", "bpi", "پاسارگاد"),
    PARSIAN("بانک پارسیان", "بانک پارسیان", "parsian", "پارسیان"),
    SAMAN("بانک سامان", "بانک سامان", "saman", "sb24", "سامان"),
    MASKAN("بانک مسکن", "بانک مسکن", "maskan", "مسکن"),
    RESALAT("بانک رسالت", "قرض الحسنه رسالت", "بانک رسالت", "resalat", "رسالت"),
    KESHAVARZI("بانک کشاورزی", "بانک کشاورزی", "keshavarzi", "bki", "کشاورزی"),
    REFAH("بانک رفاه", "رفاه کارگران", "بانک رفاه", "refah", "رفاه"),
    MEHR_IRAN("بانک مهر ایران", "مهر ایران", "mehr iran", "qmb"),
    EGHTESAD_NOVIN("بانک اقتصاد نوین", "اقتصاد نوین", "eghtesad novin", "edbi"),
    AYANDEH("بانک آینده", "بانک آینده", "ayandeh", "آینده"),
    SHAHR("بانک شهر", "بانک شهر", "shahr bank", "city bank"),
    SINA("بانک سینا", "بانک سینا", "sina bank"),
    KARAFARIN("بانک کارآفرین", "کارآفرین", "karafarin"),
    DAY("بانک دی", "بانک دی", "day bank"),
    POST_BANK("پست بانک", "پست بانک", "postbank"),
    TOSEE_TAAVON("بانک توسعه تعاون", "توسعه تعاون", "ttbank"),
    SARMAYEH("بانک سرمایه", "بانک سرمایه", "sarmayeh"),
    KHAVARMIANEH("بانک خاورمیانه", "خاورمیانه", "middle east bank"),
    GARDESHGARI("بانک گردشگری", "گردشگری", "tourism bank"),
    IRAN_ZAMIN("بانک ایران زمین", "ایران زمین", "iran zamin"),
    UNKNOWN("بانک");

    companion object {
        /** Matches by explicit sender hint first, then by name keywords in sender + body. */
        fun detect(sender: String, normalizedBody: String, senderHints: Map<String, Bank> = emptyMap()): Bank {
            senderHints[sender.trim()]?.let { return it }
            val haystack = (sender + "\n" + normalizedBody).lowercase()
            for (bank in entries) {
                if (bank == UNKNOWN) continue
                if (bank.nameKeywords.any { kw -> containsWord(haystack, kw.lowercase()) }) return bank
            }
            return UNKNOWN
        }

        /**
         * Every bank named in [text] (normalized, lowercase), ordered by first position.
         * Used by voice input: «از ملت به بلو» → [MELLAT, BLU].
         */
        fun mentions(text: String): List<Bank> {
            val lower = text.lowercase()
            return entries.asSequence()
                .filter { it != UNKNOWN }
                .mapNotNull { bank ->
                    bank.nameKeywords.map { indexOfWord(lower, it.lowercase()) }.filter { it >= 0 }.minOrNull()?.let { it to bank }
                }
                .sortedBy { it.first }
                .map { it.second }
                .toList()
        }

        /** Whole-word contains: avoids matching "ملت" inside an unrelated longer word. */
        private fun containsWord(haystack: String, word: String): Boolean = indexOfWord(haystack, word) >= 0

        internal fun indexOfWord(haystack: String, word: String): Int {
            var from = 0
            while (true) {
                val idx = haystack.indexOf(word, from)
                if (idx < 0) return -1
                val before = if (idx == 0) ' ' else haystack[idx - 1]
                val afterIdx = idx + word.length
                val after = if (afterIdx >= haystack.length) ' ' else haystack[afterIdx]
                if (!before.isLetter() && !after.isLetter()) return idx
                from = idx + 1
            }
        }
    }
}
