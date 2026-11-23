import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/auth.dart';
import 'screens/kyc.dart';
import 'screens/onboarding.dart';
import 'screens/payment.dart';
import 'screens/shell.dart';
import 'services/session.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(MomWealthApp(onboarded: prefs.getBool('onboarded') ?? false));
}

class MomWealthApp extends StatefulWidget {
  const MomWealthApp({super.key, required this.onboarded});
  final bool onboarded;
  @override
  State<MomWealthApp> createState() => _MomWealthAppState();
}

class _MomWealthAppState extends State<MomWealthApp> {
  final _links = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // momwealth://payment?ref=... comes back from the Squad checkout (see payment-complete.html).
    _linkSub = _links.uriLinkStream.listen(_onLink);
  }

  void _onLink(Uri uri) {
    if (uri.scheme != 'momwealth' || uri.host != 'payment') return;
    final ref = uri.queryParameters['ref'] ?? '';
    PaymentFlow.returned(ref);
    final nav = navigatorKey.currentState;
    if (ref.isEmpty || nav == null) return;
    // If the result screen isn't already open (e.g. the app was restarted), open it.
    var showing = false;
    nav.popUntil((route) {
      if (route.settings.name == 'payment:$ref') showing = true;
      return true;
    });
    if (!showing) {
      nav.push(MaterialPageRoute(settings: RouteSettings(name: 'payment:$ref'), builder: (_) => PaymentResultScreen(reference: ref)));
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Session(),
      child: MaterialApp(
        title: 'MOM Wealth',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: buildTheme(),
        home: AuthGate(onboarded: widget.onboarded),
      ),
    );
  }
}

/// Decides what to show: onboarding, sign-in, loading, or the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.onboarded});
  final bool onboarded;
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _onboarded = widget.onboarded;
  bool _holdKyc = false; // keep the identity flow up after success to show the new account number

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    if (!s.authResolved) return const LoadingScreen();
    if (s.user == null) {
      if (!_onboarded) {
        return OnboardingScreen(onDone: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarded', true);
          setState(() => _onboarded = true);
        });
      }
      return const AuthScreen();
    }
    if (!s.ready) return const LoadingScreen();
    if (s.profile?.verified != true || _holdKyc) {
      return KycFlow(
        onSubmitting: () => _holdKyc = true,
        onFinished: () => setState(() => _holdKyc = false),
      );
    }
    return const AppShell();
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/branding/splash-logo.png', width: 150),
            const SizedBox(height: 28),
            const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.green)),
          ]),
        ),
      );
}
