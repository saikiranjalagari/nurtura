import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../providers/app_provider.dart';
import '../services/nurtura_api.dart';

class PregnancyWeekScreen extends StatefulWidget {
  const PregnancyWeekScreen({super.key, this.showBackButton = true, this.initialWeek});

  final bool showBackButton;
  final int? initialWeek;

  @override
  State<PregnancyWeekScreen> createState() => _PregnancyWeekScreenState();
}

class _PregnancyWeekScreenState extends State<PregnancyWeekScreen> {
  final _api = NurturaApi();
  int selectedWeek = 24;
  int selectedTab = 0;
  List<int> weeks = [];
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    selectedWeek = widget.initialWeek ?? context.read<AppProvider>().user?['pregnancyWeek'] as int? ?? 24;
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      weeks = await _api.getPregnancyWeeks();
      data = await _api.getPregnancyWeek(selectedWeek);
    } catch (_) {
      data = null;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _selectWeek(int week) async {
    setState(() {
      selectedWeek = week;
      loading = true;
    });
    try {
      data = await _api.getPregnancyWeek(week);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context))
            : null,
        title: const Text('Pregnancy Journey'),
      ),
      body: loading && data == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: weeks.isEmpty ? 1 : weeks.length,
                      itemBuilder: (context, index) {
                        final week = weeks.isEmpty ? selectedWeek : weeks[index];
                        final selected = week == selectedWeek;
                        return GestureDetector(
                          onTap: () => _selectWeek(week),
                          child: Container(
                            width: 48,
                            margin: const EdgeInsets.only(right: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary : AppColors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder),
                            ),
                            child: Text('$week', style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.white : AppColors.textMuted)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (data != null) ...[
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Week ${data!['week']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                Text(data!['trimester']?.toString() ?? '', style: TextStyle(color: AppColors.textMuted)),
                                const SizedBox(height: 12),
                                Text('Size: ${data!['babySize']} 🌽'),
                                Text('Length: ${data!['lengthCm']} cm'),
                                Text('Weight: ${data!['weightGm']} gm'),
                              ],
                            ),
                          ),
                          const CircleAvatar(radius: 40, backgroundColor: Color(0xFFFCE4EC), child: Icon(Icons.baby_changing_station, size: 40, color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _TabLabel('Baby Development', selected: selectedTab == 0, onTap: () => setState(() => selectedTab = 0)),
                        _TabLabel('Body Changes', selected: selectedTab == 1, onTap: () => setState(() => selectedTab = 1)),
                        _TabLabel('Tips', selected: selectedTab == 2, onTap: () => setState(() => selectedTab = 2)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('This Week You May Experience', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: ((data!['symptoms'] as List?) ?? []).map((s) {
                        return Chip(label: Text(s['label']?.toString() ?? ''));
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Text(
                        selectedTab == 0
                            ? data!['development']?.toString() ?? ''
                            : selectedTab == 1
                                ? data!['bodyChanges']?.toString() ?? ''
                                : data!['tips']?.toString() ?? '',
                        style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? AppColors.primary : AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Container(height: 3, color: selected ? AppColors.primary : Colors.transparent),
          ],
        ),
      ),
    );
  }
}
