package ir.hesabyar.app.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ir.hesabyar.app.AppContainer
import ir.hesabyar.app.backup.BackupManager
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.export.ExportedFile
import ir.hesabyar.domain.security.PinHasher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class SettingsState(
    val lockEnabled: Boolean = false,
    val biometricEnabled: Boolean = false,
    val lockTimeoutSec: Int = 30,
    val secureScreen: Boolean = false,
    val reminderHour: Int = 9,
    val ledger: LedgerEntity? = null,
    val busy: Boolean = false,
)

class SettingsViewModel(private val c: AppContainer) : ViewModel() {

    /** busy flag + a version counter bumped after every plain-preference change. */
    private data class Local(val busy: Boolean = false, val version: Int = 0)
    private val local = MutableStateFlow(Local())

    val state: StateFlow<SettingsState> = combine(local, c.prefs.lockEnabled, c.prefs.secureScreen, c.db.ledgerDao().observeAll(), c.prefs.activeLedgerId) { l, lock, secure, ledgers, active ->
        SettingsState(
            busy = l.busy,
            lockEnabled = lock, biometricEnabled = c.prefs.biometricEnabled, lockTimeoutSec = c.prefs.lockTimeoutSec,
            secureScreen = secure, reminderHour = c.prefs.reminderHour,
            ledger = ledgers.firstOrNull { it.id == active } ?: ledgers.firstOrNull(),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), SettingsState())

    private fun refresh() { local.value = local.value.copy(version = local.value.version + 1) }

    // ---------------------------------------------------------------- lock
    fun setPin(pin: String) = viewModelScope.launch {
        val hashed = withContext(Dispatchers.Default) { PinHasher.hash(pin) }
        c.prefs.pinHash = hashed
        c.prefs.pinAttempts = c.prefs.pinAttempts.onSuccess()
        refresh()
    }
    fun removePin() { c.prefs.pinHash = null; refresh() }
    fun setBiometric(on: Boolean) { c.prefs.biometricEnabled = on; refresh() }
    fun setLockTimeout(sec: Int) { c.prefs.lockTimeoutSec = sec; refresh() }
    fun setSecureScreen(on: Boolean) = c.prefs.setSecureScreen(on)

    // ---------------------------------------------------------------- reminders
    fun setReminderHour(h: Int) { c.prefs.reminderHour = h; c.reminderScheduler.scheduleNext(); refresh() }

    // ---------------------------------------------------------------- backup
    private val _message = MutableStateFlow<String?>(null)
    val message: StateFlow<String?> = _message.asStateFlow()
    fun consumeMessage() { _message.value = null }

    private fun busy(on: Boolean) { local.value = local.value.copy(busy = on) }


    fun createBackup(password: String?, onReady: (ExportedFile) -> Unit) = viewModelScope.launch {
        busy(true)
        runCatching {
            val bytes = c.backup.create(password?.toCharArray())
            val encrypted = !password.isNullOrEmpty()
            ExportedFile(BackupManager.fileName(encrypted), if (encrypted) BackupManager.MIME_ENCRYPTED else BackupManager.MIME_JSON, bytes)
        }.onSuccess(onReady).onFailure { _message.value = "ساخت نسخه پشتیبان انجام نشد" }
        busy(false)
    }

    /** Validates (and decrypts) without writing; the UI then asks for a final confirmation. */
    fun inspect(bytes: ByteArray, password: String?, onResult: (Result<BackupManager.Info>) -> Unit) = viewModelScope.launch {
        busy(true)
        onResult(runCatching { c.backup.inspect(bytes, password?.toCharArray()) })
        busy(false)
    }

    fun restore(bytes: ByteArray, password: String?) = viewModelScope.launch {
        busy(true)
        _message.value = runCatching { c.backup.restore(bytes, password?.toCharArray()) }
            .fold({ c.reminderScheduler.scheduleNext(); "بازیابی کامل شد" }, { (it as? BackupManager.BackupException)?.message ?: "بازیابی انجام نشد؛ اطلاعات فعلی دست‌نخورده باقی ماند" })
        busy(false)
    }

    // ---------------------------------------------------------------- fiscal year
    fun resetFiscalYear(carryOver: Boolean) = viewModelScope.launch {
        val l = state.value.ledger ?: return@launch
        busy(true)
        _message.value = runCatching { c.fiscalYearReset(l.id, carryOver) }.fold({ "سال مالی جدید برای «${l.name}» شروع شد" }, { "عملیات انجام نشد" })
        busy(false)
    }
}
