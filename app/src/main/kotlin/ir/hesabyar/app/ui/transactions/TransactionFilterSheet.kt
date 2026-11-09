package ir.hesabyar.app.ui.transactions

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import ir.hesabyar.app.data.local.entity.AccountEntity
import ir.hesabyar.app.data.local.entity.CategoryEntity
import ir.hesabyar.app.data.local.entity.CategoryKind
import ir.hesabyar.app.data.repository.FilterKind
import ir.hesabyar.app.data.repository.TransactionFilter
import ir.hesabyar.app.ui.components.DateInput
import ir.hesabyar.app.ui.components.FieldLabel
import ir.hesabyar.app.ui.components.FormSheet
import ir.hesabyar.app.ui.components.TextInput

@Composable
fun TransactionFilterSheet(
    initial: TransactionFilter,
    categories: List<CategoryEntity>,
    accounts: List<AccountEntity>,
    onApply: (TransactionFilter) -> Unit,
    onDismiss: () -> Unit,
) {
    var f by remember { mutableStateOf(initial) }
    var minText by remember { mutableStateOf(initial.minToman?.toString().orEmpty()) }
    var maxText by remember { mutableStateOf(initial.maxToman?.toString().orEmpty()) }

    FormSheet(
        title = "فیلتر پیشرفته", saveLabel = "اعمال فیلتر", error = null, saving = false, onDismiss = onDismiss,
        onSave = {
            onApply(f.copy(minToman = minText.toLongOrNull(), maxToman = maxText.toLongOrNull()))
            onDismiss()
        },
    ) {
        TextButton(onClick = { f = TransactionFilter(query = f.query); minText = ""; maxText = "" }) { Text("پاک کردن همه‌ی فیلترها") }

        FieldLabel("بازه زمانی")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            val presets = listOf(
                "همه" to TransactionFilter(), "این ماه" to TransactionFilter.thisMonth(),
                "ماه قبل" to TransactionFilter.lastMonth(), "۷ روز" to TransactionFilter.lastDays(7), "۳۰ روز" to TransactionFilter.lastDays(30),
            )
            presets.forEach { (label, p) ->
                FilterChip(selected = f.from == p.from && f.to == p.to, onClick = { f = f.copy(from = p.from, to = p.to) }, label = { Text(label) })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f)) { DateInput("از تاریخ", f.from, { f = f.copy(from = it) }, optional = true) }
            Column(Modifier.weight(1f)) { DateInput("تا تاریخ", f.to, { f = f.copy(to = it) }, optional = true) }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Column(Modifier.weight(1f)) { TextInput("از مبلغ (تومان)", minText, { minText = it.take(13) }, numeric = true) }
            Column(Modifier.weight(1f)) { TextInput("تا مبلغ (تومان)", maxText, { maxText = it.take(13) }, numeric = true) }
        }

        FieldLabel("نوع")
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            FilterKind.entries.forEach { k ->
                FilterChip(selected = k in f.kinds, onClick = { f = f.copy(kinds = f.kinds.toggle(k)) }, label = { Text(k.label) })
            }
        }

        val visibleCats = categories.filter { c ->
            f.kinds.isEmpty() || (c.kind == CategoryKind.EXPENSE && FilterKind.EXPENSE in f.kinds) || (c.kind == CategoryKind.INCOME && FilterKind.INCOME in f.kinds)
        }
        if (visibleCats.isNotEmpty()) {
            FieldLabel("دسته‌بندی")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                visibleCats.forEach { c ->
                    FilterChip(selected = c.id in f.categoryIds, onClick = { f = f.copy(categoryIds = f.categoryIds.toggle(c.id)) }, label = { Text("${c.icon} ${c.name}") })
                }
            }
        }

        if (accounts.size > 1) {
            FieldLabel("حساب")
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                accounts.forEach { a ->
                    FilterChip(selected = a.id in f.accountIds, onClick = { f = f.copy(accountIds = f.accountIds.toggle(a.id)) }, label = { Text(a.name) })
                }
            }
        }
    }
}

private fun <T> Set<T>.toggle(v: T): Set<T> = if (v in this) this - v else this + v
