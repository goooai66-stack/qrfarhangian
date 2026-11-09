import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/billing/billing_service.dart';
import '../../data/api/api_client.dart';
import '../../l10n/app_localizations.dart';

/// صفحه‌ی اشتراک ویژه (بخش ۹-۳). [soft]: بعد از آنبوردینگ، با «فعلاً نه» واضح.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.soft = false});

  final bool soft;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  SubscriptionPlan _plan = SubscriptionPlan.yearly;
  List<ProductInfo> _products = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final billing = ref.read(billingServiceProvider);
    await billing.connect();
    final p = await billing.products();
    if (mounted) setState(() => _products = p);
  }

  String _planName(AppLocalizations t, SubscriptionPlan p) => switch (p) {
    SubscriptionPlan.monthly => t.planMonthly,
    SubscriptionPlan.quarterly => t.planQuarterly,
    SubscriptionPlan.yearly => t.planYearly,
  };

  void _close() => context.canPop() ? context.pop() : context.go(Routes.today);

  /// توکن خرید ← اعتبارسنجی سمت سرور ← فعال‌سازی ویژه.
  Future<bool> _verify(PurchaseResult r) async {
    final billing = ref.read(billingServiceProvider);
    final q = await ref
        .read(monetizationApiProvider)
        .verifyPurchase(
          store: billing.storeId,
          productId: productIdOf(r.plan!),
          purchaseToken: r.purchaseToken!,
        );
    ref.read(entitlementProvider.notifier).apply(q);
    return q.premium;
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    String? message;
    try {
      message = await action();
    } on ApiException catch (e) {
      message = e.kind == ApiErrorKind.verificationUnavailable
          ? t.purchaseUnavailable
          : t.purchaseFailed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _buy() => _run(() async {
    final t = AppLocalizations.of(context);
    final r = await ref.read(billingServiceProvider).purchase(_plan);
    if (r.errorCode == 'unavailable') return t.purchaseUnavailable;
    if (!r.success) return null; // انصراف کاربر
    if (await _verify(r)) {
      if (mounted) _close();
      return t.purchaseSuccess;
    }
    return t.purchaseFailed;
  });

  Future<void> _restore() => _run(() async {
    final t = AppLocalizations.of(context);
    final owned = await ref.read(billingServiceProvider).restorePurchases();
    for (final r in owned.where((r) => r.success && r.plan != null)) {
      try {
        if (await _verify(r)) {
          if (mounted) _close();
          return t.purchaseSuccess;
        }
      } on ApiException catch (e) {
        if (e.kind != ApiErrorKind.invalidPurchase) rethrow;
      }
    }
    return t.restoreNone;
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    String? priceOf(SubscriptionPlan p) =>
        _products.where((x) => x.plan == p).firstOrNull?.price;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.soft,
        actions: [
          if (widget.soft)
            TextButton(
              key: const Key('paywall-not-now'),
              onPressed: _close,
              child: Text(t.notNow),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            t.premiumTitle,
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          for (final b in [
            t.premiumBenefitScan,
            t.premiumBenefitNoAds,
            t.premiumBenefitMore,
          ])
            ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, color: BrandColors.green),
              title: Text(b, style: tt.bodyLarge),
            ),
          const SizedBox(height: 12),
          for (final p in SubscriptionPlan.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Material(
                color: _plan == p
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _plan == p ? cs.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: InkWell(
                  key: Key('plan-${p.name}'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _plan = p),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _plan == p
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_planName(t, p), style: tt.titleMedium),
                              if (p == SubscriptionPlan.yearly)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BrandColors.orange,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    t.bestValue,
                                    style: tt.labelMedium?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            priceOf(p) ?? t.priceInStore,
                            style: tt.bodyMedium,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('paywall-buy'),
            onPressed: _busy ? null : _buy,
            child: Text('${t.buy} · ${_planName(t, _plan)}'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('paywall-restore'),
            onPressed: _busy ? null : _restore,
            child: Text(t.restorePurchases),
          ),
          if (widget.soft)
            OutlinedButton(onPressed: _close, child: Text(t.notNow)),
        ],
      ),
    );
  }
}

/// Paywall نرم یک‌بار بعد از آنبوردینگ (بخش ۵-۱).
class SoftPaywallGate extends ConsumerStatefulWidget {
  const SoftPaywallGate({super.key});

  static const pendingKey = 'soft_paywall';

  @override
  ConsumerState<SoftPaywallGate> createState() => _SoftPaywallGateState();
}

class _SoftPaywallGateState extends ConsumerState<SoftPaywallGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final db = ref.read(databaseProvider);
    if (await db.getSetting(SoftPaywallGate.pendingKey) != 'pending') return;
    await db.setSetting(SoftPaywallGate.pendingKey, 'shown');
    if (!mounted || ref.read(isPremiumProvider)) return;
    context.push(Routes.paywallSoft);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
