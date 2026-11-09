package ir.hesabyar.app.reminders

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import ir.hesabyar.app.MainActivity
import ir.hesabyar.app.R

/** High-importance channel with sound: «هشدار صوتی» for cheques and installments. */
class ReminderNotifier(private val context: Context) {

    init {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "یادآور سررسیدها", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "هشدار ۳ روز قبل، ۱ روز قبل و روز سررسید چک، قسط و طلب"
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build(),
                )
                enableVibration(true)
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    @SuppressLint("MissingPermission") // guarded by areNotificationsEnabled() + SecurityException
    fun show(r: Reminder) {
        val nm = NotificationManagerCompat.from(context)
        if (!nm.areNotificationsEnabled()) return
        val id = notificationId(r.kind, r.refId)
        val open = PendingIntent.getActivity(
            context, id,
            Intent(context, MainActivity::class.java).putExtra(MainActivity.EXTRA_OPEN_TAB, MainActivity.TAB_DUE).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFFC5A059.toInt())
            .setContentTitle(r.title)
            .setContentText(r.text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(r.text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(open)
            .setAutoCancel(true)

        when (r.kind) {
            ReminderKind.CHEQUE -> builder.addAction(0, "پاس شد", action(ReminderActionReceiver.ACTION_CHEQUE_CLEARED, r, id))
            ReminderKind.INSTALLMENT -> builder.addAction(0, "پرداخت شد", action(ReminderActionReceiver.ACTION_INSTALLMENT_PAID, r, id))
            ReminderKind.DEBT -> Unit
        }
        try { nm.notify(id, builder.build()) } catch (_: SecurityException) { }
    }

    fun cancel(kind: ReminderKind, refId: Long) = NotificationManagerCompat.from(context).cancel(notificationId(kind, refId))

    private fun action(action: String, r: Reminder, requestCode: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context, requestCode,
            Intent(context, ReminderActionReceiver::class.java).setAction(action).putExtra(ReminderActionReceiver.EXTRA_ID, r.refId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        const val CHANNEL = "due_reminders"
        /** One notification per item: a newer offset replaces the older one instead of stacking. */
        fun notificationId(kind: ReminderKind, refId: Long): Int = 20_000 + kind.ordinal * 1_000_000 + (refId % 1_000_000).toInt()
    }
}
