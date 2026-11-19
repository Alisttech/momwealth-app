// One combined, newest-first list of everything that touched the member's money:
// statement rows, payments still in progress, and withdrawal requests not yet paid.
import 'package:flutter/material.dart';

import 'format.dart';
import 'services/session.dart';
import 'theme.dart';
import 'widgets.dart';

enum ActivityKind { moneyIn, moneyOut, loan, ajo, failed }

class ActivityItem {
  ActivityItem({
    required this.at,
    required this.title,
    required this.type,
    required this.kind,
    required this.amount,
    required this.sign,
    required this.status,
    required this.method,
    required this.reference,
    required this.place,
    required this.filter,
    this.statusLabel,
  });
  final DateTime? at;
  final String title, type, sign, status, method, reference, place, filter;
  final String? statusLabel;
  final ActivityKind kind;
  final int amount;
}

const _typeLabel = {
  'savings_contribution': 'Savings contribution', 'wallet_funding': 'Savings contribution', 'withdrawal': 'Withdrawal',
  'loan_disbursement': 'Loan disbursement', 'loan_repayment': 'Loan repayment', 'adjustment': 'Adjustment',
  'withdrawal_refund': 'Adjustment', 'fee': 'Adjustment', 'group_contribution': 'Group contribution',
  'group_withdrawal': 'Group withdrawal', 'ajo_contribution': 'Ajo contribution', 'ajo_payout': 'Ajo payout received',
};

String withdrawalLabel(String s) => const {
      'pending': 'Pending review', 'approved': 'Approved · payment pending', 'paid': 'Paid', 'rejected': 'Rejected', 'cancelled': 'Cancelled',
    }[s] ??
    s;

List<ActivityItem> activityItems(Session s) {
  final out = <ActivityItem>[];
  for (final t in s.ledger) {
    final loan = t.account == 'loan';
    final ajo = t.account == 'ajo';
    final credit = t.direction == 'credit';
    final type = _typeLabel[t.type] ?? 'Transaction';
    out.add(ActivityItem(
      at: t.createdAt,
      title: t.description.isEmpty ? type : t.description,
      type: type,
      kind: loan ? ActivityKind.loan : ajo ? ActivityKind.ajo : credit ? ActivityKind.moneyIn : ActivityKind.moneyOut,
      amount: t.amount,
      sign: loan || ajo ? '' : credit ? '+' : '−',
      status: t.status,
      method: methodLabel[t.paymentMethod] ?? t.channel,
      reference: t.reference,
      place: t.planName,
      filter: loan ? 'loans' : (t.account == 'group' || ajo) ? 'groups' : t.type == 'withdrawal' ? 'withdrawals' : 'savings',
    ));
  }
  for (final p in s.payments) {
    if (p.credited || p.status == 'successful' || p.status == 'initiating') continue;
    final st = p.status == 'abandoned' ? 'cancelled' : p.status == 'review' ? 'pending' : p.status;
    final (type, filter) = p.kind == 'group' ? ('Group contribution', 'groups') : p.kind == 'ajo' ? ('Ajo contribution', 'groups') : ('Savings contribution', 'savings');
    out.add(ActivityItem(
      at: p.createdAt, title: 'Payment to ${p.planName}', type: type, kind: st == 'failed' ? ActivityKind.failed : ActivityKind.moneyIn,
      amount: p.amountKobo, sign: '', status: st, method: methodLabel[p.paymentMethod] ?? 'Squad', reference: p.reference, place: p.planName, filter: filter,
    ));
  }
  for (final w in s.withdrawals) {
    if (w.status == 'paid') continue;
    final st = const {'pending': 'pending', 'approved': 'pending', 'rejected': 'failed', 'cancelled': 'cancelled'}[w.status] ?? w.status;
    out.add(ActivityItem(
      at: w.createdAt, title: 'Withdrawal request to ${w.bank.bank}', type: 'Withdrawal', kind: st == 'failed' ? ActivityKind.failed : ActivityKind.moneyOut,
      amount: w.amount, sign: '', status: st, statusLabel: withdrawalLabel(w.status), method: 'Bank transfer', reference: w.id, place: w.planName,
      filter: w.groupId != null ? 'groups' : 'withdrawals',
    ));
  }
  out.sort((a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)));
  return out;
}

Widget statusBadge(String status, [String? label]) {
  final (tone, text) = switch (status) {
    'successful' => (Tone.success, 'Successful'),
    'pending' || 'processing' => (Tone.pending, 'Pending'),
    'failed' => (Tone.danger, 'Failed'),
    'reversed' => (Tone.danger, 'Reversed'),
    'cancelled' => (Tone.muted, 'Cancelled'),
    _ => (Tone.muted, status),
  };
  return Badge2(label ?? text, tone);
}

class ActivityTile extends StatelessWidget {
  const ActivityTile(this.item, {super.key});
  final ActivityItem item;
  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (item.kind) {
      ActivityKind.moneyIn => (const Color(0xFFE7F5EC), const Color(0xFF1E7A46), Icons.south_rounded),
      ActivityKind.moneyOut => (AppColors.goldWash, AppColors.gold, Icons.north_rounded),
      ActivityKind.loan => (AppColors.blueWash, AppColors.blue, Icons.payments_outlined),
      ActivityKind.ajo => (AppColors.purpleWash, AppColors.purple, Icons.autorenew_rounded),
      ActivityKind.failed => (AppColors.redWash, AppColors.red, Icons.close_rounded),
    };
    return InkWell(
      onTap: () => showActivityDetail(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text([formatDayTime(item.at), if (item.method.isNotEmpty) item.method].join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${item.sign}${naira(item.amount)}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: item.sign == '+' ? const Color(0xFF1E7A46) : AppColors.ink)),
            if (item.status != 'successful') ...[const SizedBox(height: 4), statusBadge(item.status, item.statusLabel)],
          ]),
        ]),
      ),
    );
  }
}

/// A card containing activity rows separated by dividers.
class ActivityList extends StatelessWidget {
  const ActivityList(this.items, {super.key, this.empty = 'No transactions yet.'});
  final List<ActivityItem> items;
  final String empty;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return EmptyCard(empty);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[if (i > 0) const Divider(height: 1), ActivityTile(items[i])],
      ]),
    );
  }
}

void showActivityDetail(BuildContext context, ActivityItem it) {
  showAppSheet(context, title: it.type, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KV('Description', it.title),
      KV('Amount', '${it.sign}${naira(it.amount)}'),
      KV('Date', it.at == null ? '—' : '${formatDay(it.at)} ${formatDayTime(it.at).split(', ').last}'),
      KV('Status', '', valueWidget: Align(alignment: Alignment.centerRight, child: statusBadge(it.status, it.statusLabel))),
      if (it.place.isNotEmpty) KV('Plan / group', it.place),
      if (it.method.isNotEmpty) KV('Payment method', it.method),
      KV('Reference', it.reference.isEmpty ? '—' : it.reference, last: true),
      const SizedBox(height: 16),
      OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
    ]);
  });
}
