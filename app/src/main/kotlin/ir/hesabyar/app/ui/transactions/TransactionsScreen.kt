package ir.hesabyar.app.ui.transactions

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.ui.components.NativeAdCard
import ir.hesabyar.app.ui.components.TransactionListItem
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdPolicy
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.text.PersianText

private sealed interface ListItem {
    data class Row(val row: TransactionRow) : ListItem
    data class Ad(val index: Int) : ListItem
}

@Composable
fun TransactionsScreen(vm: TransactionsViewModel, contentPadding: PaddingValues) {
    val s by vm.state.collectAsStateWithLifecycle()
    // Native ad after every 10 rows — positions decided by AdPolicy, not by this screen.
    val listItems = remember(s.rows) {
        AdPolicy.interleave<TransactionRow, ListItem>(s.rows, AdPolicy.NATIVE_EVERY_N_ROWS, row = { ListItem.Row(it) }, ad = { ListItem.Ad(it) })
    }
    LazyColumn(
        Modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = contentPadding.calculateBottomPadding() + 16.dp),
    ) {
        item {
            Text("تراکنش‌ها", style = MaterialTheme.typography.titleLarge)
            if (s.unconfirmedSms > 0) {
                Text(
                    PersianText.toPersianDigits("${s.unconfirmedSms}") + " پیامک بانکی در انتظار تایید — از داشبورد تایید کنید",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.gold,
                )
            }
            OutlinedTextField(
                value = s.query,
                onValueChange = { vm.query.value = it },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                placeholder = { Text("جستجو در توضیحات، دسته‌بندی یا حساب") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
            )
        }
        if (s.rows.isEmpty()) {
            item { Text("تراکنشی یافت نشد.", color = AppTheme.money.muted, modifier = Modifier.padding(vertical = 24.dp)) }
        }
        items(listItems, key = { if (it is ListItem.Row) "t${it.row.tx.id}" else "ad${(it as ListItem.Ad).index}" }) { item ->
            when (item) {
                is ListItem.Row -> {
                    TransactionListItem(item.row)
                    HorizontalDivider(color = AppTheme.money.hairline)
                }
                is ListItem.Ad -> NativeAdCard(AdSlot.NATIVE_TRANSACTIONS_FEED, Modifier.padding(vertical = 8.dp), key = item.index)
            }
        }
    }
}
