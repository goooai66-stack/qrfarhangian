package ir.hesabyar.app.ui.main

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import ir.hesabyar.app.appContainer
import ir.hesabyar.app.data.repository.DraftKind
import ir.hesabyar.app.ui.common.AppViewModels
import ir.hesabyar.app.ui.components.AppIcons
import ir.hesabyar.app.ui.components.RewardedUnlockDialog
import ir.hesabyar.app.ui.components.findActivity
import ir.hesabyar.app.ui.dashboard.DashboardActions
import ir.hesabyar.app.ui.dashboard.DashboardScreen
import ir.hesabyar.app.ui.dashboard.DashboardViewModel
import ir.hesabyar.app.ui.theme.Gold
import ir.hesabyar.app.ui.theme.Navy
import ir.hesabyar.app.ui.tools.DueDatesScreen
import ir.hesabyar.app.ui.tools.ReportsScreen
import ir.hesabyar.app.ui.tools.ToolsScreen
import ir.hesabyar.app.ui.transaction.AddTransactionSheet
import ir.hesabyar.app.ui.transaction.AddTransactionViewModel
import ir.hesabyar.app.ui.transactions.TransactionsScreen
import ir.hesabyar.app.ui.transactions.TransactionsViewModel
import ir.hesabyar.domain.ads.AppSurface
import ir.hesabyar.domain.ads.RewardedFeature

enum class Tab(val label: String, val icon: ImageVector) {
    DASHBOARD("داشبورد", Icons.Filled.Home),
    TRANSACTIONS("تراکنش‌ها", Icons.AutoMirrored.Filled.List),
    DUE("سررسیدها", Icons.Filled.DateRange),
    TOOLS("ابزار و طلا", AppIcons.Tools),
    REPORTS("گزارش‌ها", AppIcons.Chart),
}

private const val EXIT_WINDOW_MS = 2_000L

@Composable
fun MainScreen(onExit: () -> Unit) {
    val context = LocalContext.current
    val container = context.appContainer
    var tab by rememberSaveable { mutableStateOf(Tab.DASHBOARD) }
    var addKind by remember { mutableStateOf<DraftKind?>(null) }
    var askVoice by remember { mutableStateOf(false) }
    var lastBack by remember { mutableLongStateOf(0L) }

    // ---- Back button: sheets/dialogs consume it first (own windows). Then: any tab → dashboard;
    // dashboard → «press again to exit». The app never closes on a single accidental press.
    BackHandler(enabled = tab != Tab.DASHBOARD) { tab = Tab.DASHBOARD }
    BackHandler(enabled = tab == Tab.DASHBOARD) {
        val now = System.currentTimeMillis()
        if (now - lastBack < EXIT_WINDOW_MS) onExit()
        else {
            lastBack = now
            Toast.makeText(context, "برای خروج دوباره ضربه بزنید", Toast.LENGTH_SHORT).show()
        }
    }

    // Light status-bar icons over the navy hero, dark icons over beige tabs.
    val view = LocalView.current
    val dark = isSystemInDarkTheme()
    SideEffect {
        view.context.findActivity()?.window?.let { w ->
            WindowCompat.getInsetsController(w, view).isAppearanceLightStatusBars = !dark && tab != Tab.DASHBOARD
        }
    }

    val dashboardVm: DashboardViewModel = viewModel(factory = AppViewModels.Factory)
    val addVm: AddTransactionViewModel = viewModel(factory = AppViewModels.Factory)
    val txVm: TransactionsViewModel = viewModel(factory = AppViewModels.Factory)
    // start() resets the form synchronously, before the sheet's first frame.
    val openAdd: (DraftKind) -> Unit = { kind -> addVm.start(kind); addKind = kind }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface, tonalElevation = 0.dp) {
                Tab.entries.forEach { t ->
                    NavigationBarItem(
                        selected = t == tab,
                        onClick = { tab = t },
                        icon = { Icon(t.icon, contentDescription = null) },
                        label = { Text(t.label, style = MaterialTheme.typography.labelSmall, maxLines = 1) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Navy, selectedTextColor = Navy, indicatorColor = Gold.copy(alpha = 0.25f),
                        ),
                    )
                }
            }
        },
        floatingActionButton = {
            if (tab == Tab.DASHBOARD || tab == Tab.TRANSACTIONS) {
                ExtendedFloatingActionButton(
                    onClick = { openAdd(DraftKind.EXPENSE) },
                    containerColor = Navy, contentColor = Color.White,
                    icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                    text = { Text("ثبت سریع") },
                )
            }
        },
    ) { padding ->
        when (tab) {
            Tab.DASHBOARD -> {
                val state by dashboardVm.state.collectAsStateWithLifecycle()
                DashboardScreen(
                    state = state,
                    contentPadding = padding,
                    actions = DashboardActions(
                        onSelectLedger = dashboardVm::selectLedger,
                        onAdd = openAdd,
                        onVoice = {
                            if (container.ads.isUnlocked(RewardedFeature.VOICE_ASSISTANT)) {
                                Toast.makeText(context, "دستیار صوتی فعال است (پیاده‌سازی در گام ۲)", Toast.LENGTH_SHORT).show()
                            } else askVoice = true
                        },
                        onConfirmSms = { id, cat -> dashboardVm.confirmSms(id, cat) },
                        onDismissSms = { dashboardVm.dismissSms(it) },
                        onNotATransfer = { dashboardVm.notATransfer(it) },
                        onSeeAllTransactions = { tab = Tab.TRANSACTIONS },
                        onOpenTools = { tab = Tab.TOOLS },
                        onRefreshRates = { dashboardVm.refreshRates() },
                    ),
                )
            }
            Tab.TRANSACTIONS -> TransactionsScreen(txVm, padding)
            Tab.DUE -> DueDatesScreen(padding)
            Tab.TOOLS -> ToolsScreen(padding)
            Tab.REPORTS -> ReportsScreen(padding)
        }
    }

    if (addKind != null) {
        AddTransactionSheet(addVm, onDismiss = { addKind = null })
    }

    if (askVoice) {
        RewardedUnlockDialog(
            RewardedFeature.VOICE_ASSISTANT,
            onWatch = {
                askVoice = false
                context.findActivity()?.let { activity ->
                    container.ads.watchToUnlock(activity, RewardedFeature.VOICE_ASSISTANT, AppSurface.DASHBOARD) { ok ->
                        if (ok) Toast.makeText(context, "دستیار صوتی برای ۲۴ ساعت فعال شد", Toast.LENGTH_SHORT).show()
                    }
                }
            },
            onDismiss = { askVoice = false },
        )
    }
}
