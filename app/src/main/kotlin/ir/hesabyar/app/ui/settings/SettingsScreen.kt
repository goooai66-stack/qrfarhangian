package ir.hesabyar.app.ui.settings

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.backup.BackupManager
import ir.hesabyar.app.export.ExportedFile
import ir.hesabyar.app.ui.common.formatWhen
import ir.hesabyar.app.ui.components.AppCard
import ir.hesabyar.app.ui.components.ExportResultDialog
import ir.hesabyar.app.ui.components.SwitchRow
import ir.hesabyar.app.ui.lock.Biometrics
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Coral
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.text.PersianText

/** Settings: security, backup/restore, reminders, new fiscal year. No ads on this page. */
@Composable
fun SettingsScreen(vm: SettingsViewModel, contentPadding: PaddingValues, onBack: () -> Unit) {
    val s by vm.state.collectAsStateWithLifecycle()
    val message by vm.message.collectAsStateWithLifecycle()
    val context = LocalContext.current

    var pinDialog by remember { mutableStateOf(false) }
    var backupDialog by remember { mutableStateOf(false) }
    var exported by remember { mutableStateOf<ExportedFile?>(null) }
    var restoreBytes by remember { mutableStateOf<ByteArray?>(null) }
    var restorePassword by remember { mutableStateOf<String?>(null) }
    var askRestorePassword by remember { mutableStateOf(false) }
    var restoreInfo by remember { mutableStateOf<BackupManager.Info?>(null) }
    var resetDialog by remember { mutableStateOf(false) }

    LaunchedEffect(message) { message?.let { Toast.makeText(context, it, Toast.LENGTH_LONG).show(); vm.consumeMessage() } }

    fun inspect(bytes: ByteArray, password: String?) {
        vm.inspect(bytes, password) { r ->
            r.onSuccess { restoreInfo = it; restorePassword = password }
                .onFailure { e ->
                    when (e) {
                        is BackupManager.BackupException.NeedsPassword -> askRestorePassword = true
                        else -> Toast.makeText(context, e.message ?: "فایل نامعتبر است", Toast.LENGTH_LONG).show()
                    }
                }
        }
    }
    val pickBackup = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val bytes = uri?.let { runCatching { context.contentResolver.openInputStream(it)?.use { s -> s.readBytes() } }.getOrNull() }
        if (bytes != null) { restoreBytes = bytes; inspect(bytes, null) }
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(bottom = contentPadding.calculateBottomPadding())) {
        Row(Modifier.padding(4.dp), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "بازگشت") }
            Text("تنظیمات", style = MaterialTheme.typography.titleLarge)
        }
        if (s.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
        Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {

            // ------------------------------------------------------------ security
            AppCard {
                Text("امنیت و حریم خصوصی", style = MaterialTheme.typography.titleMedium)
                SwitchRow(
                    "قفل برنامه با رمز ۴ رقمی", s.lockEnabled, { on -> if (on) pinDialog = true else vm.removePin() },
                    hint = "هنگام باز شدن برنامه رمز یا اثر انگشت خواسته می‌شود",
                )
                if (s.lockEnabled) {
                    TextButton(onClick = { pinDialog = true }) { Text("تغییر رمز") }
                    if (Biometrics.available(context)) SwitchRow("ورود با اثر انگشت / چهره", s.biometricEnabled, vm::setBiometric)
                    Text("قفل خودکار پس از خروج", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted, modifier = Modifier.padding(top = 8.dp))
                    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(30 to "۳۰ ثانیه", 60 to "۱ دقیقه", 300 to "۵ دقیقه", -1 to "فقط هنگام باز شدن").forEach { (sec, label) ->
                            FilterChip(selected = s.lockTimeoutSec == sec, onClick = { vm.setLockTimeout(sec) }, label = { Text(label) })
                        }
                    }
                }
                SwitchRow("پنهان کردن در برنامه‌های اخیر", s.secureScreen, vm::setSecureScreen, hint = "مبالغ در پیش‌نمایش برنامه‌های اخیر دیده نمی‌شوند و اسکرین‌شات گرفته نمی‌شود")
            }

            // ------------------------------------------------------------ backup
            AppCard {
                Text("پشتیبان‌گیری و بازیابی", style = MaterialTheme.typography.titleMedium)
                Text(
                    "همه‌ی اطلاعات در یک فایل؛ برای ارسال در تلگرام، ایتا، واتساپ یا ذخیره در گوگل درایو. هیچ نسخه‌ای خودکار به سروری فرستاده نمی‌شود.",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
                )
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { backupDialog = true }, enabled = !s.busy, colors = ButtonDefaults.buttonColors(containerColor = Navy), modifier = Modifier.weight(1f)) { Text("تهیه پشتیبان") }
                    OutlinedButton(onClick = { pickBackup.launch(arrayOf("*/*")) }, enabled = !s.busy, modifier = Modifier.weight(1f)) { Text("بازیابی از فایل") }
                }
            }

            // ------------------------------------------------------------ reminders
            AppCard {
                Text("ساعت یادآور روزانه سررسیدها", style = MaterialTheme.typography.titleMedium)
                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (7..21).forEach { h ->
                        FilterChip(selected = s.reminderHour == h, onClick = { vm.setReminderHour(h) }, label = { Text(PersianText.toPersianDigits("%02d:۰۰".format(h))) })
                    }
                }
            }

            // ------------------------------------------------------------ fiscal year
            AppCard {
                Text("شروع سال مالی جدید", style = MaterialTheme.typography.titleMedium)
                Text(
                    "تراکنش‌های دفتر «${s.ledger?.name.orEmpty()}» پاک می‌شود؛ حساب‌ها، دسته‌بندی‌ها، چک‌ها، اقساط، طلب‌ها و اهداف پس‌انداز باقی می‌مانند.",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
                )
                OutlinedButton(onClick = { resetDialog = true }, enabled = !s.busy, modifier = Modifier.padding(top = 8.dp)) { Text("شروع سال جدید…", color = Coral) }
            }

            AppCard {
                Text("درباره", style = MaterialTheme.typography.titleMedium)
                Text(
                    "حساب‌یار بدون ثبت‌نام و کاملاً روی گوشی کار می‌کند. پیامک‌ها و تراکنش‌ها هرگز به سروری ارسال نمی‌شوند؛ اینترنت فقط برای نرخ بازار و تبلیغات استفاده می‌شود.",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted,
                )
            }
        }
    }

    // ================================================================ dialogs
    if (pinDialog) PinSetupDialog(onDone = { vm.setPin(it); pinDialog = false }, onDismiss = { pinDialog = false })
    if (backupDialog) BackupDialog(onCreate = { pw -> backupDialog = false; vm.createBackup(pw) { exported = it } }, onDismiss = { backupDialog = false })
    exported?.let { f -> ExportResultDialog(f) { exported = null } }
    if (askRestorePassword) {
        PasswordDialog(
            title = "رمز فایل پشتیبان",
            onOk = { pw -> askRestorePassword = false; restoreBytes?.let { inspect(it, pw) } },
            onDismiss = { askRestorePassword = false; restoreBytes = null },
        )
    }
    restoreInfo?.let { info ->
        AlertDialog(
            onDismissRequest = { restoreInfo = null; restoreBytes = null },
            title = { Text("بازیابی نسخه پشتیبان؟") },
            text = {
                Text(
                    PersianText.toPersianDigits(
                        "تاریخ پشتیبان: ${formatWhen(info.createdAt)}\n" +
                            "${info.counts["transactions"] ?: 0} تراکنش، ${info.counts["accounts"] ?: 0} حساب، ${info.counts["cheques"] ?: 0} چک\n\n" +
                            "تمام اطلاعات فعلی گوشی با این نسخه جایگزین می‌شود.",
                    ),
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    restoreBytes?.let { vm.restore(it, restorePassword) }
                    restoreInfo = null; restoreBytes = null; restorePassword = null
                }) { Text("جایگزین کن", color = Coral) }
            },
            dismissButton = { TextButton(onClick = { restoreInfo = null; restoreBytes = null }) { Text("انصراف") } },
        )
    }
    if (resetDialog) ResetDialog(s.ledger?.name.orEmpty(), onBackupFirst = { resetDialog = false; backupDialog = true }, onConfirm = { carry -> resetDialog = false; vm.resetFiscalYear(carry) }, onDismiss = { resetDialog = false })
}

