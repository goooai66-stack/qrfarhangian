package ir.hesabyar.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import ir.hesabyar.app.R

/** Vazirmatn UI, Farsi-digits build (OFL): every number renders as ۱۲۳ without string tricks. */
val Vazirmatn = FontFamily(
    Font(R.font.vazirmatn_regular, FontWeight.Normal),
    Font(R.font.vazirmatn_medium, FontWeight.Medium),
    Font(R.font.vazirmatn_bold, FontWeight.Bold),
)

private fun style(size: Int, weight: FontWeight, line: Int) =
    TextStyle(fontFamily = Vazirmatn, fontWeight = weight, fontSize = size.sp, lineHeight = line.sp)

val AppTypography = Typography(
    displaySmall = style(32, FontWeight.Bold, 44),     // balance
    headlineMedium = style(26, FontWeight.Bold, 36),   // amount being typed
    headlineSmall = style(22, FontWeight.Bold, 32),
    titleLarge = style(19, FontWeight.Bold, 28),
    titleMedium = style(16, FontWeight.Bold, 24),
    titleSmall = style(14, FontWeight.Medium, 22),
    bodyLarge = style(15, FontWeight.Normal, 24),
    bodyMedium = style(14, FontWeight.Normal, 22),
    bodySmall = style(12, FontWeight.Normal, 18),
    labelLarge = style(14, FontWeight.Medium, 20),
    labelMedium = style(12, FontWeight.Medium, 18),
    labelSmall = style(11, FontWeight.Medium, 16),
)
