package ir.hesabyar.app.ui.common

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import ir.hesabyar.app.HesabyarApp
import ir.hesabyar.app.ui.dashboard.DashboardViewModel
import ir.hesabyar.app.ui.due.DueDatesViewModel
import ir.hesabyar.app.ui.transaction.AddTransactionViewModel
import ir.hesabyar.app.ui.transactions.TransactionsViewModel

object AppViewModels {
    val Factory: ViewModelProvider.Factory = viewModelFactory {
        initializer { DashboardViewModel((this[APPLICATION_KEY] as HesabyarApp).container) }
        initializer { AddTransactionViewModel((this[APPLICATION_KEY] as HesabyarApp).container) }
        initializer { TransactionsViewModel((this[APPLICATION_KEY] as HesabyarApp).container) }
        initializer { DueDatesViewModel((this[APPLICATION_KEY] as HesabyarApp).container) }
    }
}
