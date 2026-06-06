import 'package:flutter/material.dart';
import '../widgets/nurtura_bottom_nav.dart';
import 'home_screen.dart';
import 'ask_ai_screen.dart';
import 'pregnancy_week_screen.dart';
import 'emergency_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  NurturaTab _current = NurturaTab.askAi;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _current.index,
        children: const [
          HomeScreen(),
          AskAiScreen(showBackButton: false),
          PregnancyWeekScreen(showBackButton: false),
          EmergencyScreen(showBackButton: false),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NurturaBottomNav(
        current: _current,
        onTap: (tab) => setState(() => _current = tab),
      ),
    );
  }
}
