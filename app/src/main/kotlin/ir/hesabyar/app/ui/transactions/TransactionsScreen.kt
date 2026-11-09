package ir.hesabyar.app.ui.transactions

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.data.repository.TransactionFilter
import ir.hesabyar.app.ui.components.NativeAdCard
import ir.hesabyar.app.ui.components.TransactionListItem
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ads.AdPolicy
import ir.hesabyar.domain.ads.AdSlot
import ir.hesabyar.domain.money.Money
import ir.hesabyar.domain.text.PersianText

private sealed interface ListItem {
    data class Row(val row: TransactionRow) : ListItem
    data class Ad(val index: Int) : ListItem
}

@Composable
fun TransactionsScreen(vm: TransactionsViewModel, contentPadding: PaddingValues) {
    val s by vm.state.collectAsStateWithLifecycle()
    var showFilter by remember { mutableStateOf(false) }
    // Native ad after every 10 rows — positions decided by AdPolicy, not by this screen.
    val listItems = remember(s.rows) {
        AdPolicy.interleave<TransactionRow, ListItem>(s.rows, AdPolicy.NATIVE_EVERY_N_ROWS, row = { ListItem.Row(it) }, ad = { ListItem.Ad(it) })
    }
    LazyColumn(
        Modifier.fillMaxSize().statusBarsPadding(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 12.dp, bottom = contentPadding.calculateBottomPadding() + 88.dp),
    ) {
        item {
            Text("تراکنش‌ها", style = MaterialTheme.typography.titleLarge)
            if (s.unconfirmedSms > 0) {
                Text(
                    PersianText.toPersianDigits("${s.unconfirmedSms}") + " پیامک بانکی در انتظار تایید — از داشبورد تایید کنید",
                    style = MaterialTheme.typography.bodySmall, color = AppTheme.money.gold,
                )
            }
            Row(Modifier.padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = s.filter.query,
                    onValueChange = vm::setQuery,
                    leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                    placeholder = { Text("جستجو در توضیحات، دسته یا حساب") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                BadgedBox(badge = { if (s.filter.activeCount > 0) Badge { Text(PersianText.toPersianDigits(s.filter.activeCount.toString())) } }) {
                    FilledTonalButton(onClick = { showFilter = true }) { Text("فیلتر") }
                }
            }
            if (s.filter.activeCount > 0) ActiveFilterChips(s.filter, onClear = vm::clearFilters, onOpen = { showFilter = true })
            Row(Modifier.fillMaxWidth().padding(bottom = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(PersianText.toPersianDigits("${s.rows.size} تراکنش"), style = MaterialTheme.typography.labelMedium, color = AppTheme.money.muted)
                Text("درآمد ${Money.formatToman(s.incomeRial)}", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.income)
                Text("هزینه ${Money.formatToman(s.expenseRial)}", style = MaterialTheme.typography.labelMedium, color = AppTheme.money.expense)
            }
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

    if (showFilter) {
        TransactionFilterSheet(s.filter, s.categories, s.accounts, onApply = vm::applyFilter, onDismiss = { showFilter = false })
    }
}

@Composable
private fun ActiveFilterChips(f: TransactionFilter, onClear: () -> Unit, onOpen: () -> Unit) {
    val labels = buildList {
        if (f.from != null || f.to != null) add("📅 ${f.from?.formatLong() ?: "…"} تا ${f.to?.formatLong() ?: "…"}")
        if (f.minToman != null || f.maxToman != null) add(
            "💰 " + (f.minToman?.let { Money.formatToman(it * 10) } ?: "۰") + " تا " + (f.maxToman?.let { Money.formatToman(it * 10) } ?: "∞"),
        )
        if (f.kinds.isNotEmpty()) add(f.kinds.joinToString("، ") { it.label })
        if (f.categoryIds.isNotEmpty()) add(PersianText.toPersianDigits("${f.categoryIds.size} دسته"))
        if (f.accountIds.isNotEmpty()) add(PersianText.toPersianDigits("${f.accountIds.size} حساب"))
    }
    Row(Modifier.horizontalScroll(rememberScrollState()).padding(bottom = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        labels.forEach { AssistChip(onClick = onOpen, label = { Text(it) }) }
        AssistChip(onClick = onClear, label = { Text("✕ حذف فیلترها") })
    }
}
