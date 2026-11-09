package ir.hesabyar.app.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.calc.AmountExpression

sealed interface CalcKey {
    data class Digit(val d: Char) : CalcKey
    data object TripleZero : CalcKey
    data class Operator(val op: AmountExpression.Op) : CalcKey
    data object Backspace : CalcKey
    data object Clear : CalcKey
    data object Equals : CalcKey
}

fun AmountExpression.apply(key: CalcKey): AmountExpression = when (key) {
    is CalcKey.Digit -> appendDigit(key.d)
    CalcKey.TripleZero -> appendTripleZero()
    is CalcKey.Operator -> appendOperator(key.op)
    CalcKey.Backspace -> backspace()
    CalcKey.Clear -> clear()
    CalcKey.Equals -> collapse()
}

/**
 * Built-in numeric keyboard with + − × ÷ and «۰۰۰». Replaces the system keyboard for amounts:
 * no layout jump, no wrong-language digits, and the user can add up a receipt in place.
 * Long-press ⌫ clears. Laid out LTR (7-8-9 on top) like every calculator, inside the RTL app.
 */
@Composable
fun CalculatorKeyboard(onKey: (CalcKey) -> Unit, modifier: Modifier = Modifier) {
    val haptic = LocalHapticFeedback.current
    val press: (CalcKey) -> Unit = { haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove); onKey(it) }
    val op = MaterialTheme.colorScheme.primary
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(
            modifier
                .fillMaxWidth()
                .background(AppTheme.money.chipBg.copy(alpha = 0.6f))
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            KeyRow { Digit('7', press); Digit('8', press); Digit('9', press); OpKey("÷", AmountExpression.Op.DIVIDE, op, press) }
            KeyRow { Digit('4', press); Digit('5', press); Digit('6', press); OpKey("×", AmountExpression.Op.TIMES, op, press) }
            KeyRow { Digit('1', press); Digit('2', press); Digit('3', press); OpKey("−", AmountExpression.Op.MINUS, op, press) }
            KeyRow {
                Key("۰۰۰", onClick = { press(CalcKey.TripleZero) }, label = "سه صفر")
                Digit('0', press)
                Key(onClick = { press(CalcKey.Backspace) }, onLongClick = { press(CalcKey.Clear) }, label = "پاک کردن") {
                    Icon(AppIcons.Backspace, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface)
                }
                OpKey("+", AmountExpression.Op.PLUS, op, press)
            }
        }
    }
}

@Composable
private fun KeyRow(content: @Composable RowScope.() -> Unit) =
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp), content = content)

@Composable
private fun RowScope.Digit(d: Char, press: (CalcKey) -> Unit) =
    Key(text = ('۰' + (d - '0')).toString(), onClick = { press(CalcKey.Digit(d)) })

@Composable
private fun RowScope.OpKey(symbol: String, op: AmountExpression.Op, color: Color, press: (CalcKey) -> Unit) =
    Key(text = symbol, onClick = { press(CalcKey.Operator(op)) }, textColor = color, background = color.copy(alpha = 0.08f))

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun RowScope.Key(
    text: String? = null,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    label: String? = null,
    textColor: Color = MaterialTheme.colorScheme.onSurface,
    background: Color = MaterialTheme.colorScheme.surface,
    icon: (@Composable () -> Unit)? = null,
) {
    Box(
        Modifier
            .weight(1f)
            .height(52.dp)
            .clip(MaterialTheme.shapes.small)
            .background(background)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .semantics { if (label != null) contentDescription = label },
        contentAlignment = Alignment.Center,
    ) {
        if (icon != null) icon()
        else Text(text.orEmpty(), color = textColor, fontSize = 22.sp, fontWeight = FontWeight.Medium, style = MaterialTheme.typography.titleLarge)
    }
}

