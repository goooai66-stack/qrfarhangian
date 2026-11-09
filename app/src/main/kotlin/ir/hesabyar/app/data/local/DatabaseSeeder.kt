package ir.hesabyar.app.data.local

import androidx.room.withTransaction
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.AccountKind
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.local.entity.LedgerEntity
import ir.hesabyar.app.data.local.entity.LedgerKind

/** First launch: two ledgers, a cash wallet each, and sensible Persian categories. */
class DatabaseSeeder(private val db: AppDatabase) {

    suspend fun seedIfEmpty() {
        if (db.ledgerDao().count() > 0) return
        db.withTransaction {
            val personal = db.ledgerDao().insert(LedgerEntity(name = "شخصی و خانواده", kind = LedgerKind.PERSONAL, colorArgb = 0xFF1B2A4A, sortOrder = 0))
            val business = db.ledgerDao().insert(LedgerEntity(name = "کسب‌وکار", kind = LedgerKind.BUSINESS, colorArgb = 0xFFC5A059, sortOrder = 1))
            db.accountDao().insert(AccountEntity(ledgerId = personal, name = "کیف پول نقدی", kind = AccountKind.CASH, colorArgb = 0xFF3EB489))
            db.accountDao().insert(AccountEntity(ledgerId = business, name = "صندوق فروشگاه", kind = AccountKind.CASH, colorArgb = 0xFF3EB489))
            db.categoryDao().insertAll(personalCategories(personal))
            db.categoryDao().insertAll(businessCategories(business))
        }
    }

    private fun personalCategories(ledgerId: Long): List<CategoryEntity> {
        var order = 0
        fun e(name: String, icon: String, color: Long, keys: String = "") =
            CategoryEntity(ledgerId = ledgerId, name = name, icon = icon, colorArgb = color, kind = CategoryKind.EXPENSE, matchKeywords = keys, sortOrder = order++)
        fun i(name: String, icon: String, color: Long, keys: String = "") =
            CategoryEntity(ledgerId = ledgerId, name = name, icon = icon, colorArgb = color, kind = CategoryKind.INCOME, matchKeywords = keys, sortOrder = order++)
        return listOf(
            e("سوپرمارکت", "🛒", 0xFF3EB489, "PURCHASE"),
            e("رستوران و کافه", "🍽️", 0xFFE05A47),
            e("بنزین و خودرو", "⛽", 0xFF1B2A4A),
            e("حمل‌ونقل", "🚕", 0xFF5B7DB1),
            e("قبوض", "💡", 0xFFC5A059, "BILL"),
            e("شارژ و اینترنت", "📱", 0xFF7A68C4),
            e("اجاره و مسکن", "🏠", 0xFF8C6D46),
            e("درمان و دارو", "💊", 0xFFD26A8C),
            e("پوشاک", "👕", 0xFF4AA3A2),
            e("آموزش", "🎓", 0xFF3D6FA8),
            e("تفریح", "🎬", 0xFFE0894A),
            e("اقساط و وام", "💳", 0xFF6B7280, "LOAN"),
            e("کارمزد بانکی", "🧾", 0xFF9CA3AF, "FEE"),
            e("برداشت نقدی", "🏧", 0xFF64748B, "ATM"),
            e("هدیه و خیریه", "🎁", 0xFFB45309),
            e("سایر هزینه‌ها", "📦", 0xFF94A3B8),
            i("حقوق", "💼", 0xFF2E8B57, "SALARY"),
            i("سود سپرده", "📈", 0xFF3EB489, "INTEREST"),
            i("فروش", "💰", 0xFFC5A059),
            i("هدیه دریافتی", "🎁", 0xFFB45309),
            i("سایر درآمدها", "➕", 0xFF94A3B8),
        )
    }

    private fun businessCategories(ledgerId: Long): List<CategoryEntity> {
        var order = 0
        fun e(name: String, icon: String, color: Long, keys: String = "") =
            CategoryEntity(ledgerId = ledgerId, name = name, icon = icon, colorArgb = color, kind = CategoryKind.EXPENSE, matchKeywords = keys, sortOrder = order++)
        fun i(name: String, icon: String, color: Long, keys: String = "") =
            CategoryEntity(ledgerId = ledgerId, name = name, icon = icon, colorArgb = color, kind = CategoryKind.INCOME, matchKeywords = keys, sortOrder = order++)
        return listOf(
            e("خرید کالا", "📦", 0xFF1B2A4A, "PURCHASE"),
            e("حقوق پرسنل", "👥", 0xFF5B7DB1),
            e("اجاره مغازه", "🏪", 0xFF8C6D46),
            e("قبوض", "💡", 0xFFC5A059, "BILL"),
            e("حمل و ارسال", "🚚", 0xFF4AA3A2),
            e("تبلیغات", "📣", 0xFFE0894A),
            e("مالیات و عوارض", "🏛️", 0xFF6B7280),
            e("کارمزد بانکی", "🧾", 0xFF9CA3AF, "FEE"),
            e("سایر هزینه‌ها", "📁", 0xFF94A3B8),
            i("فروش نقدی", "💵", 0xFF2E8B57),
            i("فروش کارتخوان", "💳", 0xFF3EB489, "TRANSFER"),
            i("وصول چک", "🧾", 0xFFC5A059, "CHEQUE"),
            i("سایر درآمدها", "➕", 0xFF94A3B8),
        )
    }
}
