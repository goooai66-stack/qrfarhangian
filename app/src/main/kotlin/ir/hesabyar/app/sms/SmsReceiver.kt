package ir.hesabyar.app.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import ir.hesabyar.app.HesabyarApp
import kotlinx.coroutines.launch

/** Live capture. Runs off the main thread via goAsync(); never touches the network. */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        val container = (context.applicationContext as HesabyarApp).container
        val pending = goAsync()
        container.appScope.launch {
            try {
                // Multipart SMS arrive as several PDUs from the same sender: join them first.
                messages.groupBy { it.originatingAddress.orEmpty() }.forEach { (sender, parts) ->
                    val body = parts.joinToString("") { it.messageBody.orEmpty() }
                    val ts = parts.first().timestampMillis
                    container.smsIngestor.ingest(sender, body, ts)?.let { container.smsNotifier.notifyPending(it) }
                }
            } finally {
                pending.finish()
            }
        }
    }
}
