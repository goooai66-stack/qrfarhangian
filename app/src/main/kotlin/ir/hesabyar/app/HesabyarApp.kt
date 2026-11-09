package ir.hesabyar.app

import android.app.Application
import android.content.Context
import ir.hesabyar.app.ads.AdsController
import ir.hesabyar.app.ads.FakeAdProvider
import ir.hesabyar.app.ads.NoAdProvider
import ir.hesabyar.app.ads.PolicedAdProvider
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.app.data.local.DatabaseSeeder
import ir.hesabyar.app.data.prefs.AppPreferences
import ir.hesabyar.app.data.remote.JsonRateSource
import ir.hesabyar.app.data.repository.RatesRepository
import ir.hesabyar.app.data.repository.TransactionRepository
import ir.hesabyar.app.sms.SmsInboxImporter
import ir.hesabyar.app.sms.SmsIngestor
import ir.hesabyar.app.sms.SmsNotifier
import ir.hesabyar.app.reminders.ReminderEngine
import ir.hesabyar.app.reminders.ReminderNotifier
import ir.hesabyar.app.reminders.ReminderScheduler
import ir.hesabyar.app.usecase.ConfirmBankSmsUseCase
import ir.hesabyar.app.usecase.DueUseCases
import ir.hesabyar.app.usecase.SavingsUseCases
import ir.hesabyar.domain.sms.BankSmsParser
import ir.hesabyar.domain.sms.SelfTransferDetector
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class HesabyarApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
        container.appScope.launch {
            DatabaseSeeder(container.db).seedIfEmpty()
            container.reminderScheduler.scheduleNext() // idempotent: (re)arms the one daily alarm
        }
    }
}

/**
 * Manual DI: a dozen singletons do not justify Hilt's build time and APK weight.
 * Everything heavy is lazy, so cold start only pays for what the first frame needs.
 */
class AppContainer(context: Context) {
    private val app = context.applicationContext

    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val db: AppDatabase by lazy { AppDatabase.build(app) }
    val prefs = AppPreferences(app)

    val transactions by lazy { TransactionRepository(db) }
    /** Feed URL comes from the build (gradle property `hesabyar.ratesUrl`); empty → manual rates only. */
    val rates by lazy { RatesRepository(db.rateDao(), BuildConfig.RATES_URL.takeIf { it.startsWith("https://") }?.let { JsonRateSource(it) }) }
    val savings by lazy { SavingsUseCases(db, transactions) }
    val confirmSms by lazy { ConfirmBankSmsUseCase(db, transactions) }

    val smsIngestor by lazy { SmsIngestor(db, BankSmsParser(), SelfTransferDetector()) }
    val smsImporter by lazy { SmsInboxImporter(app, smsIngestor) }
    val smsNotifier by lazy { SmsNotifier(app) }

    val reminderNotifier by lazy { ReminderNotifier(app) }
    val reminderEngine by lazy { ReminderEngine(db, prefs, reminderNotifier) }
    val reminderScheduler by lazy { ReminderScheduler(app) { prefs.reminderHour } }
    val dues by lazy { DueUseCases(db, transactions) { reminderEngine.runCheck() } }

    val ads by lazy {
        AdsController(PolicedAdProvider(if (BuildConfig.DEBUG) FakeAdProvider() else NoAdProvider), prefs)
    }
}

val Context.appContainer: AppContainer get() = (applicationContext as HesabyarApp).container
