package ir.hesabyar.domain.rates

/**
 * Coin "bubble" (حباب سکه): market price minus the value of the gold inside.
 * Bahar Azadi coins are 900/1000 fine (21.6k). Gold quotes in Iran are per gram of 18k (750/1000),
 * so the intrinsic value is weight × (900 / 750) × price of one gram of 18k gold.
 */
enum class Coin(val persianName: String, val weightGrams: Double) {
    EMAMI("سکه امامی", 8.133),
    HALF("نیم‌سکه", 4.0665),
    QUARTER("ربع‌سکه", 2.03225),
}

object CoinMath {
    private const val COIN_PURITY = 0.900
    private const val GOLD18_PURITY = 0.750

    fun intrinsicValueRial(coin: Coin, gold18GramRial: Long): Long =
        Math.round(coin.weightGrams * (COIN_PURITY / GOLD18_PURITY) * gold18GramRial)

    fun bubbleRial(coin: Coin, coinPriceRial: Long, gold18GramRial: Long): Long =
        coinPriceRial - intrinsicValueRial(coin, gold18GramRial)

    fun bubblePercent(coin: Coin, coinPriceRial: Long, gold18GramRial: Long): Double {
        val intrinsic = intrinsicValueRial(coin, gold18GramRial)
        return if (intrinsic == 0L) 0.0 else (coinPriceRial - intrinsic) * 100.0 / intrinsic
    }
}
