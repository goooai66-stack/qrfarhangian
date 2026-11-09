package ir.hesabyar.app.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import ir.hesabyar.app.data.local.dao.AccountDao
import ir.hesabyar.app.data.local.dao.BankSmsDao
import ir.hesabyar.app.data.local.dao.CategoryDao
import ir.hesabyar.app.data.local.dao.LedgerDao
import ir.hesabyar.app.data.local.dao.PlanningDao
import ir.hesabyar.app.data.local.dao.RateDao
import ir.hesabyar.app.data.local.dao.TransactionDao
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.BankSmsEntity
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.ChequeEntity
import ir.hesabyar.app.data.local.entity.DebtEntity
import ir.hesabyar.app.data.local.entity.InstallmentEntity
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.data.local.entity.LoanEntity
import ir.hesabyar.app.data.local.entity.PersonEntity
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.SavingsDepositEntity
import ir.hesabyar.app.data.local.entity.SavingsGoalEntity
import ir.hesabyar.app.data.local.entity.TransactionEntity

@Database(
    entities = [
        LedgerEntity::class, AccountEntity::class, CategoryEntity::class, TransactionEntity::class,
        BankSmsEntity::class, ChequeEntity::class, LoanEntity::class, InstallmentEntity::class,
        PersonEntity::class, DebtEntity::class, SavingsGoalEntity::class, SavingsDepositEntity::class,
        RateEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun ledgerDao(): LedgerDao
    abstract fun accountDao(): AccountDao
    abstract fun categoryDao(): CategoryDao
    abstract fun transactionDao(): TransactionDao
    abstract fun bankSmsDao(): BankSmsDao
    abstract fun rateDao(): RateDao
    abstract fun planningDao(): PlanningDao

    companion object {
        const val NAME = "hesabyar.db"

        /** v2: savings goals get a linked wallet account. Explicit SQL — financial data is never dropped. */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE savings_goals ADD COLUMN accountId INTEGER DEFAULT NULL")
            }
        }

        fun build(context: Context): AppDatabase =
            Room.databaseBuilder(context, AppDatabase::class.java, NAME)
                // WAL: list reads never block a write coming from the SMS receiver.
                .setJournalMode(RoomDatabase.JournalMode.WRITE_AHEAD_LOGGING)
                .addMigrations(MIGRATION_1_2)
                .build()
    }
}
