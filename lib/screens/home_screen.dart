import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../providers/app_provider.dart';
import 'ask_ai_screen.dart';
import 'pregnancy_week_screen.dart';
import 'diet_screen.dart';
import 'emergency_screen.dart';
import 'appointments_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadUserData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final home = app.home;

    if (app.loading && home == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final greeting = home?['greeting']?.toString() ?? 'Hello';
    final week = home?['pregnancyWeek'] ?? app.user?['pregnancyWeek'] ?? 24;
    final babySize = home?['babySize']?.toString() ?? 'Corn';
    final progress = (home?['progress'] as num?)?.toDouble() ?? week / 40;
    final tip = home?['tip'] as Map<String, dynamic>?;
    final appt = home?['nextAppointment'] as Map<String, dynamic>?;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => context.read<AppProvider>().loadUserData(),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Week $week of pregnancy', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.read<AppProvider>().loadUserData(),
                    icon: const Icon(Icons.refresh, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your baby is the size of a $babySize 🌽', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: AppColors.background, color: AppColors.primary),
                          ),
                          const SizedBox(height: 6),
                          Text('$week Weeks', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.baby_changing_station, size: 36, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  _ActionTile(label: 'Ask AI', icon: Icons.psychology_rounded, color: AppColors.askAi, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskAiScreen()))),
                  _ActionTile(label: 'Weekly Guidance', icon: Icons.calendar_view_week_rounded, color: AppColors.weeklyGuidance, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PregnancyWeekScreen(initialWeek: week as int)))),
                  _ActionTile(label: 'Diet Advice', icon: Icons.restaurant_rounded, color: AppColors.diet, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DietScreen()))),
                  _ActionTile(label: 'Emergency', icon: Icons.emergency_rounded, color: AppColors.emergency, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen()))),
                ],
              ),
              if (tip != null) ...[
                const SizedBox(height: 20),
                Text("Today's Tip", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                AppCard(
                  color: AppColors.tipBlue,
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, color: AppColors.tipBlueIcon, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tip['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(tip['description']?.toString() ?? '', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Next Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen())),
                    child: const Text('See all', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
              if (appt != null)
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.appointments.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.event, color: AppColors.appointments),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appt['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${_fmtDate(appt['date'])} • ${_fmtTime(appt['time'])} • ${appt['doctorName']}',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text('No upcoming appointments', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(d.toString()));
    } catch (_) {
      return d.toString();
    }
  }

  String _fmtTime(dynamic t) {
    if (t == null) return '';
    try {
      final parts = t.toString().split(':');
      final dt = DateTime(2026, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return t.toString();
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: AppColors.white, size: 28),
          Text(label, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      )),
    );
  }
}
