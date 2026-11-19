import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart' show push;

const loanLabels = {
  'submitted': 'Submitted', 'under_review': 'Under review', 'info_requested': 'Action needed', 'approved': 'Awaiting disbursement',
  'active': 'Active', 'completed': 'Completed', 'rejected': 'Rejected', 'defaulted': 'Defaulted',
};

Widget loanBadge(String status) {
  final tone = switch (status) {
    'submitted' || 'under_review' => Tone.pending,
    'info_requested' || 'rejected' || 'defaulted' => Tone.danger,
    'approved' => Tone.info,
    'active' => Tone.success,
    _ => Tone.muted,
  };
  return Badge2(loanLabels[status] ?? status, tone);
}

class LoansTab extends StatelessWidget {
  const LoansTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final current = s.currentLoan;
    final past = s.loans.where((l) => l != current).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      body: PageBody(children: [
        if (current == null)
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Need a loan?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Apply in a few minutes. MOM reviews every application personally and will contact you about the next steps.',
                  style: TextStyle(color: AppColors.inkSoft, height: 1.45)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => push(context, const LoanApplyScreen()), child: const Text('Apply for a loan')),
            ]),
          )
        else
          _CurrentLoan(current, s.instalments.where((x) => x.loanId == current.id).toList()),
        if (past.isNotEmpty) ...[
          const SectionTitle('Previous applications'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < past.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  title: Text(naira(past[i].amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${formatDay(past[i].createdAt)} · ${past[i].purpose}${past[i].rejectionReason.isNotEmpty ? ' · ${past[i].rejectionReason}' : ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: loanBadge(past[i].status),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

class _CurrentLoan extends StatefulWidget {
  const _CurrentLoan(this.l, this.instalments);
  final Loan l;
  final List<Instalment> instalments;
  @override
  State<_CurrentLoan> createState() => _CurrentLoanState();
}

class _CurrentLoanState extends State<_CurrentLoan> {
  final _reply = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final running = l.isRunning;
    final adminMsg = l.messages.where((m) => m.from == 'admin').lastOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(running ? 'Loan balance' : 'Loan application', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                Text(naira(running ? l.outstanding : l.amount), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              ]),
            ),
            loanBadge(l.status),
          ]),
          if (l.status == 'info_requested' && adminMsg != null) ...[
            const SizedBox(height: 14),
            Note('MOM needs more information:\n${adminMsg.text}'),
            const SizedBox(height: 12),
            TextField(controller: _reply, minLines: 3, maxLines: 6, maxLength: 1000, decoration: const InputDecoration(labelText: 'Your reply', counterText: '')),
            const SizedBox(height: 12),
            ErrorText(_error),
            BusyButton(
              label: 'Send reply',
              onPressed: () async {
                if (_reply.text.trim().isEmpty) {
                  setState(() => _error = 'Type your reply.');
                  return;
                }
                try {
                  await Api.call('respondToLoanInfo', {'loanId': l.id, 'message': _reply.text.trim()});
                  _reply.clear();
                  if (context.mounted) toast(context, 'Reply sent');
                } catch (e) {
                  setState(() => _error = friendlyError(e));
                }
              },
            ),
          ],
          if (l.status == 'approved') ...[
            const SizedBox(height: 14),
            const Note('Your loan has been approved. MOM will send the money to you and let you know once it has been disbursed.', tone: Tone.success),
          ],
          if (l.status == 'submitted' || l.status == 'under_review') ...[
            const SizedBox(height: 10),
            const Text("MOM is reviewing your application. You'll get an email when there's an update.", style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ],
          if (l.hasOverdue) ...[const SizedBox(height: 14), Note('${naira(l.overdueAmount)} is overdue. Please contact MOM to pay.', tone: Tone.danger)],
          const SizedBox(height: 10),
          KV(running ? 'Original amount' : 'Amount', naira(l.amount)),
          if (running) ...[
            KV('Amount repaid', naira(l.amountRepaid)),
            KV('Outstanding balance', naira(l.outstanding)),
            KV('Next repayment', l.nextDueDate != null ? '${naira(l.nextDue)} on ${formatDay(l.nextDueDate)}' : '—'),
            KV('Disbursed', formatDay(l.disbursedAt)),
          ],
          KV('Repayment period', '${l.tenureMonths} month${l.tenureMonths == 1 ? '' : 's'}'),
          KV('Total to repay', naira(l.totalRepayable)),
          KV('Purpose', l.purpose),
          KV('Applied', formatDay(l.createdAt), last: true),
        ]),
      ),
      if (running && widget.instalments.isNotEmpty) ...[
        const SectionTitle('Repayment schedule'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < widget.instalments.length; i++) ...[if (i > 0) const Divider(height: 1), _InstalmentTile(widget.instalments[i])],
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Repayments are made to MOM directly and recorded by the admin team.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
      ],
    ]);
  }
}

