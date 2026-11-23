import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'models.dart';
import 'theme.dart';

/// White rounded card used across the app.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color, borderColor;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: box));
  }
}

/// Green gradient balance card (the "Total Overall Pocket Balance" card from the original design).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.label, required this.amount, this.children = const [], this.actions = const []});
  final String label, amount;
  final List<Widget> children, actions;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: AppColors.green),
      child: Stack(children: [
        // MOM logo silhouette in the background.
        Positioned(
          right: -28,
          top: -22,
          child: IgnorePointer(child: Image.asset('assets/images/logogram.png', width: 170, color: Colors.white.withValues(alpha: .09), colorBlendMode: BlendMode.srcIn)),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(amount, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5))),
        ...children,
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(children: [for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: actions[i])]]),
        ],
          ]),
        ),
      ]),
    );
  }
}

/// Button styles for use on the green hero card.
class HeroButton extends StatelessWidget {
  const HeroButton({super.key, required this.label, required this.icon, required this.onTap, this.filled = true});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label, overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.green, minimumSize: const Size(0, 46)),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent, foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size(0, 46)),
            ),
    );
  }
}

class HeroStat extends StatelessWidget {
  const HeroStat(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
      ]);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Label/value row used in detail cards.
class KV extends StatelessWidget {
  const KV(this.label, this.value, {super.key, this.valueWidget, this.last = false});
  final String label, value;
  final Widget? valueWidget;
  final bool last;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.inkSoft, fontSize: 14))),
          const SizedBox(width: 12),
          Flexible(child: valueWidget ?? Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
        ]),
      );
}

enum Tone { success, pending, danger, info, muted }

class Badge2 extends StatelessWidget {
  const Badge2(this.text, this.tone, {super.key});
  final String text;
  final Tone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.success => (const Color(0xFFE7F5EC), const Color(0xFF1E7A46)),
      Tone.pending => (AppColors.goldWash, const Color(0xFF8A5A1C)),
      Tone.danger => (AppColors.redWash, AppColors.red),
      Tone.info => (AppColors.blueWash, AppColors.blue),
      Tone.muted => (const Color(0xFFEEECE6), AppColors.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.tone = Tone.pending, this.child});
  final String text;
  final Tone tone;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.success => (const Color(0xFFE7F5EC), const Color(0xFF1E7A46)),
      Tone.danger => (AppColors.redWash, AppColors.red),
      Tone.info => (AppColors.blueWash, AppColors.blue),
      _ => (AppColors.goldWash, const Color(0xFF7A5420)),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: child ?? Text(text, style: TextStyle(color: fg, fontSize: 13.5, height: 1.4)),
    );
  }
}

class ProgressLine extends StatelessWidget {
  const ProgressLine(this.percent, {super.key, this.onDark = false});
  final int percent;
  final bool onDark;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: percent / 100,
          minHeight: 8,
          backgroundColor: onDark ? Colors.white24 : const Color(0xFFEEECE6),
          valueColor: AlwaysStoppedAnimation(onDark ? Colors.white : AppColors.gold),
        ),
      );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        child: Column(children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ]),
      );
}

/// Inline error message shown above a form's button.
class ErrorText extends StatelessWidget {
  const ErrorText(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) =>
      message == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: Note(message!, tone: Tone.danger));
}

/// Primary button that shows a spinner while [onPressed] runs.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.color});
  final String label;
  final Future<void> Function()? onPressed;
  final Color? color;
  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: widget.color == null ? null : ElevatedButton.styleFrom(backgroundColor: widget.color),
        onPressed: _busy || widget.onPressed == null
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onPressed!();
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : Text(widget.label),
      );
}

/// Adds thousands separators while typing an amount.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var raw = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = raw.split('.');
    var whole = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    var text = buf.toString();
    if (parts.length > 1) text += '.${parts[1].substring(0, math.min(2, parts[1].length))}';
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

String formatAmountField(int kobo) {
  final s = MoneyInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: (kobo ~/ 100).toString())).text;
  return kobo % 100 == 0 ? s : '$s.${(kobo % 100).toString().padLeft(2, '0')}';
}

