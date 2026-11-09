package ir.hesabyar.app.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import ir.hesabyar.domain.due.ReminderPlanner

/**
 * Exactly one inexact, idle-safe alarm per day. No SCHEDULE_EXACT_ALARM permission needed
 * (it is restricted on Android 12+/14 and stores scrutinize it); a few minutes of drift at 9:00 is fine.
 */
class ReminderScheduler(private val context: Context, private val hour: () -> Int) {

    fun scheduleNext(now: Long = System.currentTimeMillis()) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = ReminderPlanner.nextCheckAt(now, hour())
        am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pendingIntent())
    }

    private fun pendingIntent(): PendingIntent = PendingIntent.getBroadcast(
        context, 1,
        Intent(context, ReminderReceiver::class.java).setAction(ReminderReceiver.ACTION_DAILY_CHECK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
