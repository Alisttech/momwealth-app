import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';

/// Everything MOM Wealth has told the member: payments, withdrawals, loans, groups, support replies.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Session _session;

  @override
  void initState() {
    super.initState();
    _session = context.read<Session>();
  }

  @override
  void dispose() {
    // Leaving the page marks what was seen as read.
    _session.markAllRead();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final list = s.notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: list.isEmpty
          ? const PageBody(children: [EmptyCard("No notifications yet. We'll let you know about payments, withdrawals, loans and your groups here.")])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _Tile(list[i]),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.n);
  final AppNotification n;

  static (IconData, Color, Color) _style(String type) => switch (type) {
        'deposit' => (Icons.south_west_rounded, AppColors.green, AppColors.greenWash),
        'withdrawal' => (Icons.north_east_rounded, AppColors.gold, AppColors.goldWash),
        'loan' => (Icons.payments_outlined, AppColors.blue, AppColors.blueWash),
        'security' => (Icons.shield_outlined, AppColors.red, AppColors.redWash),
        'support' => (Icons.support_agent_rounded, AppColors.purple, AppColors.purpleWash),
        'kyc' => (Icons.verified_outlined, AppColors.green, AppColors.greenWash),
        _ => (Icons.notifications_none_rounded, AppColors.green, AppColors.greenWash),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = _style(n.type);
    return AppCard(
      color: n.read ? Colors.white : const Color(0xFFF4FAF7),
      borderColor: n.read ? null : AppColors.green.withValues(alpha: .25),
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: fg, size: 19)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w700, fontSize: 14.5))),
              if (!n.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(n.body, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4)),
            const SizedBox(height: 6),
            Text(formatDayTime(n.createdAt), style: const TextStyle(color: AppColors.inkSoft, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}
