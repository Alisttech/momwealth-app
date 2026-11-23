import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../activity.dart';
import '../code_sheet.dart';
import '../format.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';

class _Source {
  _Source(this.key, this.id, this.isGroup, this.name, this.available);
  final String key, id, name;
  final bool isGroup;
  final int available;
}

/// Request a withdrawal from a personal plan, or from your own share of an unlocked savings group.
/// Nothing is paid by the app: MOM reviews, pays through its bank and marks it paid.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, this.planId, this.groupId});
  final String? planId, groupId;
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  late final BankFieldsController _bank;
  String? _sourceKey;
  String? _error;

  List<_Source> _sources(Session s) => [
        for (final p in s.plans.where((p) => p.status == 'active')) _Source('p:${p.id}', p.id, false, p.name, p.available),
        for (final g in s.activeGroups.where((g) => !g.locked && (g.member(s.uid)?.balance ?? 0) > 0))
          _Source('g:${g.id}', g.id, true, '${g.name} (group, your share)', g.member(s.uid)!.available),
      ];

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _bank = BankFieldsController(s.lastBank, s.profile?.name);
    final list = _sources(s);
    final want = widget.groupId != null ? 'g:${widget.groupId}' : widget.planId != null ? 'p:${widget.planId}' : null;
    _sourceKey = list.where((x) => x.key == want).firstOrNull?.key ?? (list.isEmpty ? null : (list.toList()..sort((a, b) => b.available.compareTo(a.available))).first.key);
  }

  Future<void> _submit(List<_Source> list) async {
    setState(() => _error = null);
    final src = list.where((x) => x.key == _sourceKey).firstOrNull;
    final k = parseKobo(_amount.text);
    final bankErr = _bank.validate();
    String? err;
    if (src == null) {
      err = 'Choose where to withdraw from.';
    } else if (k == null) {
      err = 'Enter the amount you want to withdraw.';
    } else if (k > src.available) {
      err = 'You can withdraw up to ${naira(src.available)} from here.';
    } else {
      err = bankErr;
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final b = _bank.value;
    final ok = await confirmSheet(
      context,
      title: 'Confirm withdrawal request',
      message: '${naira(k!)} from ${src!.name}\nto ${b.accountName}, ${b.bank} ${b.accountNumber}.\n\n'
          'We\'ll text a code to your phone to confirm it\'s you. The amount is then held until MOM reviews and pays it.',
      confirmLabel: 'Continue',
    );
    if (!ok || !mounted) return;
    final source = {if (src.isGroup) 'groupId': src.id else 'planId': src.id};
    final done = await confirmWithSmsCode(
      context,
      title: 'Enter your code',
      purpose: 'confirm this withdrawal of ${naira(k)}',
      verifyLabel: 'Submit request',
      send: () => Api.call('requestWithdrawalCode', {...source, 'amountKobo': k, 'accountNumber': b.accountNumber}),
      verify: (codeId, code) => Api.call('requestWithdrawal', {
        ...source,
        'amountKobo': k,
        'bankName': b.bank,
        'accountNumber': b.accountNumber,
        'accountName': b.accountName,
        'reason': _reason.text.trim(),
        'codeId': codeId,
        'code': code,
      }),
    );
    if (done && mounted) toast(context, 'Withdrawal request submitted');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final open = s.openWithdrawal;
    final list = _sources(s);
    final src = list.where((x) => x.key == _sourceKey).firstOrNull;
    const how = 'How it works: MOM reviews your request, pays the money into your bank account, then marks it paid. '
        'Your balance only reduces once it has been paid. You\'ll get an email at each step, and a text when it has been paid.';
    return Scaffold(
      appBar: AppBar(title: const Text('Withdraw')),
      body: PageBody(children: [
        if (open != null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Note('You have a withdrawal request in progress. You can make a new request once it is completed.'),
              const SizedBox(height: 8),
              KV('Amount', naira(open.amount)),
              KV('From', open.planName),
              KV('To', '${open.bank.accountName}\n${open.bank.bank} ${open.bank.accountNumber}'),
              KV('Status', '', valueWidget: Align(alignment: Alignment.centerRight, child: withdrawalBadge(open.status)), last: true),
              const SizedBox(height: 10),
              const Text(how, style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5, height: 1.45)),
            ]),
          )
        else ...[
          if (list.every((x) => x.available == 0)) ...[const Note("You don't have any savings available to withdraw yet."), const SizedBox(height: 14)],
          DropdownButtonFormField<String>(
            initialValue: _sourceKey,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Withdraw from'),
            items: [for (final x in list) DropdownMenuItem(value: x.key, child: Text('${x.name} — ${naira(x.available)}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _sourceKey = v),
          ),
          const SizedBox(height: 14),
          MoneyField(controller: _amount, label: 'Amount', hint: src == null ? null : 'Available: ${naira(src.available)}'),
          if (src != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: () => setState(() => _amount.text = formatAmountField(src.available)), child: const Text('Withdraw all')),
            ),
          const SizedBox(height: 6),
          BankFields(controller: _bank),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Must be your own account. MOM pays only into accounts in your name.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          ),
          const SizedBox(height: 14),
          TextField(controller: _reason, maxLength: 300, decoration: const InputDecoration(labelText: 'Reason (optional)', counterText: '')),
          const SizedBox(height: 18),
          ErrorText(_error),
          BusyButton(label: 'Request withdrawal', onPressed: () => _submit(list)),
          const SizedBox(height: 12),
          const Text(how, style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5, height: 1.45)),
        ],
        const SectionTitle('Your withdrawal requests'),
        if (s.withdrawals.isEmpty) const EmptyCard('No withdrawal requests yet.'),
        if (s.withdrawals.isNotEmpty)
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < s.withdrawals.length && i < 10; i++) ...[if (i > 0) const Divider(height: 1), _RequestTile(s.withdrawals[i])],
            ]),
          ),
      ]),
    );
  }
}

Widget withdrawalBadge(String status) {
  final tone = switch (status) { 'pending' => Tone.pending, 'approved' => Tone.info, 'paid' => Tone.success, 'rejected' => Tone.danger, _ => Tone.muted };
  return Badge2(withdrawalLabel(status), tone);
}

class _RequestTile extends StatelessWidget {
  const _RequestTile(this.w);
  final Withdrawal w;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${naira(w.amount)} · ${w.planName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${formatDay(w.createdAt)} · ${w.bank.bank} ${w.bank.accountNumber}${w.failureReason.isNotEmpty ? ' · ${w.failureReason}' : ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          withdrawalBadge(w.status),
          if (w.status == 'pending')
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              onPressed: () async {
                final ok = await confirmSheet(context,
                    title: 'Cancel this withdrawal request?', message: 'The held amount goes back to your available balance.', confirmLabel: 'Cancel request', danger: true);
                if (!ok) return;
                try {
                  await Api.call('cancelWithdrawal', {'payoutId': w.id});
                  if (context.mounted) toast(context, 'Request cancelled');
                } catch (e) {
                  if (context.mounted) toast(context, friendlyError(e));
                }
              },
              child: const Text('Cancel', style: TextStyle(color: AppColors.red)),
            ),
        ]),
      ]),
    );
  }
}
