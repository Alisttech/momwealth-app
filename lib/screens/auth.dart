import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets.dart';

const privacyPolicyUrl = 'https://momrehoboth.com/privacy-policy';

enum _Mode { signIn, signUp, forgot }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _Mode _mode = _Mode.signIn;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  String? _error, _ok;

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _ok = null;
    });
    final email = _email.text.trim();
    try {
      if (_mode == _Mode.forgot) {
        if (!email.contains('@')) throw 'Enter the email address on your account.';
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        setState(() => _ok = 'If an account exists for that email, a reset link is on its way. Check your inbox and spam folder.');
        return;
      }
      if (_mode == _Mode.signUp) {
        final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (name.split(' ').length < 2) throw 'Enter your first and last name.';
        if (!RegExp(r'^(0|234)?[789]\d{9}$').hasMatch(_phone.text.replaceAll(RegExp(r'\D'), ''))) throw 'Enter a valid 11-digit phone number.';
        if (!email.contains('@')) throw 'Enter your email address.';
        final session = context.read<Session>();
        session.pendingName = name;
        session.pendingPhone = _phone.text.trim();
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: _pass.text);
        await cred.user?.updateDisplayName(name);
      } else {
        if (email.isEmpty) throw 'Enter your phone number or email.';
        if (_pass.text.isEmpty) throw 'Enter your password.';
        var loginEmail = email;
        if (!email.contains('@')) {
          // Phone number: the backend checks the password and tells us which account it belongs to.
          final r = await Api.call('signInWithPhone', {'phone': email, 'password': _pass.text});
          loginEmail = '${r['email'] ?? ''}';
        }
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: loginEmail, password: _pass.text);
      }
    } on String catch (m) {
      setState(() => _error = m);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final signUp = _mode == _Mode.signUp;
    final forgot = _mode == _Mode.forgot;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), children: [
          Center(child: Image.asset('assets/branding/splash-logo.png', width: 110)),
          const SizedBox(height: 22),
          Text(forgot ? 'Reset your password' : signUp ? 'Create your account' : 'Welcome back',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            forgot ? "Enter the email on your account and we'll send you a reset link." : signUp ? 'Save, grow and borrow with MOM Wealth.' : 'Sign in to continue saving.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          if (signUp) ...[
            TextField(controller: _name, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 14),
            TextField(controller: _phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: const InputDecoration(labelText: 'Phone number', hintText: '080...')),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _email,
            keyboardType: _mode == _Mode.signIn ? TextInputType.text : TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: _mode == _Mode.signIn ? const [AutofillHints.username] : const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: _mode == _Mode.signIn ? 'Phone number or email' : 'Email',
              hintText: _mode == _Mode.signIn ? '08031234567 or you@example.com' : null,
            ),
          ),
          if (!forgot) ...[
            const SizedBox(height: 14),
            TextField(
              controller: _pass,
              obscureText: _hide,
              autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: signUp ? 'At least 6 characters.' : null,
                suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide)),
              ),
            ),
          ],
          if (_mode == _Mode.signIn)
            Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _mode = _Mode.forgot), child: const Text('Forgot password?'))),
          const SizedBox(height: 14),
          ErrorText(_error),
          if (_ok != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Note(_ok!, tone: Tone.success)),
          BusyButton(label: forgot ? 'Send reset link' : signUp ? 'Create account' : 'Sign in', onPressed: _submit),
          const SizedBox(height: 14),
          if (signUp)
            Text.rich(
              TextSpan(text: 'By creating an account you agree to our ', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12.5), children: [
                WidgetSpan(
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.inAppBrowserView),
                    child: const Text('privacy policy', style: TextStyle(color: AppColors.green, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
                const TextSpan(text: '.'),
              ]),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() {
                _error = null;
                _ok = null;
                _mode = forgot ? _Mode.signIn : signUp ? _Mode.signIn : _Mode.signUp;
              }),
              child: Text(forgot ? 'Back to sign in' : signUp ? 'Already have an account? Sign in' : "New to MOM Wealth? Create an account"),
            ),
          ),
        ]),
      ),
    );
  }
}
