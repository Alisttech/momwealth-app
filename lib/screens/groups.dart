import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../activity.dart';
import '../format.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home.dart' show push;
import 'payment.dart';
import 'savings.dart' show DateField;
import 'withdraw.dart';

const _ajoStatus = {'forming': ('Waiting to start', Tone.pending), 'active': ('Active', Tone.success), 'completed': ('Completed', Tone.muted), 'cancelled': ('Cancelled', Tone.muted)};
Widget ajoBadge(String s) => Badge2(_ajoStatus[s]?.$1 ?? s, _ajoStatus[s]?.$2 ?? Tone.muted);

/// Summary card on the Home tab.
class HomeGroupsCard extends StatelessWidget {
  const HomeGroupsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final gs = s.activeGroups;
    final ajos = s.ajos.where((a) => a.status == 'forming' || a.status == 'active').toList();
    if (gs.isEmpty && ajos.isEmpty) {
      return AppCard(
        onTap: () => push(context, const GroupsTab(standalone: true)),
        child: const Text.rich(TextSpan(text: 'Save with others towards a shared goal, or join an Ajo circle. ', style: TextStyle(color: AppColors.inkSoft), children: [
          TextSpan(text: 'Get started →', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700)),
        ])),
      );
    }
    final share = gs.fold<int>(0, (a, g) => a + (g.member(s.uid)?.balance ?? 0));
    final due = ajos.where((a) => a.status == 'active' && a.nextUnpaid(s.uid) >= 0).toList()
      ..sort((a, b) => a.dueDate(a.nextUnpaid(s.uid)).compareTo(b.dueDate(b.nextUnpaid(s.uid))));
    return AppCard(
      onTap: () => push(context, const GroupsTab(standalone: true)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Group savings & Ajo', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(text: naira(share), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700), children: [
          TextSpan(text: '  your share in ${gs.length} group${gs.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
        ])),
        if (due.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Next Ajo payment: ${naira(due.first.contributionKobo)} for ${due.first.name}, due ${formatDay(due.first.dueDate(due.first.nextUnpaid(s.uid)))}',
                style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          ),
      ]),
    );
  }
}

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key, this.standalone = false});
  final bool standalone;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final ajos = s.ajos.where((a) => a.status != 'cancelled').toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Groups'), automaticallyImplyLeading: standalone),
      body: PageBody(children: [
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: () => push(context, const JoinScreen()), child: const Text('Join with a code'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: () => _startSheet(context), icon: const Icon(Icons.add_rounded), label: const Text('Start one'))),
        ]),
        const SectionTitle('Group savings'),
        const Text("Save together towards one goal. Everyone sees the group's progress, and you can only ever withdraw your own share.",
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        if (s.activeGroups.isEmpty) const EmptyCard("You're not in a savings group yet."),
        for (final g in s.activeGroups) ...[_GroupCard(g), const SizedBox(height: 10)],
        const SectionTitle('Ajo / Esusu circles'),
        const Text('Everyone pays the same amount each round and one member collects the whole pot, in turn, until everyone has collected.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        if (ajos.isEmpty) const EmptyCard("You're not in an Ajo circle yet."),
        for (final a in ajos) ...[_AjoCard(a), const SizedBox(height: 10)],
      ]),
    );
  }

  void _startSheet(BuildContext context) {
    showAppSheet(context, title: 'What would you like to start?', builder: (ctx) {
      Widget option(String title, String sub, IconData icon, Widget page) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () {
                Navigator.pop(ctx);
                push(context, page);
              },
              child: Row(children: [
                CircleAvatar(backgroundColor: AppColors.greenWash, child: Icon(icon, color: AppColors.green)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          );
      return Column(children: [
        option('Group savings', 'A shared pot towards a goal, like a project, a trip or an event.', Icons.groups_rounded, const NewGroupScreen()),
        option('Ajo / Esusu circle', 'A fixed contribution each round; members take turns collecting the pot.', Icons.autorenew_rounded, const NewAjoScreen()),
      ]);
    });
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard(this.g);
  final SavingsGroup g;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<Session>().uid;
    return AppCard(
      onTap: () => push(context, GroupScreen(groupId: g.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              Text('Group savings · ${g.memberIds.length} member${g.memberIds.length == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ]),
          ),
          if (g.percent >= 100) const Badge2('Target reached', Tone.success),
        ]),
        const SizedBox(height: 10),
        Text(naira(g.savedKobo), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ProgressLine(g.percent),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${g.percent}% of ${naira(g.targetKobo, decimals: false)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5))),
          Text('Your share ${naira(g.member(uid)?.balance ?? 0, decimals: false)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        ]),
      ]),
    );
  }
}

