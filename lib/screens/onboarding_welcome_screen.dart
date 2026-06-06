import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../providers/app_provider.dart';
import 'onboarding_profile_screen.dart';
import 'main_shell.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (!app.apiConnected)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    app.error ?? 'Start API: cd api && npm start',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Spacer(flex: 2),
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.pregnant_woman_rounded, size: 100, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to Nurtura',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text('Your calm pregnancy companion', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              const Spacer(flex: 3),
              PrimaryButton(
                label: 'Get Started',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: app.loading ? 'Logging in...' : 'Login (Demo User)',
                outlined: true,
                onPressed: app.loading || !app.apiConnected
                    ? () {}
                    : () async {
                        await context.read<AppProvider>().loginDemo();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const MainShell()),
                          (_) => false,
                        );
                      },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
