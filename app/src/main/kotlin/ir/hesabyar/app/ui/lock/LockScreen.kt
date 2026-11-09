package ir.hesabyar.app.ui.lock

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.hesabyar.app.data.prefs.AppPreferences
import ir.hesabyar.app.ui.components.AppIcons
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.security.PinHasher
import ir.hesabyar.domain.text.PersianText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Ad-free lock (AdPolicy: LOCK_SCREEN). With biometrics enabled the system prompt opens
 * immediately, so unlocking is one touch; the PIN pad is always the fallback.
 */
@Composable
fun LockScreen(prefs: AppPreferences, biometricAvailable: Boolean, onBiometric: () -> Unit, onUnlocked: () -> Unit) {
    val scope = rememberCoroutineScope()
    var pin by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var checking by remember { mutableStateOf(false) }
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val policy = prefs.pinAttempts
    val lockedOut = policy.isLocked(now)

    LaunchedEffect(Unit) { if (biometricAvailable) onBiometric() }
    LaunchedEffect(lockedOut) { while (prefs.pinAttempts.isLocked(System.currentTimeMillis())) { delay(500); now = System.currentTimeMillis() }; now = System.currentTimeMillis() }

    fun submit(candidate: String) {
        val stored = prefs.pinHash ?: return onUnlocked()
        checking = true
        scope.launch {
            val ok = withContext(Dispatchers.Default) { PinHasher.verify(candidate, stored) }
            checking = false
            if (ok) {
                prefs.pinAttempts = prefs.pinAttempts.onSuccess()
                onUnlocked()
            } else {
                prefs.pinAttempts = prefs.pinAttempts.onFailure(System.currentTimeMillis())
                now = System.currentTimeMillis()
                pin = ""
                error = "رمز اشتباه است"
            }
        }
    }

    Column(
        Modifier.fillMaxSize().background(Navy).statusBarsPadding().navigationBarsPadding().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(AppIcons.Shield, contentDescription = null, tint = Gold, modifier = Modifier.size(52.dp))
        Spacer(Modifier.height(14.dp))
        Text("حساب‌یار", color = Color.White, style = MaterialTheme.typography.headlineSmall)
        Text("رمز ۴ رقمی را وارد کنید", color = Color.White.copy(alpha = 0.75f), style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            repeat(4) { i -> Box(Modifier.size(14.dp).clip(CircleShape).background(if (i < pin.length) Gold else Color.White.copy(alpha = 0.25f))) }
        }
        Spacer(Modifier.height(12.dp))
        val status = when {
            lockedOut -> PersianText.toPersianDigits("تلاش‌های نادرست زیاد؛ ${(policy.remainingMillis(now) + 999) / 1000} ثانیه صبر کنید")
            else -> error
        }
        Text(status.orEmpty(), color = Coral, style = MaterialTheme.typography.bodySmall, modifier = Modifier.height(20.dp))
        Spacer(Modifier.height(16.dp))

        val enabled = !lockedOut && !checking
        val onDigit: (Char) -> Unit = { d ->
            if (enabled && pin.length < 4) {
                error = null
                pin += d
                if (pin.length == 4) submit(pin)
            }
        }
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf("123", "456", "789").forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) { row.forEach { d -> PadKey(PersianText.toPersianDigits(d.toString())) { onDigit(d) } } }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(20.dp)) {
                    if (biometricAvailable) PadKey("👆", onClick = onBiometric) else Spacer(Modifier.size(68.dp))
                    PadKey("۰") { onDigit('0') }
                    PadKey("⌫") { if (pin.isNotEmpty()) pin = pin.dropLast(1) }
                }
            }
        }
    }
}

@Composable
private fun PadKey(label: String, onClick: () -> Unit) {
    Box(
        Modifier.size(68.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.08f)).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(label, color = Color.White, fontSize = 26.sp) }
}

