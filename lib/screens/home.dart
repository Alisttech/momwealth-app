import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../activity.dart';
import '../format.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account.dart';
import 'groups.dart';
import 'history.dart';
import 'kyc.dart' show promptVerification, openVerification;
import 'loans.dart';
import 'notifications.dart';
import 'vendors.dart';
import 'payment.dart';
import 'savings.dart';
import 'shell.dart';
import 'withdraw.dart';

/// Opens a page. Pages that move money or join groups need a verified member; others are open to all.
void push(BuildContext context, Widget page) {
  final needsVerification = page is PayScreen || page is NewPlanScreen || page is WithdrawScreen || page is LoanApplyScreen ||
      page is NewGroupScreen || page is NewAjoScreen || page is JoinScreen;
  if (needsVerification && context.read<Session>().profile?.verified != true) {
    promptVerification(context);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.profile!;
    final target = s.plans.where((x) => x.isTarget && x.percent < 100).firstOrNull ?? s.plans.where((x) => x.isTarget).firstOrNull;
    final loan = s.currentLoan;
    final w = s.openWithdrawal;
    final recent = activityItems(s).take(5).toList();
    final infoNeeded = s.loans.any((l) => l.status == 'info_requested');

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => push(context, const NotificationsScreen()),
            icon: Badge(
              isLabelVisible: s.unreadCount > 0,
              label: Text(s.unreadCount > 9 ? '9+' : '${s.unreadCount}'),
              backgroundColor: AppColors.red,
              child: const Icon(Icons.notifications_none_rounded, size: 26),
            ),
          ),
          const SizedBox(width: 6),
        ],
        titleSpacing: 16,
        title: Row(children: [
          MemberAvatar(profile: p, email: s.user?.email ?? '', size: 36),
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
        if (!p.verified) ...[
          const SizedBox(height: 12),
          AppCard(
            onTap: () => openVerification(context),
            color: AppColors.goldWash,
            borderColor: Colors.transparent,
            child: const Row(children: [
              Icon(Icons.verified_user_outlined, color: AppColors.gold),
              SizedBox(width: 12),
              Expanded(
                child: Text('Verify your identity to start saving, join groups and Ajo, withdraw or apply for a loan.',
                    style: TextStyle(fontSize: 13.5, height: 1.4)),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.gold),
            ]),
          ),
        ],
        if (p.hasAccount) ...[
          const SizedBox(height: 12),
          AppCard(
            onTap: () => push(context, const AccountCardScreen()),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.greenWash, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_outlined, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Save by transfer · ${p.accountBank}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
                  Text(groupAccountNumber(p.accountNumber), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.green),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: p.accountNumber));
                  toast(context, 'Account number copied');
                },
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ]),
          ),
        ],
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
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: _Promo(
                icon: Icons.local_offer_outlined,
                title: 'Vendor discounts',
                text: s.offers.isEmpty ? 'Member deals from our partners' : '${s.offers.length} member deal${s.offers.length == 1 ? '' : 's'} available',
                onTap: () => push(context, const VendorOffersScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Promo(
                icon: Icons.groups_2_outlined,
                title: 'Save together',
                text: s.groups.isEmpty && s.ajos.isEmpty ? 'Start a group goal or an Ajo circle' : 'Your groups and Ajo circles',
                onTap: () => AppShell.of(context)?.go(2),
              ),
            ),
          ]),
        ),
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

/// Solid green tile on Home (vendor discounts, group savings).
class _Promo extends StatelessWidget {
  const _Promo({required this.icon, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: Colors.white, size: 19),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
              ]),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ),
      );
}
