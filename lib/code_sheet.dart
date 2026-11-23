import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api.dart';
import 'theme.dart';
import 'widgets.dart';

/// Asks the backend to text a 6-digit code (Termii), then lets the member type it in.
/// [send] requests a code and returns {codeId, sentTo}. [verify] uses the code; throw to show an error.
/// Returns true once [verify] succeeds.
Future<bool> confirmWithSmsCode(
  BuildContext context, {
  required String title,
  required String purpose,
  required Future<Map<String, dynamic>> Function() send,
  required Future<void> Function(String codeId, String code) verify,
  String verifyLabel = 'Confirm',
}) async {
  Map<String, dynamic> first;
  try {
    first = await send();
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
    return false;
  }
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _CodeSheet(title: title, purpose: purpose, first: first, send: send, verify: verify, verifyLabel: verifyLabel),
  );
  return ok == true;
}

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({required this.title, required this.purpose, required this.first, required this.send, required this.verify, required this.verifyLabel});
  final String title, purpose, verifyLabel;
  final Map<String, dynamic> first;
  final Future<Map<String, dynamic>> Function() send;
  final Future<void> Function(String codeId, String code) verify;
  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _code = TextEditingController();
  late String _codeId = '${widget.first['codeId'] ?? ''}';
  late String _sentTo = '${widget.first['sentTo'] ?? 'your phone'}';
  String? _error;
  int _wait = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    _timer?.cancel();
    _wait = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      final r = await widget.send();
      setState(() {
        _codeId = '${r['codeId'] ?? ''}';
        _sentTo = '${r['sentTo'] ?? _sentTo}';
        _code.clear();
      });
      _tick();
      if (mounted) toast(context, 'New code sent');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _submit() async {
    final c = _code.text.replaceAll(RegExp(r'\D'), '');
    if (c.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() => _error = null);
    try {
      await widget.verify(_codeId, c);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.greenWash, shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline_rounded, color: AppColors.green),
          ),
          const SizedBox(height: 14),
          Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('We sent a 6-digit code to $_sentTo to ${widget.purpose}. It expires in 10 minutes.',
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft, height: 1.45)),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (v) {
              if (v.length == 6) _submit();
            },
          ),
          ErrorText(_error),
          const SizedBox(height: 14),
          BusyButton(label: widget.verifyLabel, onPressed: _submit),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _wait > 0 ? null : _resend,
            child: Text(_wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code'),
          ),
          const Text('MOM staff will never ask you for this code.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ]),
      ),
    );
  }
}
