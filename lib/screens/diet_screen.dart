import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../providers/app_provider.dart';
import '../services/nurtura_api.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final _api = NurturaApi();
  List<Map<String, dynamic>> categories = [];
  Map<String, dynamic> foods = {};
  int glasses = 0;
  int goal = 8;
  int selectedCategory = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppProvider>().userId;
    setState(() => loading = true);
    try {
      categories = await _api.getDietCategories();
      foods = await _api.getDietFoods();
      if (userId != null) {
        final water = await _api.getWater(userId);
        glasses = water['glasses'] as int? ?? 0;
        goal = water['goal'] as int? ?? 8;
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _tapWater(int index) async {
    final userId = context.read<AppProvider>().userId;
    if (userId == null) return;
    final newGlasses = index + 1 <= glasses ? index : index + 1;
    final result = await _api.updateWater(userId, newGlasses.clamp(0, goal));
    setState(() {
      glasses = result['glasses'] as int? ?? newGlasses;
      goal = result['goal'] as int? ?? 8;
    });
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Diet Advice'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (categories.isNotEmpty)
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final selected = index == selectedCategory;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(categories[index]['name']?.toString() ?? ''),
                              selected: selected,
                              onSelected: (_) => setState(() => selectedCategory = index),
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(color: selected ? AppColors.white : AppColors.textDark, fontSize: 13),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  ...foods.entries.map((entry) => _FoodSection(
                    title: entry.key,
                    items: (entry.value as List).cast<Map<String, dynamic>>(),
                    parseColor: _parseColor,
                  )),
                  const SizedBox(height: 20),
                  Text('Water Tracker', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$glasses/$goal Glasses', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                            const Text('Tap drops to update', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(goal, (i) {
                            return GestureDetector(
                              onTap: () => _tapWater(i),
                              child: Icon(Icons.water_drop, color: i < glasses ? AppColors.tipBlueIcon : AppColors.cardBorder, size: 28),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FoodSection extends StatelessWidget {
  const _FoodSection({required this.title, required this.items, required this.parseColor});
  final String title;
  final List<Map<String, dynamic>> items;
  final Color Function(String) parseColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final color = parseColor(item['colorHex']?.toString() ?? '#F06292');
              return Container(
                width: 90,
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.cardBorder)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.restaurant, color: color, size: 22)),
                    const SizedBox(height: 8),
                    Text(item['name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