class _AjoCard extends StatelessWidget {
  const _AjoCard(this.a);
  final AjoCircle a;
  @override
  Widget build(BuildContext context) {
    final uid = context.read<Session>().uid;
    final i = a.status == 'active' ? a.nextUnpaid(uid) : -1;
    final pos = a.payoutOrder.indexOf(uid);
    return AppCard(
      onTap: () => push(context, AjoScreen(ajoId: a.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              Text('Ajo · ${naira(a.contributionKobo, decimals: false)} per ${frequencyEvery[a.frequency]} · ${a.memberIds.length}/${a.maxMembers} members',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ]),
          ),
          ajoBadge(a.status),
        ]),
        const SizedBox(height: 10),
        Text.rich(TextSpan(text: naira(a.contributionKobo * (a.status == 'forming' ? a.maxMembers : a.rounds), decimals: false), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700), children: const [
          TextSpan(text: '  pot per round', style: TextStyle(fontSize: 13, color: AppColors.inkSoft, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: Text(a.status == 'active' ? 'Round ${(a.currentCycleIndex + 1).clamp(1, a.rounds)} of ${a.rounds}' : a.status == 'forming' ? 'Waiting for MOM to start' : '',
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5))),
          if (pos >= 0 && a.status == 'active') Text('You collect in round ${pos + 1}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        ]),
        if (i >= 0) ...[const SizedBox(height: 10), Note('Your next payment: ${naira(a.contributionKobo)} due ${formatDay(a.dueDate(i))}')],
      ]),
    );
  }
}

