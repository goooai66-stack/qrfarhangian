package ir.hesabyar.app.ui.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.ui.components.AppIcons
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Mint
import ir.hesabyar.app.ui.theme.Navy

/** First run only. No sign-up, no phone number: one honest promise, then straight to the app. */
@Composable
fun PrivacyIntroScreen(onEnableSms: () -> Unit, onSkip: () -> Unit) {
    Column(
        Modifier.fillMaxSize().background(Navy).statusBarsPadding().navigationBarsPadding().padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(AppIcons.Shield, contentDescription = null, tint = Gold, modifier = Modifier.size(56.dp))
        Spacer(Modifier.height(20.dp))
        Text("اطلاعات مالی شما فقط روی همین گوشی می‌ماند", color = Color.White, style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(16.dp))
        Bullet("بدون ثبت‌نام، بدون شماره موبایل و ایمیل.")
        Bullet("پیامک‌های بانکی فقط روی گوشی خودتان خوانده و پردازش می‌شوند؛ هیچ پیامک یا تراکنشی به هیچ سروری ارسال نمی‌شود.")
        Bullet("پیامک‌های رمز پویا و کد تایید کاملاً نادیده گرفته می‌شوند و هرگز ذخیره نمی‌شوند.")
        Bullet("اینترنت فقط برای دریافت نرخ طلا و ارز و نمایش تبلیغات استفاده می‌شود.")
        Spacer(Modifier.height(28.dp))
        Button(
            onClick = onEnableSms,
            colors = ButtonDefaults.buttonColors(containerColor = Gold, contentColor = Navy),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("فعال‌سازی ثبت خودکار از پیامک بانکی", style = MaterialTheme.typography.titleSmall) }
        TextButton(onClick = onSkip, modifier = Modifier.fillMaxWidth()) {
            Text("بعداً، می‌خواهم دستی ثبت کنم", color = Color.White.copy(alpha = 0.8f))
        }
    }
}

@Composable
private fun Bullet(text: String) {
    Row(Modifier.padding(vertical = 6.dp), verticalAlignment = Alignment.Top) {
        Text("✓", color = Mint, style = MaterialTheme.typography.titleSmall)
        Spacer(Modifier.width(10.dp))
        Text(text, color = Color.White.copy(alpha = 0.88f), style = MaterialTheme.typography.bodyMedium)
    }
}
