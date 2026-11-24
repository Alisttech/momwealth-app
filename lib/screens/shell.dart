import 'package:flutter/material.dart';

import '../features.dart';
import '../theme.dart';
import 'groups.dart';
import 'home.dart';
import 'loans.dart';
import 'profile.dart';
import 'savings.dart';

/// Bottom tabs, using the original app's icons (white "fill" icon on a green circle when active).
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  static AppShellState? of(BuildContext context) => context.findAncestorStateOfType<AppShellState>();
  /// For pages pushed on top of the tabs (they can't find the shell by context).
  static final shellKey = GlobalKey<AppShellState>();
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int index = 0;
  void go(int i) => setState(() => index = i);

  static const _tabs = [
    ('Home', 'home-fill.png', 'home-grey-unfill.png'),
    ('Savings', 'poket-fill.png', 'Poket-unfill.png'),
    ('Groups', 'Goals-fill.png', 'Goals-unfill.png'),
    if (loansEnabled) ('Loans', 'Card-fill.png', 'Card-unfill.png'),
    ('Profile', 'profile-fill.png', 'profile-unfill.png'),
  ];
  static const profileTab = loansEnabled ? 4 : 3;
  static const loansTab = 3; // only when loansEnabled

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: const [HomeTab(), SavingsTab(), GroupsTab(), if (loansEnabled) LoansTab(), ProfileTab()]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => go(i),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: i == index ? AppColors.green : Colors.transparent, shape: BoxShape.circle),
                        child: Image.asset('assets/images/${i == index ? _tabs[i].$2 : _tabs[i].$3}'),
                      ),
                      const SizedBox(height: 2),
                      Text(_tabs[i].$1,
                          style: TextStyle(fontSize: 11, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? AppColors.green : AppColors.inkSoft)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