/// Join code box with copy and WhatsApp share.
class ShareCode extends StatelessWidget {
  const ShareCode({super.key, required this.code, required this.name, required this.isAjo});
  final String code, name;
  final bool isAjo;
  @override
  Widget build(BuildContext context) {
    final link = context.watch<Session>().appLink;
    final msg = 'Join my ${isAjo ? 'Ajo circle' : 'savings group'} "$name" on the MOM Wealth app. Open Groups, tap "Join with a code" and enter: $code'
        '${link.isEmpty ? '' : '\n\nGet the app: $link'}';
    return AppCard(
      color: AppColors.goldWash,
      borderColor: const Color(0xFFEED9B8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Invite members with this code', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        const SizedBox(height: 6),
        Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                toast(context, 'Code copied');
              },
              child: const Text('Copy'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication),
              child: const Text('Share on WhatsApp'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key, required this.groupId});
  final String groupId;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final g = s.group(groupId);
    if (g == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text("This group was not found, or you're no longer a member.")));
    final me = g.member(s.uid);
    final members = g.members.values.toList()..sort((a, b) => b.balance.compareTo(a.balance));
    final rows = activityItems(s).where((it) => it.place == g.name && it.filter == 'groups').toList();
    final canWithdraw = !g.locked && (me?.available ?? 0) > 0;
    return Scaffold(
      appBar: AppBar(title: Text(g.name)),
      body: PageBody(children: [
        HeroCard(
          label: 'Group total · target ${naira(g.targetKobo, decimals: false)}',
          amount: naira(g.savedKobo),
          children: [
            const SizedBox(height: 4),
            ProgressLine(g.percent, onDark: true),
            const SizedBox(height: 12),
            Wrap(spacing: 22, runSpacing: 8, children: [
              HeroStat('Your share', naira(me?.balance ?? 0)),
              HeroStat('Progress', '${g.percent}%'),
              HeroStat('Members', '${members.length}'),
            ]),
          ],
          actions: [
            if (g.status == 'active') HeroButton(label: 'Contribute', icon: Icons.add_rounded, onTap: () => push(context, PayScreen(groupId: g.id))),
            HeroButton(label: 'Withdraw', icon: Icons.north_rounded, filled: false, onTap: canWithdraw ? () => push(context, WithdrawScreen(groupId: g.id)) : null),
          ],
        ),
        if (g.locked) ...[const SizedBox(height: 12), Note('Savings in this group unlock on ${formatDay(g.maturityDate)}. You can withdraw your share from then.')],
        if (g.status == 'active') ...[const SizedBox(height: 12), ShareCode(code: g.joinCode, name: g.name, isAjo: false)],
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (g.description.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(g.description)),
            KV('Started by', g.createdByName),
            KV('Suggested contribution',
                g.contributionKobo > 0 ? '${naira(g.contributionKobo, decimals: false)}${g.frequency != 'flexible' ? ' per ${frequencyEvery[g.frequency]}' : ''}' : 'Any amount'),
            KV('Maturity date', g.maturityDate != null ? formatDay(g.maturityDate) : '—'),
            KV('Withdrawals', g.withdrawalRule == 'maturity' ? 'After maturity' : 'Any time (own share)'),
            KV("You've contributed", naira(me?.contributed ?? 0), last: (me?.held ?? 0) == 0),
            if ((me?.held ?? 0) > 0) KV('Held for your withdrawal', naira(me!.held), last: true),
          ]),
        ),
        SectionTitle('Members', trailing: Text('${members.length}/${g.maxMembers}', style: const TextStyle(color: AppColors.inkSoft))),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < members.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Initials(members[i].name),
                title: Text('${members[i].name}${members[i].uid == s.uid ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(members[i].role == 'creator' ? 'Started the group' : 'Member'),
                trailing: Text(naira(members[i].balance), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ]),
        ),
        const SectionTitle('Your activity'),
        ActivityList(rows, empty: "You haven't contributed yet."),
        if ((me?.balance ?? 0) <= 0 && (me?.held ?? 0) <= 0) ...[
          const SizedBox(height: 18),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
            onPressed: () async {
              final ok = await confirmSheet(context, title: 'Leave ${g.name}?', message: 'You can rejoin later with the code.', confirmLabel: 'Leave', danger: true);
              if (!ok) return;
              try {
                await Api.call('leaveSavingsGroup', {'groupId': g.id});
                if (!context.mounted) return;
                toast(context, 'You left the group');
                Navigator.pop(context);
              } catch (e) {
                if (context.mounted) toast(context, friendlyError(e));
              }
            },
            child: const Text('Leave group'),
          ),
        ],
      ]),
    );
  }
}

