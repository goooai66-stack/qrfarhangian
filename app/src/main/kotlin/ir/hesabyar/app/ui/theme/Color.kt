package ir.hesabyar.app.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// Brand palette
val Beige = Color(0xFFF9F6F0)        // main background — warm, low eye strain
val BeigeDeep = Color(0xFFF1ECE2)    // pressed / track / divider surfaces
val Navy = Color(0xFF1B2A4A)         // primary, headers
val NavyLight = Color(0xFF2A3D66)
val Mint = Color(0xFF3EB489)         // success / income (fills)
val MintDeep = Color(0xFF2E8B57)     // income text on light backgrounds (contrast ≥ 4.5)
val Gold = Color(0xFFC5A059)         // accent, gold & premium elements
val Coral = Color(0xFFE05A47)        // expense / danger
val CoralDeep = Color(0xFFC2412F)    // expense text on light backgrounds
val Ink = Color(0xFF1F2430)
val InkSoft = Color(0xFF6B7280)
val CardWhite = Color(0xFFFFFFFF)
val Hairline = Color(0xFFE9E3D7)

// Dark
val NightBg = Color(0xFF0F1524)
val NightCard = Color(0xFF182036)
val NightHairline = Color(0xFF2A3350)
val NightInk = Color(0xFFE8EAF0)
val NightInkSoft = Color(0xFF9AA3B5)

/** Semantic money colours that Material's scheme has no slot for. */
@Immutable
data class MoneyColors(
    val income: Color,
    val expense: Color,
    val transfer: Color,
    val gold: Color,
    val hairline: Color,
    val muted: Color,
    val chipBg: Color,
)

val LightMoneyColors = MoneyColors(MintDeep, CoralDeep, Navy, Gold, Hairline, InkSoft, BeigeDeep)
val DarkMoneyColors = MoneyColors(Mint, Coral, Color(0xFF9DB4E6), Gold, NightHairline, NightInkSoft, Color(0xFF222B45))

val LocalMoneyColors = staticCompositionLocalOf { LightMoneyColors }
