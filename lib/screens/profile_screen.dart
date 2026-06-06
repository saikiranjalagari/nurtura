import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../providers/app_provider.dart';
import 'onboarding_welcome_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _menuItems = [
    _MenuItem('Personal Details', Icons.person_outline),
    _MenuItem('Language', Icons.language),
    _MenuItem('Notifications', Icons.notifications_outlined),
    _MenuItem('Privacy Policy', Icons.privacy_tip_outlined),
    _MenuItem('Help & Support', Icons.help_outline),
    _MenuItem('Logout', Icons.logout, isDestructive: true),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.user;
    final name = user?['name']?.toString() ?? 'Guest';
    final week = user?['pregnancyWeek'] ?? 24;
    final dueDate = user?['dueDate']?.toString() ?? 'Not set';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            const Text('Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            CircleAvatar(radius: 48, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: const Icon(Icons.person, size: 48, color: AppColors.primary)),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Week $week • Due $dueDate', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            if (app.apiConnected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(label: const Text('API Connected', style: TextStyle(fontSize: 11)), backgroundColor: Colors.green.shade50),
              ),
            const SizedBox(height: 24),
            ..._menuItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                  leading: Icon(item.icon, color: item.isDestructive ? AppColors.emergency : AppColors.primary),
                  title: Text(item.label, style: TextStyle(fontWeight: FontWeight.w500, color: item.isDestructive ? AppColors.emergency : AppColors.textDark)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: () async {
                    if (item.isDestructive) {
                      await context.read<AppProvider>().logout();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
                        (_) => false,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.label} (coming soon)')));
                    }
                  },
                ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.label, this.icon, {this.isDestructive = false});
  final String label;
  final IconData icon;
  final bool isDestructive;
}