class AjoScreen extends StatelessWidget {
  const AjoScreen({super.key, required this.ajoId});
  final String ajoId;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final a = s.ajo(ajoId);
    if (a == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text("This circle was not found, or you're no longer a member.")));
    final uid = s.uid;
    final pos = a.payoutOrder.indexOf(uid);
    final next = a.status == 'active' ? a.nextUnpaid(uid) : -1;
    final myBank = s.bankForAjo(a.id);
    final gotPaid = a.payouts.values.any((p) => p.uid == uid);
    return Scaffold(
      appBar: AppBar(title: Text(a.name)),
      body: PageBody(children: [
        HeroCard(
          label: "Each round's pot · ${naira(a.contributionKobo, decimals: false)} per ${frequencyEvery[a.frequency]} × ${a.rounds} members",
          amount: naira(a.pot),
          children: [
            const SizedBox(height: 10),
            Wrap(spacing: 22, runSpacing: 8, children: [
              HeroStat('Status', _ajoStatus[a.status]?.$1 ?? a.status),
              if (pos >= 0) HeroStat('Your turn', 'Round ${pos + 1} · ${formatDay(a.dueDate(pos))}'),
            ]),
          ],
          actions: [
            if (next >= 0)
              HeroButton(
                  label: 'Pay ${naira(a.contributionKobo, decimals: false)} for round ${next + 1}',
                  icon: Icons.add_rounded,
                  onTap: () => push(context, PayScreen(ajoId: a.id))),
          ],
        ),
        const SizedBox(height: 12),
        if (a.status == 'forming') ...[
          Note('Waiting for members to join. MOM will start the circle and email everyone their turn to collect. ${a.memberIds.length}/${a.maxMembers} joined.'),
          const SizedBox(height: 12),
          ShareCode(code: a.joinCode, name: a.name, isAjo: true),
          const SizedBox(height: 12),
        ],
        if (a.status == 'active' && next < 0) ...[const Note("You're up to date with your contributions.", tone: Tone.success), const SizedBox(height: 12)],
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KV('Contribution', '${naira(a.contributionKobo)} per ${frequencyEvery[a.frequency]}'),
            KV('Each member collects', naira(a.pot)),
            KV('Started by', a.createdByName),
            if (a.startDate != null) KV('First round due', formatDay(a.startDate)),
            KV('Your payout account', myBank == null ? '—' : '${myBank.accountName}\n${myBank.bank} ${myBank.accountNumber}', last: true),
            if (!gotPaid)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => _changeBank(context, a, myBank), child: const Text('Change payout account')),
              ),
          ]),
        ),
        SectionTitle(a.status == 'forming' ? 'Members' : 'Payout order'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (a.status == 'forming')
              for (var i = 0; i < a.memberIds.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  leading: Initials(a.nameOf(a.memberIds[i]), color: AppColors.purpleWash, fg: AppColors.purple),
                  title: Text('${a.nameOf(a.memberIds[i])}${a.memberIds[i] == uid ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(a.roleOf(a.memberIds[i]) == 'creator' ? 'Started the circle' : 'Joined'),
                ),
              ]
            else
              for (var i = 0; i < a.payoutOrder.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _RoundTile(a: a, i: i, uid: uid),
              ],
          ]),
        ),
        if (a.status == 'forming') ...[
          const SizedBox(height: 10),
          const Text('The payout order is fixed when MOM starts the circle.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          if (a.roleOf(uid) != 'creator') ...[
            const SizedBox(height: 18),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
              onPressed: () async {
                final ok = await confirmSheet(context, title: 'Leave ${a.name}?', message: 'You can rejoin with the code while the circle is still forming.', confirmLabel: 'Leave', danger: true);
                if (!ok) return;
                try {
                  await Api.call('leaveAjo', {'ajoId': a.id});
                  if (!context.mounted) return;
                  toast(context, 'You left the circle');
                  Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) toast(context, friendlyError(e));
                }
              },
              child: const Text('Leave circle'),
            ),
          ],
        ],
      ]),
    );
  }

  void _changeBank(BuildContext context, AjoCircle a, BankDetails? current) {
    final c = BankFieldsController(current);
    String? error;
    showAppSheet(context, title: 'Payout account', builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setSheet) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BankFields(controller: c),
          const SizedBox(height: 16),
          ErrorText(error),
          BusyButton(
            label: 'Save',
            onPressed: () async {
              final err = c.validate();
              if (err != null) {
                setSheet(() => error = err);
                return;
              }
              try {
                await Api.call('updateAjoBank', {'ajoId': a.id, 'bank': c.value.toMap()});
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) toast(context, 'Payout account updated');
              } catch (e) {
                setSheet(() => error = friendlyError(e));
              }
            },
          ),
        ]);
      });
    });
  }
}

