import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../activity.dart';
import '../features.dart';
import '../services/session.dart';
import '../widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all';
  static const _filters = [('all', 'All'), ('savings', 'Savings'), ('groups', 'Groups & Ajo'), ('withdrawals', 'Withdrawals'), if (loansEnabled) ('loans', 'Loans')];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final items = activityItems(s).where((it) => _filter == 'all' || it.filter == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: PageBody(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (k, label) in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(label), selected: _filter == k, onSelected: (_) => setState(() => _filter = k)),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        ActivityList(items, empty: 'No transactions here yet.'),
        const SizedBox(height: 10),
        const Text('Tap a transaction to see its reference and details.', style: TextStyle(fontSize: 12.5, color: Colors.black54)),
      ]),
    );
  }
}
