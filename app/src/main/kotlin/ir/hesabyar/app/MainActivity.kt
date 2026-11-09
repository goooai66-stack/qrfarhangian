package ir.hesabyar.app

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.WindowManager
import androidx.activity.SystemBarStyle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import ir.hesabyar.app.ui.lock.Biometrics
import ir.hesabyar.app.ui.lock.LockScreen
import ir.hesabyar.app.ui.main.MainScreen
import ir.hesabyar.app.ui.main.Tab
import ir.hesabyar.app.ui.onboarding.PrivacyIntroScreen
import ir.hesabyar.app.ui.theme.HesabyarTheme
import kotlinx.coroutines.launch

/**
 * Cold start goes straight to the dashboard: no splash ad, no app-open ad, no sign-up.
 * With the app lock on, a PIN / fingerprint screen comes first — also ad-free — and the main UI
 * (and therefore any balance) is not even composed until it is passed.
 *
 * FragmentActivity (a ComponentActivity) is required by androidx.biometric's BiometricPrompt.
 */
class MainActivity : FragmentActivity() {

    /** Tab requested by a notification (cold start or onNewIntent). */
    private var requestedTab by mutableStateOf<Tab?>(null)
    private var locked by mutableStateOf(false)
    private var backgroundAt = 0L

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        requestedTab = tabFrom(intent)
    }

    private fun tabFrom(intent: Intent?): Tab? = when (intent?.getStringExtra(EXTRA_OPEN_TAB)) {
        TAB_DUE -> Tab.DUE
        else -> null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(statusBarStyle = SystemBarStyle.dark(android.graphics.Color.TRANSPARENT))
        super.onCreate(savedInstanceState)
        val container = appContainer
        requestedTab = tabFrom(intent)
        // Cold start → lock if enabled; rotation → keep whatever state we were in.
        locked = savedInstanceState?.getBoolean(STATE_LOCKED) ?: container.prefs.lockEnabled.value

        lifecycleScope.launch {
            container.prefs.secureScreen.collect { secure ->
                if (secure) window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }

        setContent {
            HesabyarTheme {
                var showIntro by remember { mutableStateOf(!container.prefs.onboardingDone) }
                val permissions = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
                    container.prefs.onboardingDone = true
                    showIntro = false
                    container.reminderScheduler.scheduleNext()
                    if (result[Manifest.permission.READ_SMS] == true) {
                        container.appScope.launch { container.smsImporter.importRecent(days = 7) }
                    }
                }
                when {
                    locked && container.prefs.pinHash != null -> {
                        val bio = container.prefs.biometricEnabled && Biometrics.available(this)
                        LockScreen(
                            prefs = container.prefs,
                            biometricAvailable = bio,
                            onBiometric = { Biometrics.prompt(this) { locked = false } },
                            onUnlocked = { locked = false },
                        )
                    }
                    showIntro -> PrivacyIntroScreen(
                        onEnableSms = {
                            val list = mutableListOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)
                            if (Build.VERSION.SDK_INT >= 33) list += Manifest.permission.POST_NOTIFICATIONS
                            permissions.launch(list.toTypedArray())
                        },
                        onSkip = { container.prefs.onboardingDone = true; showIntro = false },
                    )
                    else -> MainScreen(requestedTab = requestedTab, onTabRequestHandled = { requestedTab = null }, onExit = { finish() })
                }
            }
        }
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations) backgroundAt = SystemClock.elapsedRealtime()
    }

    override fun onStart() {
        super.onStart()
        val prefs = appContainer.prefs
        val timeout = prefs.lockTimeoutSec
        // -1 = lock only on cold start. The minimum of 30 s means returning from the file picker,
        // the speech recognizer or the share sheet never throws the user back to the lock screen.
        if (prefs.lockEnabled.value && backgroundAt > 0 && timeout >= 0 &&
            SystemClock.elapsedRealtime() - backgroundAt >= timeout * 1000L
        ) locked = true
        backgroundAt = 0
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean(STATE_LOCKED, locked)
    }

    companion object {
        const val EXTRA_OPEN_TAB = "open_tab"
        const val TAB_DUE = "due"
        private const val STATE_LOCKED = "locked"
    }
}