class _RoundTile extends StatelessWidget {
  const _RoundTile({required this.a, required this.i, required this.uid});
  final AjoCircle a;
  final int i;
  final String uid;
  @override
  Widget build(BuildContext context) {
    final rid = a.payoutOrder[i];
    final paidCount = a.paid[i]?.length ?? 0;
    final out = a.payouts[i];
    final iPaid = a.paid[i]?.containsKey(uid) ?? false;
    final status = out != null
        ? const Badge2('Paid out', Tone.success)
        : i == a.currentCycleIndex && a.status == 'active'
            ? const Badge2('Current round', Tone.info)
            : const Badge2('Upcoming', Tone.muted);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: rid == uid ? AppColors.greenWash : AppColors.purpleWash,
        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: rid == uid ? AppColors.green : AppColors.purple)),
      ),
      title: Text('${a.nameOf(rid)}${rid == uid ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Due ${formatDay(a.dueDate(i))} · $paidCount/${a.rounds} paid${iPaid ? ' · you\'ve paid' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(naira(out?.amountKobo ?? a.pot, decimals: false), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        status,
      ]),
    );
  }
}

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});
  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _target = TextEditingController();
  final _contrib = TextEditingController();
  final _max = TextEditingController(text: '20');
  String _freq = 'monthly';
  String _rule = 'anytime';
  DateTime? _maturity;
  String? _error;

  Future<void> _create() async {
    setState(() => _error = null);
    final t = parseKobo(_target.text);
    String? err;
    if (_name.text.trim().isEmpty) {
      err = 'Give the group a name.';
    } else if (t == null) {
      err = "Enter the group's target.";
    } else if (_rule == 'maturity' && _maturity == null) {
      err = 'Set a maturity date, or let members withdraw any time.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    try {
      final r = await Api.call('createSavingsGroup', {
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'targetKobo': t,
        'contributionKobo': parseKobo(_contrib.text) ?? 0,
        'frequency': _freq,
        'maturityDate': _maturity == null ? null : isoDay(_maturity!),
        'withdrawalRule': _rule,
        'maxMembers': int.tryParse(_max.text) ?? 20,
      });
      if (!mounted) return;
      toast(context, 'Group created');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GroupScreen(groupId: '${r['groupId']}')));
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New savings group')),
      body: PageBody(children: [
        TextField(controller: _name, maxLength: 60, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Group name', hintText: 'e.g. Church building fund', counterText: '')),
        const SizedBox(height: 14),
        TextField(controller: _desc, maxLength: 300, decoration: const InputDecoration(labelText: 'What are you saving for? (optional)', counterText: '')),
        const SizedBox(height: 14),
        MoneyField(controller: _target, label: 'Group target'),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _freq,
          decoration: const InputDecoration(labelText: 'How often should members contribute?'),
          items: const [
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'flexible', child: Text('Any time')),
          ],
          onChanged: (v) => setState(() => _freq = v ?? 'monthly'),
        ),
        const SizedBox(height: 14),
        MoneyField(controller: _contrib, label: 'Suggested amount each time (optional)'),
        const SizedBox(height: 14),
        DateField(label: 'Maturity date (optional)', value: _maturity, onChanged: (d) => setState(() => _maturity = d)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _rule,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'When can members withdraw their share?'),
          items: const [
            DropdownMenuItem(value: 'anytime', child: Text('Any time')),
            DropdownMenuItem(value: 'maturity', child: Text('Only after the maturity date')),
          ],
          onChanged: (v) => setState(() => _rule = v ?? 'anytime'),
        ),
        const SizedBox(height: 14),
        TextField(controller: _max, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Maximum members')),
        const SizedBox(height: 22),
        ErrorText(_error),
        BusyButton(label: 'Create group', onPressed: _create),
        const SizedBox(height: 12),
        const Text("You'll get a code to share. Each member's contributions are tracked separately, and members can only withdraw their own share.",
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
      ]),
    );
  }
}

class NewAjoScreen extends StatefulWidget {
  const NewAjoScreen({super.key});
  @override
  State<NewAjoScreen> createState() => _NewAjoScreenState();
}

