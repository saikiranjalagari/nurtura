import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_card.dart';
import '../providers/app_provider.dart';
import '../services/nurtura_api.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _api = NurturaApi();
  bool upcoming = true;
  List<Map<String, dynamic>> appointments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppProvider>().userId;
    if (userId == null) return;
    setState(() => loading = true);
    try {
      appointments = await _api.getAppointments(userId, upcoming: upcoming);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addAppointment() async {
    final userId = context.read<AppProvider>().userId;
    if (userId == null) return;

    final titleController = TextEditingController();
    final doctorController = TextEditingController(text: 'Dr. Mehta');
    DateTime? date;
    TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: doctorController, decoration: const InputDecoration(labelText: 'Doctor')),
              ListTile(
                title: Text(date == null ? 'Pick date' : DateFormat('yyyy-MM-dd').format(date!)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
              ListTile(
                title: Text('Time: ${time.format(ctx)}'),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showTimePicker(context: ctx, initialTime: time);
                  if (picked != null) setDialogState(() => time = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, titleController.text.trim().isNotEmpty && date != null),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || date == null) return;

    await _api.addAppointment(
      userId,
      title: titleController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(date!),
      time: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      doctorName: doctorController.text.trim(),
    );
    await _load();
    if (mounted) context.read<AppProvider>().loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Appointments'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _TabButton(label: 'Upcoming', selected: upcoming, onTap: () { setState(() => upcoming = true); _load(); })),
                const SizedBox(width: 12),
                Expanded(child: _TabButton(label: 'Past', selected: !upcoming, onTap: () { setState(() => upcoming = false); _load(); })),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : appointments.isEmpty
                    ? Center(child: Text('No appointments', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final a = appointments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              child: Row(
                                children: [
                                  const Icon(Icons.event, color: AppColors.appointments),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('${a['date']} • ${a['time']} • ${a['doctorName']}', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          child: FloatingActionButton.extended(
            onPressed: _addAppointment,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: AppColors.white),
            label: const Text('Add Appointment', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.appointments : AppColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: selected ? AppColors.appointments : AppColors.cardBorder)),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.white : AppColors.textMuted)),
        ),
      ),
    );
  }
}
