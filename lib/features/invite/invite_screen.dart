import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/utils/persian_digits.dart';
import '../../data/api/api_client.dart';
import '../../data/community/community_api.dart';
import '../../l10n/app_localizations.dart';
import '../common/persian_counter.dart';

/// معرفی به دوست: کد دعوت ← ۷ روز ویژه برای هر دو طرف (ثبت سمت سرور).
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _code = TextEditingController();
  InviteInfo? _info;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await ref.read(communityApiProvider).inviteInfo();
      if (mounted) setState(() => _info = info);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _redeem() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    String msg;
    try {
      final q = await ref.read(communityApiProvider).redeemInvite(_code.text);
      ref.read(entitlementProvider.notifier).apply(q);
      msg = t.inviteRedeemed;
      await _load();
    } on ApiException catch (e) {
      msg = switch (e.kind) {
        ApiErrorKind.ownCode => t.inviteOwn,
        ApiErrorKind.alreadyRedeemed => t.inviteAlready,
        ApiErrorKind.offline => t.inviteOffline,
        _ => t.inviteInvalid,
      };
    }
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final info = _info;
    return Scaffold(
      appBar: AppBar(title: Text(t.inviteTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '🎁',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 56),
          ),
          const SizedBox(height: 8),
          Text(
            t.inviteDesc(toPersianDigits('${info?.days ?? 7}')),
            textAlign: TextAlign.center,
            style: tt.bodyLarge,
          ),
          const SizedBox(height: 24),
          if (info == null && !_failed)
            const Center(child: CircularProgressIndicator())
          else if (info == null)
            Text(t.inviteOffline, textAlign: TextAlign.center)
          else ...[
            Text(t.inviteYourCode, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    info.code,
                    key: const Key('invite-code'),
                    textAlign: TextAlign.center,
                    style: tt.headlineMedium?.copyWith(
                      letterSpacing: 6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: info.code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(t.inviteCopied)));
                  },
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('invite-share'),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: t.inviteShareText(
                    info.code,
                    toPersianDigits('${info.days}'),
                  ),
                ),
              ),
              icon: const Icon(Icons.share),
              label: Text(t.inviteShare),
            ),
            if (info.invited > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.inviteCount(toPersianDigits('${info.invited}')),
                  textAlign: TextAlign.center,
                ),
              ),
            const Divider(height: 48),
            if (info.redeemedCode == null) ...[
              Text(t.inviteEnter, style: tt.titleMedium),
              const SizedBox(height: 8),
              TextField(
                key: const Key('invite-input'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                maxLength: 6,
                buildCounter: persianCounter,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              FilledButton.tonal(
                key: const Key('invite-redeem'),
                onPressed: _busy || _code.text.trim().length != 6
                    ? null
                    : _redeem,
                child: Text(t.inviteRedeem),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
