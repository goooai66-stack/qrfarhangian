package ir.hesabyar.app.ui.lock

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

/** Fingerprint / face unlock via androidx.biometric (works from Android 6). PIN is always the fallback. */
object Biometrics {

    fun available(context: Context): Boolean =
        BiometricManager.from(context).canAuthenticate(BIOMETRIC_WEAK) == BiometricManager.BIOMETRIC_SUCCESS

    fun prompt(activity: FragmentActivity, onSuccess: () -> Unit) {
        val prompt = BiometricPrompt(
            activity, ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onSuccess()
                // Errors / cancel: the PIN pad stays on screen — nothing to do.
            },
        )
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("ورود به حساب‌یار")
                .setSubtitle("اثر انگشت یا چهره")
                .setNegativeButtonText("استفاده از رمز")
                .setAllowedAuthenticators(BIOMETRIC_WEAK)
                .build(),
        )
    }
}
