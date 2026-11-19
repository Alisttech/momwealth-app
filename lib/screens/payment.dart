import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Starts a Squad checkout and shows the result screen.
/// Squad opens in an in-app browser (Safari view on iPhone). After paying, Squad sends the member to
/// payment-complete.html on the portal, which hands back to the app through momwealth://payment.
/// The result screen asks the backend to verify with Squad, so nothing is credited on the app's word.
class PaymentFlow {
  /// target: {'planId': id} | {'groupId': id} | {'ajoId': id}
  static Future<void> start(BuildContext context, Map<String, dynamic> target, int? amountKobo) async {
    final res = await Api.startPayment(target, amountKobo);
    final ref = '${res['reference']}';
    final url = Uri.parse('${res['checkoutUrl']}');
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(settings: RouteSettings(name: 'payment:$ref'), builder: (_) => PaymentResultScreen(reference: ref)));
    await launchUrl(url, mode: LaunchMode.inAppBrowserView);
  }

  /// Called when the app is opened from momwealth://payment?ref=...
  static Future<void> returned(String ref) async {
    try {
      await closeInAppWebView();
    } catch (_) {}
  }
}

class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({super.key, required this.reference});
  final String reference;
  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> with WidgetsBindingObserver {
  bool _checking = false;
  bool _gaveUp = false;
  Timer? _timer;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // First check once the member has had time to pay; resuming the app triggers one immediately.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    final p = context.read<Session>().payment(widget.reference);
    if (p != null && (p.credited || const ['failed', 'abandoned', 'review'].contains(p.status))) {
      _timer?.cancel();
      return;
    }
    _checking = true;
    try {
      final r = await Api.confirmPayment(widget.reference);
      if (r['status'] != 'pending') _timer?.cancel();
    } catch (_) {}
    _checking = false;
    _tries++;
    if (_tries >= 36 && mounted) {
      // About 3 minutes. The backend keeps checking every 15 minutes on its own.
      _timer?.cancel();
      setState(() => _gaveUp = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.payment(widget.reference);
    Widget body;
    if (p != null && (p.credited || p.status == 'successful')) {
      final plan = p.kind == 'plan' ? s.plan(p.creditedPlanId ?? p.planId ?? '') : null;
      body = _Result(
        icon: Icons.check_rounded,
        iconBg: const Color(0xFFE7F5EC),
        iconFg: const Color(0xFF1E7A46),
        title: 'Payment successful',
        message: '${naira(p.amountKobo)} has been added to ${p.planName}.${plan != null ? '\nPlan balance: ${naira(plan.savedKobo)}' : ''}',
        foot: 'Reference ${widget.reference} · A receipt has been sent to your email.',
        primary: 'Done',
      );
    } else if (p != null && (p.status == 'failed' || p.status == 'abandoned')) {
      body = const _Result(
        icon: Icons.close_rounded,
        iconBg: AppColors.redWash,
        iconFg: AppColors.red,
        title: 'Payment not completed',
        message: 'Nothing was added to your savings. If money left your account, your bank normally reverses it automatically.',
        primary: 'Close',
      );
    } else if (p != null && p.status == 'review') {
      body = _Result(
        icon: Icons.schedule_rounded,
        iconBg: AppColors.goldWash,
        iconFg: AppColors.gold,
        title: 'Payment under review',
        message: 'MOM is checking this payment and will add it to your savings once confirmed.',
        foot: 'Reference ${widget.reference}',
        primary: 'Close',
      );
    } else if (_gaveUp) {
      body = _Result(
        icon: Icons.schedule_rounded,
        iconBg: AppColors.goldWash,
        iconFg: AppColors.gold,
        title: 'Still processing',
        message: "Squad hasn't confirmed this payment yet. We'll keep checking and update your savings automatically. You can leave this screen.",
        foot: 'Reference ${widget.reference}',
        primary: 'Close',
      );
    } else {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 22),
        const Text('Confirming your payment…', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Complete the payment in the Squad window. We confirm it with Squad as soon as you\'re done.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft, height: 1.45)),
        const SizedBox(height: 24),
        TextButton(onPressed: _check, child: const Text('I\'ve paid – check now')),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Payment'), automaticallyImplyLeading: false),
      body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: body))),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.icon, required this.iconBg, required this.iconFg, required this.title, required this.message, this.foot, required this.primary});
  final IconData icon;
  final Color iconBg, iconFg;
  final String title, message, primary;
  final String? foot;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 76, height: 76, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle), child: Icon(icon, color: iconFg, size: 38)),
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
        if (foot != null) ...[const SizedBox(height: 12), Text(foot!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5))],
        const SizedBox(height: 26),
        ElevatedButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: Text(primary)),
      ]);
}

