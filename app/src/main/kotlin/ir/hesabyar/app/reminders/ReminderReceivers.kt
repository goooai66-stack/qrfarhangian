package ir.hesabyar.app.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import ir.hesabyar.app.appContainer
import kotlinx.coroutines.launch

/** Daily alarm + boot/time-change: run the check, then arm tomorrow's alarm. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val c = context.appContainer
        val pending = goAsync()
        c.appScope.launch {
            try {
                c.reminderEngine.runCheck()
            } finally {
                c.reminderScheduler.scheduleNext()
                pending.finish()
            }
        }
    }

    companion object { const val ACTION_DAILY_CHECK = "ir.hesabyar.app.DAILY_DUE_CHECK" }
}

/** «پاس شد» / «پرداخت شد» straight from the notification — no need to open the app. */
class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getLongExtra(EXTRA_ID, -1).takeIf { it > 0 } ?: return
        val c = context.appContainer
        val pending = goAsync()
        c.appScope.launch {
            try {
                when (intent.action) {
                    ACTION_CHEQUE_CLEARED -> { c.dues.clearCheque(id); c.reminderNotifier.cancel(ReminderKind.CHEQUE, id) }
                    ACTION_INSTALLMENT_PAID -> { c.dues.payInstallment(id); c.reminderNotifier.cancel(ReminderKind.INSTALLMENT, id) }
                }
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val ACTION_CHEQUE_CLEARED = "ir.hesabyar.app.CHEQUE_CLEARED"
        const val ACTION_INSTALLMENT_PAID = "ir.hesabyar.app.INSTALLMENT_PAID"
        const val EXTRA_ID = "id"
    }
}
