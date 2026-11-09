package ir.hesabyar.app.data.repository

import ir.hesabyar.app.data.local.dao.RateDao
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.domain.rates.RateSanity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Network source of market prices (null = not configured; the app then relies on manual entry). */
fun interface RateSource {
    suspend fun fetch(): List<RateEntity>
}

enum class RefreshResult { UPDATED, NO_SOURCE, FAILED, REJECTED }

class RatesRepository(private val dao: RateDao, private val source: RateSource?) {

    private val mutex = Mutex()
    private var lastAttempt = 0L

    val hasOnlineSource: Boolean get() = source != null

    fun observe(): Flow<Map<RateKey, RateEntity>> = dao.observeAll().map { list -> list.associateBy { it.key } }

    /**
     * Never throws: on failure the cached prices stay on screen with their timestamp.
     * Each new price passes [RateSanity]; a 10× unit mistake or zero price is rejected
     * instead of silently corrupting gold calculators and savings goals.
     */
    suspend fun refresh(): RefreshResult = mutex.withLock {
        val src = source ?: return@withLock RefreshResult.NO_SOURCE
        lastAttempt = System.currentTimeMillis()
        val fresh = runCatching { src.fetch() }.getOrNull() ?: return@withLock RefreshResult.FAILED
        if (fresh.isEmpty()) return@withLock RefreshResult.FAILED
        val current = dao.observeAll().first().associateBy { it.key }
        val accepted = fresh.filter { RateSanity.check(it.priceRial, current[it.key]?.priceRial) == RateSanity.Verdict.OK }
        if (accepted.isEmpty()) return@withLock RefreshResult.REJECTED
        dao.upsertAll(accepted)
        RefreshResult.UPDATED
    }

    /** Called on dashboard/tools open: at most one network attempt per [minIntervalMs]. */
    suspend fun refreshIfStale(minIntervalMs: Long = 30 * 60_000L) {
        if (source == null || System.currentTimeMillis() - lastAttempt < minIntervalMs) return
        val newest = dao.observeAll().first().maxOfOrNull { it.fetchedAt } ?: 0L
        if (System.currentTimeMillis() - newest >= minIntervalMs) refresh()
    }

    /** «ثبت دستی نرخ»: the offline-first fallback; the user's number wins until the next feed update. */
    suspend fun setManual(key: RateKey, priceRial: Long) {
        require(priceRial > 0)
        dao.upsertAll(listOf(RateEntity(key, priceRial, null, System.currentTimeMillis(), "manual")))
    }
}
