import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../models/gram_sabha_meeting.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/auth_provider.dart';

class CreateMeetingScreen extends ConsumerStatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  ConsumerState<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends ConsumerState<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  MeetingType _selectedType = MeetingType.regular;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _venueController = TextEditingController(text: 'ग्रामपंचायत कार्यालय, ओझर');
  final _agendaController = TextEditingController();

  @override
  void dispose() {
    _venueController.dispose();
    _agendaController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveMeeting() {
    if (_formKey.currentState!.validate() && _selectedDate != null && _selectedTime != null) {
      final scheduledDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final authState = ref.read(authProvider);
      final userId = authState.currentUser?.id ?? 'admin_id';

      ref.read(meetingsProvider.notifier).createMeeting(
        villageId: 'vil_ozhar_01', // Hardcoded for pilot
        scheduledDate: scheduledDate,
        type: _selectedType,
        venue: _venueController.text,
        venueLat: 19.7800,
        venueLng: 73.2200,
        createdByUserId: userId,
        agenda: _agendaController.text,
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields including Date and Time.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        title: const Text('Schedule Meeting'),
        backgroundColor: c.scaffoldBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meeting Type', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<MeetingType>(
                dropdownColor: c.dialogBg,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                value: _selectedType,
                decoration: InputDecoration(
                  filled: c.isDark,
                  fillColor: c.isDark ? c.sunkenBg : null,
                  border: OutlineInputBorder(borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border)),
                ),
                items: MeetingType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayNameMr, style: TextStyle(color: c.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 24),
              
              Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.isDark ? AppColors.accentSaffron : AppColors.primary,
                        side: BorderSide(color: c.border),
                      ),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_selectedDate == null 
                          ? 'Select Date' 
                          : DateFormat('dd MMM yyyy').format(_selectedDate!)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.isDark ? AppColors.accentSaffron : AppColors.primary,
                        side: BorderSide(color: c.border),
                      ),
                      icon: const Icon(Icons.access_time),
                      label: Text(_selectedTime == null 
                          ? 'Select Time' 
                          : _selectedTime!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text('Venue', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _venueController,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  filled: c.isDark,
                  fillColor: c.isDark ? c.sunkenBg : null,
                  border: OutlineInputBorder(borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Venue is required' : null,
              ),
              const SizedBox(height: 24),
              
              Text('Agenda (One item per line)', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _agendaController,
                style: TextStyle(color: c.textPrimary),
                decoration: InputDecoration(
                  filled: c.isDark,
                  fillColor: c.isDark ? c.sunkenBg : null,
                  border: OutlineInputBorder(borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: c.border)),
                  hintText: 'e.g.\n1. Review claims\n2. Discuss boundary',
                  hintStyle: TextStyle(color: c.textTertiary),
                ),
                maxLines: 5,
                validator: (val) => val == null || val.isEmpty ? 'Agenda is required' : null,
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Schedule Meeting', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
