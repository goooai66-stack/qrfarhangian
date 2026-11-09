package ir.hesabyar.app.ui.components

import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.ui.platform.LocalContext
import ir.hesabyar.app.export.ExportedFile
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.domain.text.PersianText

/** After generating a file: share it (Telegram, Eitaa, WhatsApp, Drive…) or save it on the phone. */
@Composable
fun ExportResultDialog(file: ExportedFile, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val save = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(file.mime)) { uri ->
        if (uri != null) {
            val ok = runCatching { file.saveTo(context, uri) }.isSuccess
            Toast.makeText(context, if (ok) "فایل ذخیره شد" else "ذخیره انجام نشد", Toast.LENGTH_SHORT).show()
            if (ok) onDismiss()
        }
    }
    val kb = (file.bytes.size + 1023) / 1024
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("فایل آماده است") },
        text = {
            Column {
                Text(file.name, style = MaterialTheme.typography.bodyMedium)
                Text(PersianText.toPersianDigits("$kb کیلوبایت"), style = MaterialTheme.typography.bodySmall, color = AppTheme.money.muted)
            }
        },
        confirmButton = {
            Column {
                Button(onClick = { file.share(context); onDismiss() }, colors = ButtonDefaults.buttonColors(containerColor = Navy), modifier = Modifier.fillMaxWidth()) {
                    Text("ارسال (تلگرام، ایتا، واتساپ، درایو…)")
                }
                OutlinedButton(onClick = { save.launch(file.name) }, modifier = Modifier.fillMaxWidth()) { Text("ذخیره در حافظه گوشی") }
                TextButton(onClick = onDismiss, modifier = Modifier.fillMaxWidth()) { Text("بستن") }
            }
        },
    )
}