class _NewAjoScreenState extends State<NewAjoScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _max = TextEditingController(text: '6');
  String _freq = 'monthly';
  late final BankFieldsController _bank;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<Session>();
    _bank = BankFieldsController(s.lastBank, s.profile?.name);
  }

  Future<void> _create() async {
    setState(() => _error = null);
    final k = parseKobo(_amount.text);
    String? err;
    if (_name.text.trim().isEmpty) {
      err = 'Give the circle a name.';
    } else if (k == null) {
      err = 'Enter the contribution amount.';
    } else {
      err = _bank.validate();
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    try {
      final r = await Api.call('createAjo', {
        'name': _name.text.trim(),
        'contributionKobo': k,
        'frequency': _freq,
        'maxMembers': int.tryParse(_max.text) ?? 0,
        'bank': _bank.value.toMap(),
      });
      if (!mounted) return;
      toast(context, 'Circle created');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AjoScreen(ajoId: '${r['ajoId']}')));
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = parseKobo(_amount.text);
    final m = int.tryParse(_max.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('New Ajo circle')),
      body: PageBody(children: [
        TextField(controller: _name, maxLength: 60, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Circle name', hintText: 'e.g. Market women monthly', counterText: '')),
        const SizedBox(height: 14),
        MoneyField(controller: _amount, label: 'Contribution per member, each round', onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _freq,
          decoration: const InputDecoration(labelText: 'How often?'),
          items: const [
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
          ],
          onChanged: (v) => setState(() => _freq = v ?? 'monthly'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _max,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Number of members',
            helperText: k != null && m > 1 ? 'Each member collects ${naira(k * m, decimals: false)} once, over $m rounds.' : null,
          ),
        ),
        const SectionTitle('Where should your payout go?'),
        BankFields(controller: _bank),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Only MOM can see these details.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        ),
        const SizedBox(height: 22),
        ErrorText(_error),
        BusyButton(label: 'Create circle', onPressed: _create),
        const SizedBox(height: 12),
        const Text('Share the code with members. When everyone has joined, MOM starts the circle and sets the payout order.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
      ]),
    );
  }
}

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  Map<String, dynamic>? _found;
  BankFieldsController? _bank;
  String? _error;

  Future<void> _find() async {
    setState(() {
      _error = null;
      _found = null;
    });
    try {
      final r = await Api.call('lookupJoinCode', {'code': _code.text});
      if (!mounted) return;
      final s = context.read<Session>();
      setState(() {
        _found = r;
        _bank = BankFieldsController(s.lastBank, s.profile?.name);
      });
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _join() async {
    final x = _found!;
    final isAjo = x['kind'] == 'ajo';
    setState(() => _error = null);
    if (isAjo) {
      final err = _bank!.validate();
      if (err != null) {
        setState(() => _error = err);
        return;
      }
    }
    try {
      if (isAjo) {
        await Api.call('joinAjo', {'ajoId': x['id'], 'bank': _bank!.value.toMap()});
      } else {
        await Api.call('joinSavingsGroup', {'groupId': x['id']});
      }
      if (!mounted) return;
      toast(context, "You've joined ${x['name']}");
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => isAjo ? AjoScreen(ajoId: '${x['id']}') : GroupScreen(groupId: '${x['id']}')));
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = _found;
    return Scaffold(
      appBar: AppBar(title: const Text('Join with a code')),
      body: PageBody(children: [
        TextField(
          controller: _code,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'Join code', hintText: 'K7M2QX', counterText: ''),
        ),
        const SizedBox(height: 14),
        if (x == null) ...[ErrorText(_error), BusyButton(label: 'Find', onPressed: _find)],
        if (x != null) _foundCard(x),
      ]),
    );
  }

  Widget _foundCard(Map<String, dynamic> x) {
    final isAjo = x['kind'] == 'ajo';
    final members = (x['members'] as num?)?.toInt() ?? 0;
    final max = (x['maxMembers'] as num?)?.toInt() ?? 0;
    final contribution = (x['contributionKobo'] as num?)?.toInt() ?? 0;
    final target = (x['targetKobo'] as num?)?.toInt() ?? 0;
    final full = members >= max;
    final closed = isAjo ? x['status'] != 'forming' : x['status'] != 'active';
    if (x['alreadyMember'] == true) {
      return Note("You're already in ${x['name']}.", tone: Tone.success);
    }
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(isAjo ? 'Ajo circle' : 'Savings group', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        Text('${x['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        KV('Started by', '${x['createdByName'] ?? ''}'),
        KV('Members', '$members/$max'),
        if (isAjo) ...[
          KV('Contribution', '${naira(contribution)} per ${frequencyEvery[x['frequency']] ?? ''}'),
          KV('Each member collects', naira(contribution * max), last: true),
        ] else ...[
          KV('Group target', naira(target)),
          if (contribution > 0) KV('Suggested contribution', naira(contribution)),
          KV('Withdrawals', x['withdrawalRule'] == 'maturity' && x['maturityDate'] != null ? 'After ${formatDay(DateTime.tryParse('${x['maturityDate']}'))}' : 'Any time (own share)', last: true),
        ],
        const SizedBox(height: 12),
        if (full || closed)
          Note(closed ? (isAjo ? "This circle has already started, so it can't take new members." : 'This group is closed.') : 'This is full.')
        else ...[
          if (isAjo && _bank != null) ...[
            const SectionTitle('Where should your payout go?'),
            BankFields(controller: _bank!),
            const SizedBox(height: 6),
            const Text('Only MOM can see these details.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            const SizedBox(height: 16),
          ],
          ErrorText(_error),
          BusyButton(label: isAjo ? 'Join circle' : 'Join group', onPressed: _join),
        ],
      ]),
    );
  }
}
