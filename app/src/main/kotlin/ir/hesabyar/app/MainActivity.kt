package ir.hesabyar.app

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import ir.hesabyar.app.ui.main.MainScreen
import ir.hesabyar.app.ui.main.Tab
import ir.hesabyar.app.ui.onboarding.PrivacyIntroScreen
import ir.hesabyar.app.ui.theme.HesabyarTheme
import kotlinx.coroutines.launch

/**
 * Cold start goes straight to the dashboard: no splash ad, no app-open ad, no sign-up.
 * (Biometric/PIN lock is added in step 5 as a lightweight overlay, still ad-free.)
 */
class MainActivity : ComponentActivity() {

    /** Tab requested by a notification (cold start or onNewIntent). */
    private var requestedTab by mutableStateOf<Tab?>(null)

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
                if (showIntro) {
                    PrivacyIntroScreen(
                        onEnableSms = {
                            val list = mutableListOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)
                            if (Build.VERSION.SDK_INT >= 33) list += Manifest.permission.POST_NOTIFICATIONS
                            permissions.launch(list.toTypedArray())
                        },
                        onSkip = { container.prefs.onboardingDone = true; showIntro = false },
                    )
                } else {
                    MainScreen(requestedTab = requestedTab, onTabRequestHandled = { requestedTab = null }, onExit = { finish() })
                }
            }
        }
    }

    companion object {
        const val EXTRA_OPEN_TAB = "open_tab"
        const val TAB_DUE = "due"
    }
}
