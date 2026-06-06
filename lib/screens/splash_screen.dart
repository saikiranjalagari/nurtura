import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'onboarding_welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final app = context.read<AppProvider>();
    try {
      await app.init();
    } catch (_) {
      // Continue to welcome even if API check fails
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFDEEF4), Color(0xFFFCE4EC)],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFF06292), width: 3),
                  ),
                  child: const Icon(Icons.favorite_rounded, size: 48, color: Color(0xFFF06292)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Nurtura',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF06292),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Trusted pregnancy guidance anytime',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                const CircularProgressIndicator(color: Color(0xFFF06292)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
