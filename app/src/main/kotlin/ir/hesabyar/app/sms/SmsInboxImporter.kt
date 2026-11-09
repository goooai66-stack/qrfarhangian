package ir.hesabyar.app.sms

import android.content.Context
import android.provider.Telephony

/** One-time import of recent bank SMS right after the user grants READ_SMS. */
class SmsInboxImporter(private val context: Context, private val ingestor: SmsIngestor) {

    suspend fun importRecent(days: Int = 7): Int {
        val since = System.currentTimeMillis() - days * 86_400_000L
        val projection = arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE, Telephony.Sms.DATE_SENT)
        var imported = 0
        context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI, projection, "${Telephony.Sms.DATE} >= ?", arrayOf(since.toString()),
            "${Telephony.Sms.DATE} ASC",
        )?.use { c ->
            val iAddr = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val iBody = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val iDate = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val iSent = c.getColumnIndexOrThrow(Telephony.Sms.DATE_SENT)
            while (c.moveToNext()) {
                val sent = c.getLong(iSent)
                val ts = if (sent > 0) sent else c.getLong(iDate)
                if (ingestor.ingest(c.getString(iAddr).orEmpty(), c.getString(iBody).orEmpty(), ts) != null) imported++
            }
        }
        return imported
    }
}
