import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../widgets/primary_button.dart';
import 'disclaimer_screen.dart';

class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final _nameController = TextEditingController(text: 'Priya Sharma');
  final _languageController = TextEditingController(text: 'English');
  DateTime? _dueDate;
  int _pregnancyWeek = 24;

  @override
  void dispose() {
    _nameController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 120)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 300)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tell us about you'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabeledField(label: 'Your Name', controller: _nameController),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickDueDate,
                child: AbsorbPointer(
                  child: _LabeledField(
                    label: 'Due Date',
                    readOnly: true,
                    controller: TextEditingController(
                      text: _dueDate != null ? DateFormat('MMM d, yyyy').format(_dueDate!) : '',
                    ),
                    hint: 'Select date',
                    suffix: const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Pregnancy Week',
                readOnly: true,
                controller: TextEditingController(text: 'Week $_pregnancyWeek'),
                onTap: () async {
                  final week = await showDialog<int>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Select week'),
                      children: List.generate(21, (i) {
                        final w = i + 4;
                        return SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, w),
                          child: Text('Week $w'),
                        );
                      }),
                    ),
                  );
                  if (week != null) setState(() => _pregnancyWeek = week);
                },
                suffix: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              _LabeledField(label: 'Preferred Language', controller: _languageController),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DisclaimerScreen(
                        name: _nameController.text.trim(),
                        dueDate: _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null,
                        pregnancyWeek: _pregnancyWeek,
                        preferredLanguage: _languageController.text.trim(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    this.controller,
    this.hint,
    this.suffix,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
        ),
      ],
    );
  }
}
