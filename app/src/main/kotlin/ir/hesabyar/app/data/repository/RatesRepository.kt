package ir.hesabyar.app.data.repository

import ir.hesabyar.app.data.local.dao.RateDao
import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/** Network source of market prices — implemented in step 3 (gold & rates module). */
fun interface RateSource {
    suspend fun fetch(): List<RateEntity>
}

class RatesRepository(private val dao: RateDao, private val source: RateSource?) {

    fun observe(): Flow<Map<RateKey, RateEntity>> = dao.observeAll().map { list -> list.associateBy { it.key } }

    /** Never throws: on failure the cached prices stay on screen with their timestamp. */
    suspend fun refresh(): Boolean = runCatching {
        val fresh = source?.fetch().orEmpty()
        if (fresh.isNotEmpty()) dao.upsertAll(fresh)
        fresh.isNotEmpty()
    }.getOrDefault(false)
}