@Composable
private fun PinSetupDialog(onDone: (String) -> Unit, onDismiss: () -> Unit) {
    var first by remember { mutableStateOf("") }
    var second by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("تعیین رمز ۴ رقمی") },
        text = {
            Column {
                PinField("رمز", first) { first = it }
                PinField("تکرار رمز", second) { second = it }
                error?.let { Text(it, color = AppTheme.money.expense, style = MaterialTheme.typography.bodySmall) }
                Text("اگر رمز را فراموش کنید، فقط با اثر انگشت یا نصب دوباره (و بازیابی پشتیبان) وارد می‌شوید.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
            }
        },
        confirmButton = {
            TextButton(onClick = {
                error = when {
                    first.length != 4 -> "رمز باید ۴ رقم باشد"
                    first != second -> "تکرار رمز یکسان نیست"
                    else -> null
                }
                if (error == null) onDone(first)
            }) { Text("ذخیره") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

@Composable
private fun PinField(label: String, value: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value, onValueChange = { onChange(PersianText.toLatinDigits(it).filter(Char::isDigit).take(4)) },
        label = { Text(label) }, singleLine = true, visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
    )
}

@Composable
private fun BackupDialog(onCreate: (String?) -> Unit, onDismiss: () -> Unit) {
    var encrypt by remember { mutableStateOf(true) }
    var pw by remember { mutableStateOf("") }
    var pw2 by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("تهیه نسخه پشتیبان") },
        text = {
            Column {
                SwitchRow("رمزگذاری فایل (توصیه می‌شود)", encrypt, { encrypt = it }, hint = "AES-256؛ بدون رمز هیچ‌کس فایل را باز نمی‌کند — حتی ما")
                if (encrypt) {
                    OutlinedTextField(pw, { pw = it }, label = { Text("رمز (حداقل ۶ نویسه)") }, singleLine = true, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
                    OutlinedTextField(pw2, { pw2 = it }, label = { Text("تکرار رمز") }, singleLine = true, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
                    Text("این رمز قابل بازیابی نیست؛ آن را جایی امن یادداشت کنید.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.expense)
                } else {
                    Text("فایل بدون رمز شامل همه‌ی تراکنش‌ها و پیامک‌های بانکی است؛ آن را فقط برای خودتان بفرستید.", style = MaterialTheme.typography.bodySmall, color = AppTheme.money.expense)
                }
                error?.let { Text(it, color = AppTheme.money.expense, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                error = when {
                    !encrypt -> null
                    pw.length < 6 -> "رمز باید حداقل ۶ نویسه باشد"
                    pw != pw2 -> "تکرار رمز یکسان نیست"
                    else -> null
                }
                if (error == null) onCreate(if (encrypt) pw else null)
            }) { Text("ساخت فایل") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

@Composable
private fun PasswordDialog(title: String, onOk: (String) -> Unit, onDismiss: () -> Unit) {
    var pw by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { OutlinedTextField(pw, { pw = it }, label = { Text("رمز") }, singleLine = true, visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth()) },
        confirmButton = { TextButton(onClick = { onOk(pw) }, enabled = pw.isNotEmpty()) { Text("ادامه") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}

@Composable
private fun ResetDialog(ledgerName: String, onBackupFirst: () -> Unit, onConfirm: (carryOver: Boolean) -> Unit, onDismiss: () -> Unit) {
    var carry by remember { mutableStateOf(false) }
    var backedUp by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("شروع سال مالی جدید") },
        text = {
            Column {
                Text("همه‌ی تراکنش‌های دفتر «$ledgerName» حذف می‌شود و قابل برگشت نیست (مگر از نسخه پشتیبان).", style = MaterialTheme.typography.bodyMedium)
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = !carry, onClick = { carry = false }); Text("صفر کردن موجودی همه‌ی حساب‌ها")
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = carry, onClick = { carry = true }); Text("انتقال موجودی فعلی به‌عنوان موجودی اول دوره")
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = backedUp, onCheckedChange = { backedUp = it }); Text("از اطلاعات پشتیبان گرفته‌ام")
                }
                TextButton(onClick = onBackupFirst) { Text("اول پشتیبان بگیر") }
            }
        },
        confirmButton = { TextButton(onClick = { onConfirm(carry) }, enabled = backedUp) { Text("شروع سال جدید", color = if (backedUp) Coral else AppTheme.money.muted) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("انصراف") } },
    )
}