/// Opens the payment screen for a plan, group or Ajo circle, asking for an amount where needed.
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, this.planId, this.groupId, this.ajoId});
  final String? planId, groupId, ajoId;
  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final _amount = TextEditingController();
  String? _planId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    if (widget.groupId == null && widget.ajoId == null) {
      _planId = widget.planId ?? (s.plans.isNotEmpty ? s.plans.first.id : null);
      final p = _planId == null ? null : s.plan(_planId!);
      if (p != null && p.contributionKobo > 0) _amount.text = formatAmountField(p.contributionKobo);
    } else if (widget.groupId != null) {
      final g = s.group(widget.groupId!);
      if (g != null && g.contributionKobo > 0) _amount.text = formatAmountField(g.contributionKobo);
    }
  }

  Future<void> _pay(Map<String, dynamic> target, int? amount) async {
    setState(() => _error = null);
    try {
      await PaymentFlow.start(context, target, amount);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    const help = "You'll pay securely with Squad by card, bank transfer or USSD. It's recorded as soon as Squad confirms the payment, and you'll get an email receipt.";

    if (widget.ajoId != null) {
      final a = s.ajo(widget.ajoId!);
      final i = a?.nextUnpaid(s.uid) ?? -1;
      return Scaffold(
        appBar: AppBar(title: const Text('Pay Ajo contribution')),
        body: PageBody(children: [
          if (a == null || a.status != 'active' || i < 0)
            Note(a?.status == 'forming' ? "This circle hasn't started yet. MOM will email you when it starts." : 'You have no contribution due for this circle.')
          else ...[
            AppCard(
              child: Column(children: [
                KV('Circle', a.name),
                KV('Round', '${i + 1} of ${a.rounds}'),
                KV('Due', formatDay(a.dueDate(i))),
                KV('This round goes to', a.payoutOrder[i] == s.uid ? 'You' : a.nameOf(a.payoutOrder[i])),
                KV('Amount', naira(a.contributionKobo), last: true),
              ]),
            ),
            const SizedBox(height: 14),
            const Text(help, style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.45)),
            const SizedBox(height: 16),
            ErrorText(_error),
            BusyButton(label: 'Pay ${naira(a.contributionKobo)}', onPressed: () => _pay({'ajoId': a.id}, null)),
          ],
        ]),
      );
    }

    final group = widget.groupId == null ? null : s.group(widget.groupId!);
    return Scaffold(
      appBar: AppBar(title: Text(group != null ? 'Save to group' : 'Save money')),
      body: PageBody(children: [
        if (group != null)
          AppCard(child: KV('Group', group.name, last: true))
        else
          DropdownButtonFormField<String>(
            initialValue: _planId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Savings plan'),
            items: [for (final p in s.plans.where((p) => p.status == 'active')) DropdownMenuItem(value: p.id, child: Text('${p.name} (${naira(p.savedKobo, decimals: false)})', overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _planId = v),
          ),
        const SizedBox(height: 16),
        MoneyField(
          controller: _amount,
          label: 'Amount',
          hint: group != null && group.contributionKobo > 0
              ? "The group's suggested contribution is ${naira(group.contributionKobo, decimals: false)}${group.frequency != 'flexible' ? ' per ${frequencyEvery[group.frequency]}' : ''}."
              : null,
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in const [100000, 500000, 1000000, 2000000, 5000000])
            ActionChip(label: Text(naira(k, decimals: false)), onPressed: () => setState(() => _amount.text = formatAmountField(k))),
        ]),
        const SizedBox(height: 16),
        const Text(help, style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.45)),
        const SizedBox(height: 16),
        ErrorText(_error),
        BusyButton(
          label: 'Save now',
          onPressed: () async {
            final k = parseKobo(_amount.text);
            if (k == null) {
              setState(() => _error = 'Enter the amount you want to save.');
            } else if (group != null) {
              await _pay({'groupId': group.id}, k);
            } else if (_planId == null) {
              setState(() => _error = 'Choose a savings plan.');
            } else {
              await _pay({'planId': _planId}, k);
            }
          },
        ),
      ]),
    );
  }
}
