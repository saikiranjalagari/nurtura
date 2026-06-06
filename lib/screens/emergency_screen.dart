import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/primary_button.dart';
import '../services/nurtura_api.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _api = NurturaApi();
  List<Map<String, dynamic>> symptoms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      symptoms = await _api.getEmergencySymptoms();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.showBackButton
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context))
            : null,
        title: const Text('Emergency Help'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seek immediate help if you experience:', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: symptoms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.emergency),
                              const SizedBox(width: 14),
                              Expanded(child: Text(symptoms[index]['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  PrimaryButton(label: 'CALL DOCTOR', icon: Icons.phone, onPressed: () => _showSnack('Calling doctor... (demo)')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _showSnack('Opening WhatsApp clinic... (demo)'),
                      icon: const Icon(Icons.chat, color: AppColors.white),
                      label: const Text('WHATSAPP CLINIC', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: AppColors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => _showSnack('Finding nearest hospital... (demo)'),
                      child: const Text('Find Nearest Hospital', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