class MoneyField extends StatelessWidget {
  const MoneyField({super.key, required this.controller, required this.label, this.hint, this.onChanged, this.enabled = true});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [MoneyInputFormatter()],
        onChanged: onChanged,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        decoration: InputDecoration(labelText: label, helperText: hint, helperMaxLines: 3, prefixText: '₦ '),
      );
}

/// Bank / account number / account name inputs, used for withdrawals and Ajo payouts.
class BankFields extends StatefulWidget {
  const BankFields({super.key, required this.controller});
  final BankFieldsController controller;
  @override
  State<BankFields> createState() => _BankFieldsState();
}

class BankFieldsController {
  BankFieldsController([BankDetails? initial, String? defaultName]) {
    if (initial != null && initial.bank.isNotEmpty) {
      if (nigerianBanks.contains(initial.bank)) {
        bank = initial.bank;
      } else {
        bank = 'Other';
        other.text = initial.bank;
      }
    }
    number.text = initial?.accountNumber ?? '';
    name.text = (initial?.accountName.isNotEmpty ?? false) ? initial!.accountName : (defaultName ?? '');
  }
  String? bank;
  final other = TextEditingController();
  final number = TextEditingController();
  final name = TextEditingController();
  String get bankName => bank == 'Other' ? other.text.trim() : (bank ?? '');

  /// Returns an error sentence, or null when complete.
  String? validate() {
    if (bankName.isEmpty) return 'Choose your bank.';
    if (number.text.replaceAll(RegExp(r'\D'), '').length != 10) return 'Account number must be 10 digits.';
    if (name.text.trim().isEmpty) return 'Enter the account name.';
    return null;
  }

  BankDetails get value => BankDetails(bankName, number.text.replaceAll(RegExp(r'\D'), ''), name.text.trim());
}

class _BankFieldsState extends State<BankFields> {
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(children: [
      DropdownButtonFormField<String>(
        initialValue: c.bank,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Bank'),
        items: [for (final b in nigerianBanks) DropdownMenuItem(value: b, child: Text(b))],
        onChanged: (v) => setState(() => c.bank = v),
      ),
      if (c.bank == 'Other') ...[const SizedBox(height: 14), TextField(controller: c.other, decoration: const InputDecoration(labelText: 'Bank name'))],
      const SizedBox(height: 14),
      TextField(
        controller: c.number,
        keyboardType: TextInputType.number,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: 'Account number', counterText: ''),
      ),
      const SizedBox(height: 14),
      TextField(controller: c.name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Account name')),
    ]);
  }
}

/// Bottom sheet with consistent padding; returns the sheet's result.
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          builder(ctx),
        ]),
      ),
    ),
  );
}

/// Yes/no confirmation sheet.
Future<bool> confirmSheet(BuildContext context, {required String title, required String message, required String confirmLabel, bool danger = false}) async {
  final ok = await showAppSheet<bool>(context, title: title, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(message, style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back'))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton(
                style: danger ? ElevatedButton.styleFrom(backgroundColor: AppColors.red) : null, onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel))),
      ]),
    ]);
  });
  return ok ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// "Adaeze Grace Okafor" -> "AO"; "ada.okafor@x.com" -> "AO"; "ada@x.com" -> "A".
String initialsOf(String nameOrEmail) {
  var t = nameOrEmail.trim();
  if (t.contains('@')) t = t.split('@').first.replaceAll(RegExp(r'[._\-+0-9]+'), ' ');
  final parts = t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// The member's photo if they have one, otherwise their initials (from their name, or email).
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.profile, this.email = '', this.size = 38});
  final Profile profile;
  final String email;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Initials(profile.name.trim().isNotEmpty ? profile.name : (email.isNotEmpty ? email : profile.email), size: size);
    if (profile.photoUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(profile.photoUrl, width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, st) => fallback),
      );
    }
    return fallback;
  }
}

/// Round avatar with initials.
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 38, this.color = AppColors.greenWash, this.fg = AppColors.green});
  final String name;
  final double size;
  final Color color, fg;
  @override
  Widget build(BuildContext context) {
    final s = initialsOf(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(s.isEmpty ? '?' : s, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.34)),
    );
  }
}

/// Page scaffold with the standard padding and pull-to-refresh-free scrolling.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 96)});
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ListView(padding: padding, children: children);
}
