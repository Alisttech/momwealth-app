import 'package:flutter/material.dart';

import '../theme.dart';

/// The four intro slides from the original app design.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  static const _slides = [
    ('assets/images/intro-1.png', 'Save Smarter', 'Set goals, track progress, and grow your savings with confidence.'),
    ('assets/images/intro-2.png', 'Save Securely', 'Your contributions are protected and managed with transparency.'),
    ('assets/images/intro-3.png', 'Save Together', 'Join a trusted community working toward shared financial success.'),
    ('assets/images/intro-4.png', 'Save for What Matters', 'Build the future you want, one contribution at a time.'),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.greenWash,
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton(onPressed: widget.onDone, child: Text(last ? '' : 'Skip')),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final (img, title, sub) = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(children: [
                    Expanded(child: Center(child: Image.asset(img, fit: BoxFit.contain))),
                    const SizedBox(height: 24),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 10),
                    Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppColors.inkSoft, height: 1.45)),
                    const SizedBox(height: 24),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _index ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == _index ? AppColors.green : const Color(0xFFB9D3CB), borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: ElevatedButton(
              onPressed: () => last ? widget.onDone() : _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              child: Text(last ? 'Get started' : 'Next'),
            ),
          ),
        ]),
      ),
    );
  }
}
