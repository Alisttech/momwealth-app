import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'shell.dart';

const supportCategories = ['Savings and deposits', 'Withdrawals', 'Account and security', 'Loans', 'Groups and Ajo', 'Verification (BVN)', 'Other'];

/// Route name used to hide the floating chat button while this page is open.
const supportRouteName = 'support';

void openSupport(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(settings: const RouteSettings(name: supportRouteName), builder: (_) => const SupportScreen()),
    );

/// Open a support ticket and follow earlier ones. MOM answers from the admin dashboard.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String? _category, _error;

  Future<void> _submit() async {
    if (_category == null) {
      setState(() => _error = 'Choose what your request is about.');
      return;
    }
    if (_subject.text.trim().length < 3) {
      setState(() => _error = 'Give your request a short title.');
      return;
    }
    if (_message.text.trim().length < 10) {
      setState(() => _error = 'Tell us a little more so we can help.');
      return;
    }
    setState(() => _error = null);
    try {
      final r = await Api.call('createSupportTicket', {'category': _category, 'subject': _subject.text.trim(), 'message': _message.text.trim()});
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _subject.clear();
      _message.clear();
      setState(() => _category = null);
      await showAppSheet(context, title: 'Request sent', builder: (ctx) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your ticket number is ${r['ticketNo'] ?? ''}. We\'ve emailed you a copy, and we\'ll email you again when it\'s resolved.',
              style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ]);
      });
      // Back to the Profile tab, where "Open a support ticket" lives.
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      AppShell.key.currentState?.go(4);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = context.watch<Session>().tickets;
    return Scaffold(
      appBar: AppBar(title: const Text('Get help')),
      body: PageBody(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.greenWash, borderRadius: BorderRadius.circular(18)),
          child: const Row(children: [
            Icon(Icons.support_agent_rounded, color: AppColors.green, size: 30),
            SizedBox(width: 12),
            Expanded(child: Text('Tell us what you need. The MOM team will reply by email, and you can follow your request here.', style: TextStyle(height: 1.45))),
          ]),
        ),
        const SizedBox(height: 18),
        const Text('What is it about?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in supportCategories)
            ChoiceChip(
              label: Text(c),
              selected: _category == c,
              onSelected: (_) => setState(() => _category = c),
              selectedColor: AppColors.greenWash,
              labelStyle: TextStyle(color: _category == c ? AppColors.green : AppColors.ink, fontWeight: _category == c ? FontWeight.w600 : FontWeight.w500),
              side: BorderSide(color: _category == c ? AppColors.green : AppColors.line),
              showCheckmark: false,
            ),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _subject, maxLength: 120, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. My transfer hasn\'t shown', counterText: '')),
        const SizedBox(height: 14),
        TextField(
          controller: _message,
          minLines: 4,
          maxLines: 8,
          maxLength: 3000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Details', hintText: 'What happened? Include amounts, dates and references if you have them.', alignLabelWithHint: true, counterText: ''),
        ),
        const SizedBox(height: 8),
        const Text('Never share your password, PIN or SMS codes. MOM will never ask for them.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
        const SizedBox(height: 14),
        ErrorText(_error),
        BusyButton(label: 'Send request', onPressed: _submit),
        if (tickets.isNotEmpty) ...[
          const SizedBox(height: 26),
          const SectionTitle('Your requests'),
          for (final t in tickets) ...[_TicketTile(t), const SizedBox(height: 8)],
        ],
      ]),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile(this.t);
  final SupportTicket t;
  @override
  Widget build(BuildContext context) {
    final badge = t.done
        ? const Badge2('Completed', Tone.success)
        : t.status == 'in_progress'
            ? const Badge2('In progress', Tone.info)
            : const Badge2('Received', Tone.pending);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showAppSheet(context, title: t.title, builder: (ctx) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KV('Ticket', t.ticketNo.isEmpty ? '—' : t.ticketNo),
          KV('Topic', t.category.isEmpty ? '—' : t.category),
          KV('Opened', formatDayTime(t.createdAt)),
          KV('Status', '', valueWidget: Align(alignment: Alignment.centerRight, child: badge), last: true),
          const SizedBox(height: 12),
          Text(t.description, style: const TextStyle(height: 1.45)),
          if (t.resolution.isNotEmpty) ...[const SizedBox(height: 12), Note('MOM\'s response: ${t.resolution}', tone: Tone.success)],
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ]);
      }),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${t.ticketNo} · ${formatDay(t.createdAt)}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5)),
          ]),
        ),
        badge,
      ]),
    );
  }
}

/// Green chat button floating over every page (once signed in and verified). Opens the support form.
class SupportFab extends StatelessWidget {
  const SupportFab({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.green,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: AppColors.green.withValues(alpha: .5),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(width: 54, height: 54, child: Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 24)),
        ),
      );
}
