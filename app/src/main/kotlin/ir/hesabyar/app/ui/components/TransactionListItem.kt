package ir.hesabyar.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.hesabyar.app.data.local.dao.TransactionRow
import ir.hesabyar.app.ui.common.formatWhen
import ir.hesabyar.app.ui.theme.AppTheme
import ir.hesabyar.domain.ledger.TransactionType
import ir.hesabyar.domain.money.Money

@Composable
fun TransactionListItem(row: TransactionRow, onClick: (() -> Unit)? = null, modifier: Modifier = Modifier) {
    val tx = row.tx
    val isTransfer = tx.type == TransactionType.TRANSFER_OUT || tx.type == TransactionType.TRANSFER_IN
    val money = AppTheme.money
    val amountColor = when {
        isTransfer -> money.transfer
        tx.type.sign > 0 -> money.income
        else -> money.expense
    }
    val tint = row.categoryColor?.let { Color(it) } ?: money.transfer
    val title = when {
        isTransfer -> "انتقال بین حساب‌ها"
        row.categoryName != null -> row.categoryName
        tx.type.sign > 0 -> "درآمد"
        else -> "هزینه"
    }
    val subtitle = buildString {
        if (isTransfer && row.counterAccountName != null) append("${row.accountName} ← ${row.counterAccountName}")
        else append(row.accountName)
        append(" • ").append(formatWhen(tx.occurredAt))
        if (tx.note.isNotBlank()) append(" • ").append(tx.note)
    }

    Row(
        modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(42.dp).clip(CircleShape).background(tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) {
            if (isTransfer) Icon(AppIcons.Transfer, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
            else Text(row.categoryIcon ?: "•", fontSize = 20.sp)
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = money.muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Spacer(Modifier.width(8.dp))
        Text(
            if (isTransfer) Money.formatToman(tx.amountRial) else Money.formatSignedToman(tx.type.signedAmount(tx.amountRial)),
            style = MaterialTheme.typography.titleSmall,
            color = amountColor,
        )
    }
}
