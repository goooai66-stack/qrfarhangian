package ir.hesabyar.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp

private val LightScheme = lightColorScheme(
    primary = Navy, onPrimary = CardWhite, primaryContainer = NavyLight, onPrimaryContainer = CardWhite,
    secondary = Mint, onSecondary = CardWhite, secondaryContainer = Mint.copy(alpha = 0.14f), onSecondaryContainer = MintDeep,
    tertiary = Gold, onTertiary = Navy, tertiaryContainer = Gold.copy(alpha = 0.16f), onTertiaryContainer = Navy,
    error = Coral, onError = CardWhite, errorContainer = Coral.copy(alpha = 0.12f), onErrorContainer = CoralDeep,
    background = Beige, onBackground = Ink, surface = CardWhite, onSurface = Ink,
    surfaceVariant = BeigeDeep, onSurfaceVariant = InkSoft, outline = Hairline, outlineVariant = Hairline,
    surfaceContainerLowest = CardWhite, surfaceContainerLow = CardWhite, surfaceContainer = Beige,
    surfaceContainerHigh = CardWhite, surfaceContainerHighest = BeigeDeep,
)

private val DarkScheme = darkColorScheme(
    primary = Gold, onPrimary = NightBg, primaryContainer = Navy, onPrimaryContainer = NightInk,
    secondary = Mint, onSecondary = NightBg, tertiary = Gold, onTertiary = NightBg,
    error = Coral, onError = NightBg,
    background = NightBg, onBackground = NightInk, surface = NightCard, onSurface = NightInk,
    surfaceVariant = Navy, onSurfaceVariant = NightInkSoft, outline = NightHairline, outlineVariant = NightHairline,
    surfaceContainerLowest = NightCard, surfaceContainerLow = NightCard, surfaceContainer = NightBg,
    surfaceContainerHigh = NightCard, surfaceContainerHighest = Navy,
)

val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(28.dp),
)

@Composable
fun HesabyarTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    // RTL is forced regardless of device locale: many Iranian phones run an English system UI.
    CompositionLocalProvider(
        LocalLayoutDirection provides LayoutDirection.Rtl,
        LocalMoneyColors provides if (dark) DarkMoneyColors else LightMoneyColors,
    ) {
        MaterialTheme(
            colorScheme = if (dark) DarkScheme else LightScheme,
            typography = AppTypography,
            shapes = AppShapes,
            content = content,
        )
    }
}

object AppTheme {
    val money: MoneyColors @Composable get() = LocalMoneyColors.current
}
