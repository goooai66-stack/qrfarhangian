package ir.hesabyar.app.data.remote

import ir.hesabyar.app.data.local.entity.RateEntity
import ir.hesabyar.app.data.local.entity.RateKey
import ir.hesabyar.app.data.repository.RateSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Reads a small public JSON feed (schema: docs/rates-feed.md). No OkHttp/Retrofit — one GET
 * with HttpURLConnection and the platform org.json keeps the APK small. The request carries no
 * user data: no ids, no headers beyond the defaults, nothing from the database.
 *
 * {"updatedAt": 1762675200, "source": "…",
 *  "rates": {"GOLD_18K_GRAM": {"price": 71500000, "unit": "rial", "change": 0.8}, …}}
 */
class JsonRateSource(private val url: String, private val timeoutMs: Int = 8_000) : RateSource {

    override suspend fun fetch(): List<RateEntity> = withContext(Dispatchers.IO) {
        val conn = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = timeoutMs
            readTimeout = timeoutMs
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
            useCaches = false
        }
        try {
            if (conn.responseCode !in 200..299) return@withContext emptyList()
            val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
            parse(body, System.currentTimeMillis())
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        /** Pure parsing, tolerant to missing keys; prices may be given in rial or toman. */
        fun parse(json: String, nowMillis: Long): List<RateEntity> {
            val root = JSONObject(json)
            val updatedAt = root.optLong("updatedAt", 0L).let { if (it in 1..9_999_999_999L) it * 1000 else nowMillis }
            val source = root.optString("source", "feed").take(40)
            val rates = root.optJSONObject("rates") ?: return emptyList()
            return RateKey.entries.mapNotNull { key ->
                val o = rates.optJSONObject(key.name) ?: return@mapNotNull null
                val raw = o.optLong("price", -1)
                if (raw <= 0) return@mapNotNull null
                val rial = if (o.optString("unit", "rial").lowercase() == "toman") raw * 10 else raw
                RateEntity(
                    key = key, priceRial = rial,
                    changePercent = if (o.has("change")) o.optDouble("change") else null,
                    fetchedAt = minOf(updatedAt, nowMillis), source = source,
                )
            }
        }
    }
}
