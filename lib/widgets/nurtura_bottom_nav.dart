import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum NurturaTab { home, askAi, pregnancy, emergency, profile }

class NurturaBottomNav extends StatelessWidget {
  const NurturaBottomNav({
    super.key,
    required this.current,
    required this.onTap,
  });

  final NurturaTab current;
  final ValueChanged<NurturaTab> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: current == NurturaTab.home,
                onTap: () => onTap(NurturaTab.home),
              ),
              _NavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'Ask AI',
                selected: current == NurturaTab.askAi,
                onTap: () => onTap(NurturaTab.askAi),
              ),
              _NavItem(
                icon: Icons.pregnant_woman_rounded,
                label: 'Pregnancy',
                selected: current == NurturaTab.pregnancy,
                onTap: () => onTap(NurturaTab.pregnancy),
              ),
              _NavItem(
                icon: Icons.shield_rounded,
                label: 'Emergency',
                selected: current == NurturaTab.emergency,
                onTap: () => onTap(NurturaTab.emergency),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                selected: current == NurturaTab.profile,
                onTap: () => onTap(NurturaTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
