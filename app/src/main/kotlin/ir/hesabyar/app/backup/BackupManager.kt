package ir.hesabyar.app.backup

import android.content.ContentValues
import android.database.Cursor
import ir.hesabyar.app.BuildConfig
import ir.hesabyar.app.data.local.AppDatabase
import ir.hesabyar.domain.calendar.JalaliDate
import ir.hesabyar.domain.security.BackupCrypto
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * Full-fidelity backup of every table as JSON, optionally sealed with [BackupCrypto]
 * (AES-256-GCM). Table-generic on purpose: new columns are picked up automatically, and a backup
 * from an older schema restores into a newer app (missing columns take their defaults).
 *
 * Restore is all-or-nothing inside one SQLite transaction and only starts after the file has been
 * fully decrypted, parsed and validated — a bad file can never leave the books half-replaced.
 */
class BackupManager(private val db: AppDatabase) {

    data class Info(val createdAt: Long, val appVersion: String, val counts: Map<String, Int>, val encrypted: Boolean)

    sealed class BackupException(message: String) : Exception(message) {
        class NeedsPassword : BackupException("این فایل رمزگذاری شده است؛ رمز را وارد کنید")
        class WrongPassword : BackupException("رمز اشتباه است یا فایل آسیب دیده")
        class NotABackup : BackupException("این فایل نسخه پشتیبان حساب‌یار نیست")
        class TooNew : BackupException("این پشتیبان با نسخه جدیدتر برنامه ساخته شده؛ ابتدا برنامه را به‌روز کنید")
    }

    suspend fun create(password: CharArray?): ByteArray = withContext(Dispatchers.IO) {
        val sdb = db.openHelper.readableDatabase
        val tablesJson = JSONObject()
        for (table in TABLES) {
            val rows = JSONArray()
            sdb.query("SELECT * FROM `$table`").use { c ->
                while (c.moveToNext()) {
                    val o = JSONObject()
                    for (i in 0 until c.columnCount) {
                        val name = c.getColumnName(i)
                        when (c.getType(i)) {
                            Cursor.FIELD_TYPE_NULL -> o.put(name, JSONObject.NULL)
                            Cursor.FIELD_TYPE_INTEGER -> o.put(name, c.getLong(i))
                            Cursor.FIELD_TYPE_FLOAT -> o.put(name, c.getDouble(i))
                            Cursor.FIELD_TYPE_STRING -> o.put(name, c.getString(i))
                            else -> Unit // no BLOB columns in this schema
                        }
                    }
                    rows.put(o)
                }
            }
            tablesJson.put(table, rows)
        }
        val root = JSONObject()
            .put("format", FORMAT).put("schemaVersion", SCHEMA_VERSION)
            .put("appVersion", BuildConfig.VERSION_NAME).put("createdAt", System.currentTimeMillis())
            .put("tables", tablesJson)
        val bytes = root.toString().toByteArray(Charsets.UTF_8)
        if (password != null && password.isNotEmpty()) BackupCrypto.encrypt(bytes, password) else bytes
    }

    /** Decrypts + validates without touching the database. */
    suspend fun inspect(data: ByteArray, password: CharArray?): Info = withContext(Dispatchers.Default) {
        val (root, encrypted) = open(data, password)
        val tables = root.getJSONObject("tables")
        Info(
            createdAt = root.optLong("createdAt"),
            appVersion = root.optString("appVersion"),
            counts = TABLES.associateWith { tables.optJSONArray(it)?.length() ?: 0 },
            encrypted = encrypted,
        )
    }

    suspend fun restore(data: ByteArray, password: CharArray?) = withContext(Dispatchers.IO) {
        val (root, _) = open(data, password)
        val tables = root.getJSONObject("tables")
        val sdb = db.openHelper.writableDatabase
        sdb.beginTransaction()
        try {
            TABLES.reversed().forEach { sdb.execSQL("DELETE FROM `$it`") } // children first
            for (table in TABLES) {                                         // parents first
                val known = columns(table)
                val rows = tables.optJSONArray(table) ?: continue
                for (i in 0 until rows.length()) {
                    val o = rows.getJSONObject(i)
                    val cv = ContentValues()
                    for (key in o.keys()) {
                        if (key !in known) continue // column from a newer schema
                        when (val v = o.get(key)) {
                            JSONObject.NULL -> cv.putNull(key)
                            is Int -> cv.put(key, v.toLong())
                            is Long -> cv.put(key, v)
                            is Double -> cv.put(key, v)
                            is Boolean -> cv.put(key, if (v) 1L else 0L)
                            is Number -> cv.put(key, v.toDouble())
                            else -> cv.put(key, v.toString())
                        }
                    }
                    sdb.insert(table, android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE, cv)
                }
            }
            sdb.setTransactionSuccessful()
        } finally {
            sdb.endTransaction()
        }
        db.invalidationTracker.refreshVersionsAsync() // wake every Flow observing these tables
    }

    private fun open(data: ByteArray, password: CharArray?): Pair<JSONObject, Boolean> {
        val encrypted = BackupCrypto.isEncrypted(data)
        val plain = if (encrypted) {
            if (password == null || password.isEmpty()) throw BackupException.NeedsPassword()
            try { BackupCrypto.decrypt(data, password) } catch (_: BackupCrypto.WrongPasswordOrCorrupt) { throw BackupException.WrongPassword() }
        } else data
        val root = try { JSONObject(String(plain, Charsets.UTF_8)) } catch (_: Exception) { throw BackupException.NotABackup() }
        if (root.optString("format") != FORMAT || !root.has("tables")) throw BackupException.NotABackup()
        if (root.optInt("schemaVersion", 0) > SCHEMA_VERSION) throw BackupException.TooNew()
        if ((root.getJSONObject("tables").optJSONArray("ledgers")?.length() ?: 0) == 0) throw BackupException.NotABackup()
        return root to encrypted
    }

    private fun columns(table: String): Set<String> =
        db.openHelper.readableDatabase.query("PRAGMA table_info(`$table`)").use { c ->
            val idx = c.getColumnIndexOrThrow("name")
            buildSet { while (c.moveToNext()) add(c.getString(idx)) }
        }

    companion object {
        const val FORMAT = "hesabyar-backup"
        const val SCHEMA_VERSION = 2
        const val MIME_ENCRYPTED = "application/octet-stream"
        const val MIME_JSON = "application/json"

        /** FK order: parents before children. */
        val TABLES = listOf(
            "ledgers", "accounts", "categories", "transactions", "bank_sms", "cheques", "loans", "installments",
            "people", "debts", "savings_goals", "savings_deposits", "rates",
        )

        fun fileName(encrypted: Boolean): String =
            "hesabyar-backup-${JalaliDate.today().format('-')}" + if (encrypted) ".hsb" else ".json"
    }
}
