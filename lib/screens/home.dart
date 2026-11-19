import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../activity.dart';
import '../format.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'groups.dart';
import 'history.dart';
import 'loans.dart';
import 'payment.dart';
import 'savings.dart';
import 'shell.dart';
import 'withdraw.dart';

void push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.profile!;
    final target = s.plans.where((x) => x.isTarget && x.percent < 100).firstOrNull ?? s.plans.where((x) => x.isTarget).firstOrNull;
    final contributions = s.plans.fold<int>(0, (a, x) => a + x.totalContributionsKobo);
    final count = s.plans.fold<int>(0, (a, x) => a + x.contributionsCount);
    final loan = s.currentLoan;
    final w = s.openWithdrawal;
    final recent = activityItems(s).take(5).toList();
    final infoNeeded = s.loans.any((l) => l.status == 'info_requested');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          Initials(p.name.isEmpty ? '?' : p.name, size: 36),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome back', style: TextStyle(fontSize: 12, color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
            Text('Hello, ${p.firstName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
      body: PageBody(children: [
        HeroCard(
          label: 'Total savings',
          amount: naira(p.walletBalance),
          children: [
            const SizedBox(height: 10),
            Wrap(spacing: 24, runSpacing: 8, children: [
              HeroStat('Available balance', naira(p.available)),
              if (p.withdrawalHold > 0) HeroStat('Held for withdrawal', naira(p.withdrawalHold)),
            ]),
          ],
          actions: [
            HeroButton(label: 'Save money', icon: Icons.add_rounded, onTap: () => push(context, const PayScreen())),
            HeroButton(label: 'Withdraw', icon: Icons.north_rounded, filled: false, onTap: () => push(context, const WithdrawScreen())),
          ],
        ),
        if (infoNeeded) ...[
          const SizedBox(height: 12),
          GestureDetector(onTap: () => AppShell.of(context)?.go(3), child: const Note('MOM needs more information about your loan. Tap to reply.')),
        ],
        if (w != null) ...[const SizedBox(height: 12), Note('Withdrawal of ${naira(w.amount)}: ${withdrawalLabel(w.status)}.')],
        const SizedBox(height: 18),
        Row(children: [
          _Quick(icon: Icons.add_rounded, label: 'Save\nmoney', onTap: () => push(context, const PayScreen())),
          _Quick(icon: Icons.savings_outlined, label: 'My\nsavings', onTap: () => AppShell.of(context)?.go(1)),
          _Quick(icon: Icons.north_rounded, label: 'Withdraw', onTap: () => push(context, const WithdrawScreen())),
          _Quick(icon: Icons.payments_outlined, label: 'Apply for\nloan', onTap: () => push(context, const LoanApplyScreen())),
          _Quick(icon: Icons.receipt_long_outlined, label: 'History', onTap: () => push(context, const HistoryScreen())),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _Stat('Active plans', '${s.plans.length}')),
          const SizedBox(width: 10),
          Expanded(child: _Stat('Total contributions', naira(contributions, decimals: false), sub: '$count payment${count == 1 ? '' : 's'}')),
        ]),
        const SizedBox(height: 10),
        if (target != null)
          AppCard(
            onTap: () => push(context, PlanScreen(planId: target.id)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current savings target · ${target.name}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text.rich(TextSpan(text: naira(target.savedKobo, decimals: false), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700), children: [
                TextSpan(text: '  of ${naira(target.targetKobo, decimals: false)}', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
              ])),
              const SizedBox(height: 10),
              ProgressLine(target.percent),
            ]),
          )
        else
          AppCard(
            onTap: () => push(context, const NewPlanScreen(target: true)),
            child: const Text.rich(TextSpan(text: 'No savings target yet. ', style: TextStyle(color: AppColors.inkSoft), children: [
              TextSpan(text: 'Set a savings goal →', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
            ])),
          ),
        if (loan != null) ...[
          const SizedBox(height: 10),
          AppCard(
            onTap: () => AppShell.of(context)?.go(3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loan.isRunning ? 'Outstanding loan balance' : 'Loan application', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(naira(loan.isRunning ? loan.outstanding : loan.amount), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
                loanBadge(loan.status),
              ]),
              if (loan.isRunning && loan.nextDueDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Next repayment ${naira(loan.nextDue)} due ${formatDay(loan.nextDueDate)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        const HomeGroupsCard(),
        SectionTitle('Recent activity', trailing: TextButton(onPressed: () => push(context, const HistoryScreen()), child: const Text('See all'))),
        ActivityList(recent, empty: 'No transactions yet. Make your first savings payment to get started.'),
      ]),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: Icon(icon, color: AppColors.green),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.sub});
  final String label, value;
  final String? sub;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          if (sub != null) Text(sub!, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ]),
      );
}