class _InstalmentTile extends StatelessWidget {
  const _InstalmentTile(this.x);
  final Instalment x;
  @override
  Widget build(BuildContext context) {
    final late = !x.paid && x.dueDate != null && x.dueDate!.isBefore(DateTime.now());
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: x.paid ? const Color(0xFFE7F5EC) : late ? AppColors.redWash : AppColors.blueWash,
        child: Icon(x.paid ? Icons.check_rounded : Icons.schedule_rounded, color: x.paid ? const Color(0xFF1E7A46) : late ? AppColors.red : AppColors.blue, size: 20),
      ),
      title: Text('Instalment ${x.number}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Due ${formatDay(x.dueDate)}${x.paidAmount > 0 && !x.paid ? ' · ${naira(x.paidAmount)} paid' : ''}'),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(naira(x.amountDue), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        x.paid ? const Badge2('Paid', Tone.success) : late ? const Badge2('Overdue', Tone.danger) : x.paidAmount > 0 ? const Badge2('Part paid', Tone.pending) : const Badge2('Due', Tone.muted),
      ]),
    );
  }
}

class LoanApplyScreen extends StatefulWidget {
  const LoanApplyScreen({super.key});
  @override
  State<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends State<LoanApplyScreen> {
  Map<String, dynamic>? _settings;
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  final _notes = TextEditingController();
  int _tenor = 6;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic> r;
    try {
      r = await Api.call('getLoanSettings');
    } catch (_) {
      r = {'ratePctPerMonth': 0, 'minTenor': 1, 'maxTenor': 12};
    }
    if (!mounted) return;
    setState(() {
      _settings = r;
      final max = (r['maxTenor'] as num?)?.toInt() ?? 12;
      final min = (r['minTenor'] as num?)?.toInt() ?? 1;
      _tenor = math.min(max, math.max(min, _tenor));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (s.currentLoan != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Apply for a loan')),
        body: const PageBody(children: [Note('You already have a loan application or an active loan. You can apply again once it is completed.')]),
      );
    }
    final st = _settings;
    if (st == null) return Scaffold(appBar: AppBar(title: const Text('Apply for a loan')), body: const Center(child: CircularProgressIndicator()));
    final rate = (st['ratePctPerMonth'] as num?)?.toDouble() ?? 0;
    final minT = (st['minTenor'] as num?)?.toInt() ?? 1;
    final maxT = (st['maxTenor'] as num?)?.toInt() ?? 12;
    final minA = (st['minAmountKobo'] as num?)?.toInt() ?? 0;
    final maxA = (st['maxAmountKobo'] as num?)?.toInt() ?? 0;
    final p = parseKobo(_amount.text);
    final interest = p == null ? 0 : (p * rate * _tenor / 100).round();
    final total = (p ?? 0) + interest;
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for a loan')),
      body: PageBody(children: [
        MoneyField(
          controller: _amount,
          label: 'How much do you need?',
          hint: maxA > 0 ? 'Between ${naira(minA, decimals: false)} and ${naira(maxA, decimals: false)}.' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        TextField(controller: _purpose, maxLength: 300, decoration: const InputDecoration(labelText: 'What is the loan for?', hintText: 'e.g. Business stock, school fees', counterText: '')),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: math.min(maxT, math.max(minT, _tenor)),
          decoration: const InputDecoration(labelText: 'Preferred repayment period'),
          items: [for (var m = minT; m <= maxT; m++) DropdownMenuItem(value: m, child: Text('$m month${m == 1 ? '' : 's'}'))],
          onChanged: (v) => setState(() => _tenor = v ?? _tenor),
        ),
        const SizedBox(height: 14),
        TextField(controller: _notes, minLines: 3, maxLines: 6, maxLength: 1000, decoration: const InputDecoration(labelText: 'Additional notes (optional)', counterText: '')),
        const SizedBox(height: 14),
        AppCard(
          color: AppColors.greenWash,
          borderColor: Colors.transparent,
          child: p == null
              ? const Text('Enter an amount to see your estimated repayments.', style: TextStyle(color: AppColors.inkSoft))
              : Column(children: [
                  KV(rate > 0 ? 'Interest ($rate% per month)' : 'Interest', rate > 0 ? naira(interest) : 'None'),
                  KV('Total to repay', naira(total)),
                  KV('About each month', naira((total / _tenor).ceil()), last: true),
                ]),
        ),
        const SizedBox(height: 18),
        ErrorText(_error),
        BusyButton(
          label: 'Submit application',
          onPressed: () async {
            setState(() => _error = null);
            if (p == null) {
              setState(() => _error = 'Enter the amount you need.');
              return;
            }
            if (_purpose.text.trim().isEmpty) {
              setState(() => _error = 'Tell us what the loan is for.');
              return;
            }
            try {
              await Api.call('applyForLoan', {'amountKobo': p, 'tenorMonths': _tenor, 'purpose': _purpose.text.trim(), 'notes': _notes.text.trim()});
              if (!context.mounted) return;
              toast(context, 'Application submitted');
              Navigator.pop(context);
            } catch (e) {
              setState(() => _error = friendlyError(e));
            }
          },
        ),
        const SizedBox(height: 12),
        const Text("Submitting doesn't guarantee a loan. MOM reviews each application and may ask you for more information.",
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
      ]),
    );
  }
}
