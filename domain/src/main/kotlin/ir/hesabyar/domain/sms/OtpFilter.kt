package ir.hesabyar.domain.sms

/**
 * Detects one-time passwords and verification codes.
 *
 * Security rule: these messages are dropped *before* anything is persisted, so a database
 * backup can never contain a dynamic password. When in doubt, we drop the SMS: a missed
 * transaction can be entered by hand; a leaked OTP cannot be taken back.
 */
object OtpFilter {

    private val phrases = listOf(
        "رمز پویا", "رمز پویای", "رمزپویا",
        "رمز یکبار مصرف", "رمز یک بار مصرف", "رمز یکبارمصرف", "رمز یک‌بار مصرف",
        "رمز دوم", "رمز اینترنتی", "رمز موقت", "رمز عبور",
        "کد تایید", "کد تأیید", "کدتایید", "کد فعالسازی", "کد فعال سازی", "کد ورود",
        "کد امنیتی", "کد یکبار مصرف", "کد احراز", "کد اعتبارسنجی", "شناسه ورود",
        "otp", "one time password", "verification code", "passcode", "password",
    )

    /** "رمز: 123456", "کد 48213", "Code: 9931" … */
    private val codePattern = Regex(
        "(?:رمز|کد|code|pass)\\s*(?:شما|جدید)?\\s*[:：]?\\s*\\d{4,8}(?!\\d)",
        RegexOption.IGNORE_CASE,
    )

    fun isSecurityCode(normalizedBody: String): Boolean {
        val lower = normalizedBody.lowercase()
        if (phrases.any { lower.contains(it) }) return true
        return codePattern.containsMatchIn(lower)
    }
}
