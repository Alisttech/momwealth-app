import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../code_sheet.dart';
import '../format.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'account.dart';
import 'auth.dart' show privacyPolicyUrl;
import 'history.dart';
import 'notifications.dart';
import 'support.dart';
import 'kyc.dart' show nigerianStates, maritalOptions, employmentOptions, openVerification;
import 'home.dart' show push;
import 'withdraw.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final p = s.profile!;
    final dash = '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(children: [
        AppCard(
          child: Row(children: [
            MemberAvatar(profile: p, email: s.user?.email ?? '', size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name.isEmpty ? 'Member' : p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(s.user?.email ?? p.email, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                const SizedBox(height: 6),
                if (p.verified)
                  const Badge2('Verified', Tone.success)
                else
                  GestureDetector(onTap: () => openVerification(context), child: const Badge2('Not verified · Verify now', Tone.pending)),
              ]),
            ),
          ]),
        ),
        if (p.verified) ...[
          const SizedBox(height: 14),
          GestureDetector(onTap: () => push(context, const AccountCardScreen()), child: MomCard(profile: p, compact: true)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => push(context, const AccountCardScreen()),
              icon: const Icon(Icons.credit_card_rounded, size: 18),
              label: Text(p.hasAccount ? 'View account details' : 'View member card'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        AppCard(
          color: AppColors.goldWash,
          borderColor: Colors.transparent,
          child: Row(children: [
            const Icon(Icons.phone_iphone_rounded, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.phone.isEmpty ? 'Add your phone number so MOM can reach you.' : 'Is ${p.phone} still your number? Keep it up to date so MOM can reach you.',
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ),
            TextButton(onPressed: () => push(context, const ChangePhoneScreen()), child: Text(p.phone.isEmpty ? 'Add' : 'Change')),
          ]),
        ),
        const SizedBox(height: 18),
        SectionTitle('Personal details', trailing: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.inkSoft),
          SizedBox(width: 4),
          Text('Locked', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        ])),
        AppCard(
          child: Column(children: [
            if (p.memberNo.isNotEmpty) KV('Member ID', p.memberNo),
            KV('Full name', p.name.isEmpty ? dash : p.name),
            KV('Date of birth', p.dob.isEmpty ? dash : p.dob),
            KV('Gender', p.gender.isEmpty ? dash : p.gender),
            KV('BVN', p.bvnLast4.isEmpty ? dash : '•••••••${p.bvnLast4}'),
            KV('NIN', p.ninLast4.isEmpty ? dash : '•••••••${p.ninLast4}', last: true),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text('These can\'t be changed in the app. If something is wrong, contact MOM.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ),
        const SizedBox(height: 18),
        SectionTitle('Contact and other details', trailing: TextButton(onPressed: () => push(context, const EditDetailsScreen()), child: const Text('Update'))),
        AppCard(
          child: Column(children: [
            KV('Phone', p.phone.isEmpty ? dash : p.phone),
            KV('Email', s.user?.email ?? p.email),
            KV('Address', [p.address, p.city, p.state].where((x) => x.isNotEmpty).join(', ').isEmpty ? dash : [p.address, p.city, p.state].where((x) => x.isNotEmpty).join(', ')),
            KV('Marital status', p.maritalStatus.isEmpty ? dash : p.maritalStatus),
            KV('Employment', p.employmentStatus.isEmpty ? dash : p.employmentStatus),
            KV('Occupation', p.occupation.isEmpty ? dash : [p.occupation, p.employer].where((x) => x.isNotEmpty).join(' · '), last: true),
          ]),
        ),
        const SizedBox(height: 18),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _Item(Icons.receipt_long_outlined, 'Transaction history', () => push(context, const HistoryScreen())),
            const Divider(height: 1),
            _Item(Icons.north_rounded, 'Withdrawals', () => push(context, const WithdrawScreen())),
            const Divider(height: 1),
            _Item(Icons.support_agent_rounded, 'Open a support ticket', () => openSupport(context)),
            const Divider(height: 1),
            _Item(Icons.notifications_none_rounded, 'Notifications', () => push(context, const NotificationsScreen())),
            const Divider(height: 1),
            _Item(Icons.privacy_tip_outlined, 'Privacy policy', () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.inAppBrowserView)),
            const Divider(height: 1),
            _Item(Icons.logout_rounded, 'Sign out', () => FirebaseAuth.instance.signOut()),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(child: KV('Member since', formatDay(p.createdAt), last: true)),
        const SizedBox(height: 24),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.red),
          onPressed: () => _deleteAccount(context),
          child: const Text('Delete my account'),
        ),
      ]),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await confirmSheet(
      context,
      title: 'Delete your account?',
      message: 'Your login and personal details will be deleted. You can only do this when you have no savings, group share, '
          'open withdrawal or loan. Records MOM must keep by law (your past transactions) are retained.',
      confirmLabel: 'Delete account',
      danger: true,
    );
    if (!ok) return;
    try {
      await Api.call('deleteMyAccount');
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (context.mounted) {
        showAppSheet(context, title: "We couldn't delete your account", builder: (ctx) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(friendlyError(e), style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ]);
        });
      }
    }
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.green),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

