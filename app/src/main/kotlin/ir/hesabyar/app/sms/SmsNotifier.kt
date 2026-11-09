package ir.hesabyar.app.sms

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import ir.hesabyar.app.MainActivity
import ir.hesabyar.app.R
import ir.hesabyar.app.data.local.entity.BankSmsEntity
import ir.hesabyar.app.data.local.entity.SmsStatus
import ir.hesabyar.domain.money.Money

class SmsNotifier(private val context: Context) {

    init {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, context.getString(R.string.channel_sms), NotificationManager.IMPORTANCE_DEFAULT)
            channel.description = context.getString(R.string.channel_sms_desc)
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    @SuppressLint("MissingPermission") // checked via areNotificationsEnabled() + SecurityException guard
    fun notifyPending(sms: BankSmsEntity) {
        val nm = NotificationManagerCompat.from(context)
        if (!nm.areNotificationsEnabled()) return
        val title = when {
            sms.status == SmsStatus.SELF_TRANSFER -> "انتقال بین حساب‌های شما"
            sms.isDebit -> "برداشت ${Money.formatTomanWithUnit(sms.amountRial)}"
            else -> "واریز ${Money.formatTomanWithUnit(sms.amountRial)}"
        }
        val open = PendingIntent.getActivity(
            context, sms.id.toInt(),
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(0xFF1B2A4A.toInt())
            .setContentTitle(title)
            .setContentText("${sms.bank.persianName} • برای انتخاب دسته‌بندی ضربه بزنید")
            .setContentIntent(open)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .build()
        try {
            nm.notify(NOTIFICATION_BASE + sms.id.toInt(), n)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS revoked between the check and notify — the dashboard card still shows it.
        }
    }

    private companion object {
        const val CHANNEL = "bank_sms"
        const val NOTIFICATION_BASE = 10_000
    }
}
