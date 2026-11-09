package ir.hesabyar.app.data.local.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import ir.hesabyar.app.data.local.entity.RateEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface RateDao {
    @Query("SELECT * FROM rates")
    fun observeAll(): Flow<List<RateEntity>>

    @Upsert suspend fun upsertAll(rates: List<RateEntity>)
}
