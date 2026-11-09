package ir.hesabyar.app.reminders

import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.entity.ChequeDirection
import ir.hesabyar.app.data.local.entity.DebtDirection
import ir.hesabyar.app.data.prefs.AppPreferences
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.due.ReminderPlanner
import ir.hesabyar.domain.money.Money

enum class ReminderKind { CHEQUE, INSTALLMENT, DEBT }

data class Reminder(
    /** Stable de-dup key: kind:id:dueDay:offset. */
    val key: String,
    val kind: ReminderKind,
    val refId: Long,
    val title: String,
    val text: String,
    val offset: Int,
)

/**
 * The once-a-day check. Pure read of the DB + notification; no ads can ever be attached here
 * (AdPolicy: DUE_REMINDER_ALERT is an ad-free surface, and notifications have no ad slot at all).
 */
class ReminderEngine(
    private val db: AppDatabase,
    private val prefs: AppPreferences,
    private val notifier: ReminderNotifier,
) {
    private val dao = db.planningDao()

    suspend fun collect(now: Long = System.currentTimeMillis()): List<Reminder> {
        val today = JalaliDate.fromEpochMillis(now).toEpochDay()
        val from = today + ReminderPlanner.OFFSETS.min()
        val to = today + ReminderPlanner.OFFSETS.max()
        val out = mutableListOf<Reminder>()

        dao.chequesDueBetween(from, to).forEach { c ->
            val offset = ReminderPlanner.offsetFor(today, c.dueEpochDay) ?: return@forEach
            val received = c.direction == ChequeDirection.RECEIVED
            out += Reminder(
                key = "C:${c.id}:${c.dueEpochDay}:$offset", kind = ReminderKind.CHEQUE, refId = c.id, offset = offset,
                title = "${if (received) "وصول چک" else "پرداخت چک"} • ${ReminderPlanner.label(offset)}",
                text = "${Money.formatTomanWithUnit(c.amountRial)} ${if (received) "از" else "به"} ${c.counterpartyName} — ${dateLabel(c.dueEpochDay)}" +
                    if (!received) " • موجودی حساب را چک کنید" else "",
            )
        }
        dao.installmentsDueBetween(from, to).forEach { row ->
            val i = row.installment
            val offset = ReminderPlanner.offsetFor(today, i.dueEpochDay) ?: return@forEach
            out += Reminder(
                key = "I:${i.id}:${i.dueEpochDay}:$offset", kind = ReminderKind.INSTALLMENT, refId = i.id, offset = offset,
                title = "قسط ${row.loanTitle} • ${ReminderPlanner.label(offset)}",
                text = "قسط ${fa(i.number)} از ${fa(row.totalInstallments)} — ${Money.formatTomanWithUnit(i.amountRial)} — ${dateLabel(i.dueEpochDay)}",
            )
        }
        dao.debtsDueBetween(from, to).forEach { row ->
            val d = row.debt
            val due = d.dueEpochDay ?: return@forEach
            val offset = ReminderPlanner.offsetFor(today, due) ?: return@forEach
            val left = d.amountRial - d.settledRial
            val theyOwe = d.direction == DebtDirection.THEY_OWE_ME
            out += Reminder(
                key = "D:${d.id}:$due:$offset", kind = ReminderKind.DEBT, refId = d.id, offset = offset,
                title = "${if (theyOwe) "طلب از" else "بدهی به"} ${row.personName} • ${ReminderPlanner.label(offset)}",
                text = Money.formatTomanWithUnit(left) + (if (d.note.isNotBlank()) " — ${d.note}" else ""),
            )
        }
        return out
    }

    /** Posts every reminder not yet shown. Safe to call any number of times. */
    suspend fun runCheck(now: Long = System.currentTimeMillis()): Int {
        val today = JalaliDate.fromEpochMillis(now).toEpochDay()
        var posted = 0
        collect(now).forEach { r ->
            if (prefs.wasNotified(r.key)) return@forEach
            notifier.show(r)
            prefs.markNotified(r.key, today)
            posted++
        }
        return posted
    }

    private fun dateLabel(epochDay: Long) = JalaliDate.fromEpochDay(epochDay).formatLong()
    private fun fa(n: Int) = ir.hesabyar.domain.text.PersianText.toPersianDigits(n.toString())
}
