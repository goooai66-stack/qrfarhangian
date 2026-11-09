package ir.hesabyar.app.export

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File

/** A generated report/backup held in memory until the user shares or saves it. */
class ExportedFile(val name: String, val mime: String, val bytes: ByteArray) {

    /** Share sheet: Telegram, Eitaa, WhatsApp, Google Drive, e-mail… via a private FileProvider URI. */
    fun share(context: Context, chooserTitle: String = "ارسال فایل") {
        val dir = File(context.cacheDir, "share").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() } // never accumulate financial files in cache
        val file = File(dir, name).apply { writeBytes(bytes) }
        val uri = FileProvider.getUriForFile(context, context.packageName + ".files", file)
        val send = Intent(Intent.ACTION_SEND).setType(mime).putExtra(Intent.EXTRA_STREAM, uri)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(Intent.createChooser(send, chooserTitle).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /** Writes to a location picked with the system file picker (no storage permission needed). */
    fun saveTo(context: Context, uri: Uri) {
        context.contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) } ?: error("cannot open destination")
    }

    companion object {
        const val MIME_XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        const val MIME_PDF = "application/pdf"
    }
}
