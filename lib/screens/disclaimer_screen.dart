import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import '../providers/app_provider.dart';
import 'main_shell.dart';

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({
    super.key,
    required this.name,
    this.dueDate,
    required this.pregnancyWeek,
    required this.preferredLanguage,
  });

  final String name;
  final String? dueDate;
  final int pregnancyWeek;
  final String preferredLanguage;

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool agreed = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.pregnant_woman_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text('Important', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  'Nurtura provides educational guidance only and is not a substitute '
                  'for professional medical advice, diagnosis, or treatment.',
                  style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(value: agreed, onChanged: (v) => setState(() => agreed = v ?? false)),
                  const Expanded(child: Text('I understand and agree')),
                ],
              ),
              if (app.error != null)
                Text(app.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              const Spacer(),
              PrimaryButton(
                label: app.loading ? 'Saving...' : 'Continue',
                onPressed: () async {
                  if (!agreed || app.loading) return;
                  final ok = await context.read<AppProvider>().register(
                    name: widget.name,
                    dueDate: widget.dueDate,
                    pregnancyWeek: widget.pregnancyWeek,
                    preferredLanguage: widget.preferredLanguage,
                  );
                  if (!context.mounted || !ok) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (_) => false,
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
