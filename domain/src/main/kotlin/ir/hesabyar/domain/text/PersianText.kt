package ir.hesabyar.domain.text

/**
 * Text normalization shared by the SMS parser, search and voice input.
 *
 * Iranian bank SMS arrive in every possible encoding mix: Persian digits (۱۲۳), Arabic-Indic
 * digits (١٢٣), Arabic Yeh/Kaf (ي ك), Arabic thousands separator (٬), invisible bidi marks
 * and ZWNJ. Everything is folded to one canonical form before any regex runs.
 */
object PersianText {

    private const val PERSIAN_ZERO = '۰'
    private const val ARABIC_ZERO = '٠'

    fun normalize(input: String): String {
        val sb = StringBuilder(input.length)
        for (ch in input) {
            when (ch) {
                in '۰'..'۹' -> sb.append('0' + (ch - PERSIAN_ZERO))
                in '٠'..'٩' -> sb.append('0' + (ch - ARABIC_ZERO))
                'ي', 'ى' -> sb.append('ی')   // Arabic Yeh / Alef Maksura
                'ك' -> sb.append('ک')             // Arabic Kaf
                'ة' -> sb.append('ه')             // Teh Marbuta
                'أ', 'إ' -> sb.append('ا')   // Alef with hamza
                '٬', '،', '，' -> sb.append(',') // ٬ ، ，
                '٫' -> sb.append('.')             // Arabic decimal separator
                '：' -> sb.append(':')
                '‌', ' ' -> sb.append(' ')   // ZWNJ, NBSP
                '‎', '‏', '‪', '‫', '‬', '‭', '‮',
                '⁦', '⁧', '⁨', '⁩', '﻿', 'ً', 'ٌ',
                'ٍ', 'َ', 'ُ', 'ِ', 'ّ', 'ْ' -> Unit // bidi marks, harakat
                '\r' -> Unit
                else -> sb.append(ch)
            }
        }
        // Collapse runs of spaces/tabs but keep line breaks: bank SMS are line-structured.
        return sb.toString()
            .replace(Regex("[ \\t]+"), " ")
            .lines()
            .joinToString("\n") { it.trim() }
            .trim()
    }

    /** Latin digits → Persian digits, for display only. */
    fun toPersianDigits(input: String): String {
        val sb = StringBuilder(input.length)
        for (ch in input) {
            if (ch in '0'..'9') sb.append(PERSIAN_ZERO + (ch - '0')) else sb.append(ch)
        }
        return sb.toString()
    }

    /** Persian/Arabic digits → Latin digits, keeping everything else. */
    fun toLatinDigits(input: String): String {
        val sb = StringBuilder(input.length)
        for (ch in input) {
            when (ch) {
                in '۰'..'۹' -> sb.append('0' + (ch - PERSIAN_ZERO))
                in '٠'..'٩' -> sb.append('0' + (ch - ARABIC_ZERO))
                else -> sb.append(ch)
            }
        }
        return sb.toString()
    }
}
