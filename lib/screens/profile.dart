import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart' show privacyPolicyUrl;
import 'history.dart';
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
    final va = p.virtualAccount;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(children: [
        AppCard(
          child: Row(children: [
            Initials(p.name.isEmpty ? '?' : p.name, size: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name.isEmpty ? 'Member' : p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(s.user?.email ?? p.email, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                if (p.phone.isNotEmpty) Text(p.phone, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => push(context, const EditProfileScreen())),
          ]),
        ),
        if (va != null && '${va['accountNumber'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your MOM Wealth account number', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text('${va['accountNumber']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 1))),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${va['accountNumber']}'));
                    toast(context, 'Account number copied');
                  },
                ),
              ]),
              Text('${va['bankName'] ?? ''} · ${va['accountName'] ?? ''}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 6),
              const Text('Transfers to this account are added to your General Savings automatically.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _Item(Icons.receipt_long_outlined, 'Transaction history', () => push(context, const HistoryScreen())),
            const Divider(height: 1),
            _Item(Icons.north_rounded, 'Withdrawals', () => push(context, const WithdrawScreen())),
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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name, _phone;
  String? _error;
  @override
  void initState() {
    super.initState();
    final p = context.read<Session>().profile!;
    _name = TextEditingController(text: p.name);
    _phone = TextEditingController(text: p.phone);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<Session>();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: PageBody(children: [
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 14),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
        const SizedBox(height: 14),
        TextField(
          enabled: false,
          controller: TextEditingController(text: s.user?.email ?? ''),
          decoration: const InputDecoration(labelText: 'Email', helperText: 'Receipts and updates are sent here.'),
        ),
        const SizedBox(height: 22),
        ErrorText(_error),
        BusyButton(
          label: 'Save changes',
          onPressed: () async {
            final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            if (name.split(' ').length < 2) {
              setState(() => _error = 'Enter your first and last name.');
              return;
            }
            try {
              await FirebaseFirestore.instance.collection('users').doc(s.uid).update({'display_name': name, 'phone_number': _phone.text.trim()});
              await s.user?.updateDisplayName(name);
              if (!context.mounted) return;
              toast(context, 'Profile updated');
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
