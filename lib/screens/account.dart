import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';

String groupAccountNumber(String n) =>
    n.length == 10 ? '${n.substring(0, 4)} ${n.substring(4, 7)} ${n.substring(7)}' : n;

/// The member's dedicated account number, drawn as a bank card in MOM colours.
class MomCard extends StatelessWidget {
  const MomCard({super.key, required this.profile, this.compact = false});
  final Profile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return AspectRatio(
      aspectRatio: compact ? 2.3 : 1.586,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 18 : 22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.greenDark, AppColors.green, AppColors.greenLight],
            stops: [0, .55, 1],
          ),
          boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: .28), blurRadius: 22, offset: const Offset(0, 10))],
        ),
        child: Stack(children: [
          Positioned(
            right: -40,
            bottom: -46,
            child: Image.asset('assets/images/logogram.png', width: compact ? 170 : 230, color: Colors.white.withValues(alpha: .13), colorBlendMode: BlendMode.srcIn),
          ),
          Positioned(
            left: -60,
            top: -90,
            child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06))),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 16 : 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Image.asset('assets/images/logo-mark.png', width: compact ? 20 : 24, height: compact ? 20 : 24),
                ),
                const SizedBox(width: 8),
                const Text('MOM WEALTH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1.6, fontSize: 13)),
                const Spacer(),
                if (p.hasAccount) Text(p.accountBank, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
              const Spacer(),
              if (!compact) ...[const _Chip(), const SizedBox(height: 14)],
              Text(p.hasAccount ? 'ACCOUNT NUMBER' : 'MEMBER ID', style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  p.hasAccount ? groupAccountNumber(p.accountNumber) : (p.memberNo.isEmpty ? '—' : p.memberNo),
                  style: TextStyle(color: Colors.white, fontSize: compact ? 22 : 27, fontWeight: FontWeight.w700, letterSpacing: 2.2, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              SizedBox(height: compact ? 6 : 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text(p.accountName.toUpperCase(),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: .8, fontSize: 13)),
                ),
                Text(p.hasAccount ? 'SAVINGS' : 'MEMBER', style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip();
  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 31,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(colors: [Color(0xFFE9C987), Color(0xFFC9A45C)]),
        ),
        child: CustomPaint(painter: _ChipLines()),
      );
}

class _ChipLines extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFF9C7A3C).withValues(alpha: .7)
      ..strokeWidth = 1;
    c.drawLine(Offset(0, s.height / 3), Offset(s.width, s.height / 3), p);
    c.drawLine(Offset(0, s.height * 2 / 3), Offset(s.width, s.height * 2 / 3), p);
    c.drawLine(Offset(s.width * .38, 0), Offset(s.width * .38, s.height), p);
    c.drawLine(Offset(s.width * .62, 0), Offset(s.width * .62, s.height), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full page: the card, copy/share, and how saving by transfer works.
class AccountCardScreen extends StatelessWidget {
  const AccountCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<Session>().profile!;
    final details = 'Account number: ${p.accountNumber}\nBank: ${p.accountBank}\nAccount name: ${p.accountName}';
    return Scaffold(
      appBar: AppBar(title: Text(p.hasAccount ? 'My account' : 'My member card')),
      body: PageBody(children: [
        MomCard(profile: p),
        const SizedBox(height: 18),
        if (!p.hasAccount) ...[
          AppCard(
            child: Column(children: [
              KV('Member ID', p.memberNo.isEmpty ? '—' : p.memberNo),
              KV('Name', p.name),
              KV('Phone', p.phone.isEmpty ? '—' : p.phone, last: true),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionTitle('How to save'),
          const AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Step(1, 'Tap Save money on the Home screen and choose a plan.'),
              _Step(2, 'Pay by card, bank transfer or USSD on the secure Squad page.'),
              _Step(3, 'Your savings update as soon as the payment is confirmed. You get an email for every payment.'),
            ]),
          ),
          const SizedBox(height: 12),
          const Note('Quote your member ID whenever you contact MOM.', tone: Tone.info),
        ] else ...[
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: p.accountNumber));
                  toast(context, 'Account number copied');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy number'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('My MOM Wealth account\n$details')}'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          AppCard(
            child: Column(children: [
              KV('Account number', p.accountNumber),
              KV('Bank', p.accountBank),
              KV('Account name', p.accountName, last: true),
            ]),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Save by bank transfer'),
          const AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Step(1, 'Open your bank app or dial your bank\'s USSD code.'),
              _Step(2, 'Transfer any amount to the account number above.'),
              _Step(3, 'It is added to your General Savings automatically, usually within minutes. You get an email for every payment.'),
            ]),
          ),
          const SizedBox(height: 12),
          const Note('Only transfer from bank accounts in your own name. This is an account number for saving, not a payment card.', tone: Tone.info),
        ],
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.greenWash, shape: BoxShape.circle),
            child: Text('$n', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ]),
      );
}
