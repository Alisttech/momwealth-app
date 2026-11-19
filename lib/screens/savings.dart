import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../activity.dart';
import '../format.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart' show push;
import 'payment.dart';
import 'withdraw.dart';

class SavingsTab extends StatelessWidget {
  const SavingsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('My savings')),
      body: PageBody(children: [
        HeroCard(
          label: 'Total savings',
          amount: naira(p.walletBalance),
          children: [const SizedBox(height: 8), HeroStat('Available', naira(p.available))],
          actions: [
            HeroButton(label: 'Save money', icon: Icons.add_rounded, onTap: () => push(context, const PayScreen())),
            HeroButton(label: 'New plan', icon: Icons.flag_outlined, filled: false, onTap: () => push(context, const NewPlanScreen())),
          ],
        ),
        const SectionTitle('Your plans'),
        if (s.plans.isEmpty) const EmptyCard('No savings plans yet.'),
        for (final plan in s.plans) ...[PlanCard(plan), const SizedBox(height: 10)],
        const SizedBox(height: 6),
        OutlinedButton.icon(onPressed: () => push(context, const WithdrawScreen()), icon: const Icon(Icons.north_rounded), label: const Text('Request a withdrawal')),
      ]),
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard(this.plan, {super.key});
  final SavingsPlan plan;
  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => push(context, PlanScreen(planId: plan.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.greenWash, borderRadius: BorderRadius.circular(12)),
            child: Icon(plan.isTarget ? Icons.flag_rounded : Icons.savings_rounded, color: AppColors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              Text('${plan.isTarget ? 'Target savings' : 'Flexible savings'} · ${frequencyLabel[plan.frequency] ?? 'Flexible'}',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ]),
          ),
          if (plan.heldKobo > 0)
            Badge2('${naira(plan.heldKobo, decimals: false)} held', Tone.pending)
          else if (plan.isTarget && plan.percent >= 100)
            const Badge2('Target reached', Tone.success),
        ]),
        const SizedBox(height: 12),
        Text(naira(plan.savedKobo), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (plan.isTarget) ...[
          ProgressLine(plan.percent),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('${plan.percent}% of ${naira(plan.targetKobo, decimals: false)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5))),
            if (plan.maturityDate != null) Text('Matures ${formatDay(plan.maturityDate)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          ]),
        ] else
          Text(plan.nextContributionDue != null ? 'Next contribution ${formatDay(plan.nextContributionDue)}' : 'Save any amount, any time',
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
      ]),
    );
  }
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.planId});
  final String planId;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.plan(planId);
    if (p == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('This plan was not found.')));
    final rows = activityItems(s).where((it) => it.place == p.name && it.filter != 'groups').toList();
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: PageBody(children: [
        HeroCard(
          label: p.isTarget ? 'Saved towards ${naira(p.targetKobo, decimals: false)}' : 'Amount saved',
          amount: naira(p.savedKobo),
          children: [
            if (p.isTarget) ...[const SizedBox(height: 4), ProgressLine(p.percent, onDark: true), const SizedBox(height: 8), HeroStat('Progress', '${p.percent}% of target')],
          ],
          actions: [
            HeroButton(label: 'Save now', icon: Icons.add_rounded, onTap: () => push(context, PayScreen(planId: p.id))),
            HeroButton(label: 'Withdraw', icon: Icons.north_rounded, filled: false, onTap: () => push(context, WithdrawScreen(planId: p.id))),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(children: [
            KV('Target amount', p.isTarget ? naira(p.targetKobo) : 'No target'),
            KV('Amount saved', naira(p.savedKobo)),
            KV('Available to withdraw', naira(p.available)),
            KV('Contribution frequency', '${frequencyLabel[p.frequency] ?? 'Flexible'}${p.contributionKobo > 0 ? ' · ${naira(p.contributionKobo, decimals: false)}' : ''}'),
            KV('Next expected contribution', p.nextContributionDue != null ? formatDay(p.nextContributionDue) : 'Any time'),
            KV('Status', p.status == 'active' ? 'Active' : p.status),
            KV('Start date', formatDay(p.startDate ?? p.createdAt)),
            KV('Maturity date', p.maturityDate != null ? formatDay(p.maturityDate) : '—', last: true),
          ]),
        ),
        const SectionTitle('Plan history'),
        ActivityList(rows, empty: 'No payments into this plan yet.'),
      ]),
    );
  }
}

class NewPlanScreen extends StatefulWidget {
  const NewPlanScreen({super.key, this.target = true});
  final bool target;
  @override
  State<NewPlanScreen> createState() => _NewPlanScreenState();
}

class _NewPlanScreenState extends State<NewPlanScreen> {
  late bool _target = widget.target;
  final _name = TextEditingController();
  final _targetAmt = TextEditingController();
  final _contrib = TextEditingController();
  String _freq = 'monthly';
  DateTime? _maturity;
  String? _error;

  Future<void> _create() async {
    setState(() => _error = null);
    final name = _name.text.trim();
    final targetKobo = parseKobo(_targetAmt.text);
    if (name.isEmpty) {
      setState(() => _error = 'Give your plan a name.');
      return;
    }
    if (_target && targetKobo == null) {
      setState(() => _error = 'Enter your target amount.');
      return;
    }
    try {
      final r = await Api.call('createSavingsPlan', {
        'name': name,
        'planType': _target ? 'target' : 'general',
        'frequency': _freq,
        'targetKobo': _target ? targetKobo : 0,
        'contributionKobo': parseKobo(_contrib.text) ?? 0,
        'maturityDate': _target && _maturity != null ? isoDay(_maturity!) : null,
      });
      if (!mounted) return;
      toast(context, 'Plan created');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PlanScreen(planId: '${r['planId']}')));
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New savings plan')),
      body: PageBody(children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: true, label: Text('Target savings')), ButtonSegment(value: false, label: Text('Flexible'))],
          selected: {_target},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => _target = v.first),
        ),
        const SizedBox(height: 18),
        TextField(controller: _name, maxLength: 60, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Plan name', hintText: 'e.g. School fees, Rent, Business', counterText: '')),
        if (_target) ...[const SizedBox(height: 14), MoneyField(controller: _targetAmt, label: 'Target amount')],
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _freq,
          decoration: const InputDecoration(labelText: 'How often will you save?'),
          items: const [
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'flexible', child: Text('Flexible (any time)')),
          ],
          onChanged: (v) => setState(() => _freq = v ?? 'monthly'),
        ),
        const SizedBox(height: 14),
        MoneyField(controller: _contrib, label: 'Amount each time (optional)', hint: "We'll suggest this amount when you save."),
        if (_target) ...[
          const SizedBox(height: 14),
          DateField(label: 'Maturity date (optional)', value: _maturity, onChanged: (d) => setState(() => _maturity = d)),
        ],
        const SizedBox(height: 22),
        ErrorText(_error),
        BusyButton(label: 'Create plan', onPressed: _create),
      ]),
    );
  }
}

/// Tappable field that opens a date picker for a future date.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now.add(const Duration(days: 180)),
          firstDate: now.add(const Duration(days: 1)),
          lastDate: DateTime(now.year + 20),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null ? const Icon(Icons.calendar_today_outlined, size: 18) : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null)),
        ),
        child: Text(value == null ? 'Choose a date' : formatDay(value), style: TextStyle(color: value == null ? AppColors.inkSoft : AppColors.ink)),
      ),
    );
  }
}