/// Contact and life details members may change themselves. Identity details are fixed by the BVN check.
class EditDetailsScreen extends StatefulWidget {
  const EditDetailsScreen({super.key});
  @override
  State<EditDetailsScreen> createState() => _EditDetailsScreenState();
}

class _EditDetailsScreenState extends State<EditDetailsScreen> {
  late final TextEditingController _address, _city, _occupation, _employer;
  String? _state, _marital, _employment, _error;

  @override
  void initState() {
    super.initState();
    final p = context.read<Session>().profile!;
    _address = TextEditingController(text: p.address);
    _city = TextEditingController(text: p.city);
    _occupation = TextEditingController(text: p.occupation);
    _employer = TextEditingController(text: p.employer);
    _state = nigerianStates.contains(p.state) ? p.state : null;
    _marital = maritalOptions.contains(p.maritalStatus) ? p.maritalStatus : null;
    _employment = employmentOptions.contains(p.employmentStatus) ? p.employmentStatus : null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Session>().profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Update details')),
      body: PageBody(children: [
        AppCard(
          child: Row(children: [
            Expanded(child: KV('Phone', p.phone.isEmpty ? 'Not set' : p.phone, last: true)),
            TextButton(onPressed: () => push(context, const ChangePhoneScreen()), child: const Text('Change')),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(controller: _address, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Home address')),
        const SizedBox(height: 14),
        TextField(controller: _city, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City or town')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _state,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'State'),
          items: [for (final st in nigerianStates) DropdownMenuItem(value: st, child: Text(st))],
          onChanged: (v) => setState(() => _state = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _marital,
          decoration: const InputDecoration(labelText: 'Marital status'),
          items: [for (final o in maritalOptions) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _marital = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _employment,
          decoration: const InputDecoration(labelText: 'Employment status'),
          items: [for (final o in employmentOptions) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) => setState(() => _employment = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: _occupation, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Occupation')),
        const SizedBox(height: 14),
        TextField(controller: _employer, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Employer or business name')),
        const SizedBox(height: 14),
        const Note('Your name, date of birth, gender, BVN and NIN come from your BVN record and can\'t be changed here. Contact MOM if any of them is wrong.', tone: Tone.info),
        const SizedBox(height: 18),
        ErrorText(_error),
        BusyButton(
          label: 'Save changes',
          onPressed: () async {
            if (_address.text.trim().length < 5) {
              setState(() => _error = 'Enter your home address.');
              return;
            }
            setState(() => _error = null);
            try {
              await Api.call('updateMyDetails', {
                'address': _address.text.trim(),
                'city': _city.text.trim(),
                if (_state != null) 'state': _state,
                if (_marital != null) 'maritalStatus': _marital,
                if (_employment != null) 'employmentStatus': _employment,
                'occupation': _occupation.text.trim(),
                'employer': _employer.text.trim(),
              });
              if (!context.mounted) return;
              toast(context, 'Details updated');
              Navigator.pop(context);
            } catch (e) {
              setState(() => _error = friendlyError(e));
            }
          },
        ),
      ]),
    );
  }
}

/// New phone number, confirmed with a one-time code (by email, or SMS when enabled).
class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});
  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _phone = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Session>().profile!;
    return Scaffold(
      appBar: AppBar(title: Text(p.phone.isEmpty ? 'Add phone number' : 'Change phone number')),
      body: PageBody(children: [
        if (p.phone.isNotEmpty) ...[AppCard(child: KV('Current number', p.phone, last: true)), const SizedBox(height: 16)],
        TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
          decoration: const InputDecoration(labelText: 'New phone number', hintText: '08031234567'),
        ),
        const SizedBox(height: 14),
        const Note('We\'ll send you a code to confirm it\'s you. For your security, withdrawals pause for 24 hours after a change, '
            'and we let your old number and email know.', tone: Tone.info),
        const SizedBox(height: 18),
        ErrorText(_error),
        BusyButton(
          label: 'Send code',
          onPressed: () async {
            final phone = _phone.text.replaceAll(RegExp(r'\D'), '');
            if (!RegExp(r'^0[789]\d{9}$').hasMatch(phone)) {
              setState(() => _error = 'Enter an 11-digit Nigerian mobile number.');
              return;
            }
            setState(() => _error = null);
            final ok = await confirmWithSmsCode(
              context,
              title: 'Confirm your new number',
              purpose: 'confirm your new phone number',
              send: () => Api.call('requestPhoneChangeCode', {'phone': phone}),
              verify: (codeId, code) => Api.call('confirmPhoneChange', {'phone': phone, 'codeId': codeId, 'code': code}),
            );
            if (ok && context.mounted) {
              toast(context, 'Phone number updated');
              Navigator.pop(context);
            }
          },
        ),
      ]),
    );
  }
}
