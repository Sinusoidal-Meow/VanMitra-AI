import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/attendance_record.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/auth_provider.dart';
// Note: We'll create a simple provider/service in this file for demo purposes 
// or use the existing ones if available. I will define a dummy provider to mock 
// village members to keep this self-contained for the pilot.

class AttendanceManagementScreen extends ConsumerStatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  ConsumerState<AttendanceManagementScreen> createState() => _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState extends ConsumerState<AttendanceManagementScreen> {
  // Mocking registered members for the pilot
  final int totalRegistered = 500;
  final int totalWomen = 250;
  final int requiredQuorum = 250; // 50%
  final int requiredWomenQuorum = 84; // 1/3rd of 250

  @override
  Widget build(BuildContext context) {
    final meetingId = ModalRoute.of(context)?.settings.arguments as String?;
    if (meetingId == null) return const Scaffold(body: Center(child: Text('Error')));

    // Watch the attendance for this meeting
    final attendanceState = ref.watch(attendanceProvider);
    final records = attendanceState.where((r) => r.meetingId == meetingId).toList();

    final int currentAttendees = records.length;
    // Mocking that 40% of attendees are women for the UI calculation
    final int currentWomenAttendees = (currentAttendees * 0.4).round();

    final bool isOverallQuorumMet = currentAttendees >= requiredQuorum;
    final bool isWomenQuorumMet = currentWomenAttendees >= requiredWomenQuorum;

    final c = context.colors;
    return Scaffold(
      backgroundColor: c.scaffoldBg,
      appBar: AppBar(
        title: const Text('Manage Attendance'),
        backgroundColor: c.scaffoldBg,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Quorum Dashboard
          Container(
            padding: const EdgeInsets.all(16),
            color: c.isDark ? c.cardBg : AppColors.primary.withValues(alpha: 0.1),
            child: Column(
              children: [
                Text(
                  'Live Quorum Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: c.textPrimary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _QuorumIndicator(
                      title: 'Overall (50%)',
                      current: currentAttendees,
                      required: requiredQuorum,
                      isMet: isOverallQuorumMet,
                    ),
                    _QuorumIndicator(
                      title: 'Women (1/3rd)',
                      current: currentWomenAttendees,
                      required: requiredWomenQuorum,
                      isMet: isWomenQuorumMet,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          // List of attendees
          Expanded(
            child: records.isEmpty
                ? Center(child: Text('No attendees yet.', style: TextStyle(color: c.textSecondary)))
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: record.method == VerificationMethod.gpsFace
                              ? AppColors.secondary
                              : (c.isDark ? AppColors.accentSaffron : AppColors.primary),
                          child: Icon(
                            record.method == VerificationMethod.gpsFace
                                ? Icons.face
                                : Icons.person_add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text('Member ID: ${record.memberId}', style: TextStyle(color: c.textPrimary)),
                        subtitle: Text('Checked in at ${record.timestamp.hour}:${record.timestamp.minute}', style: TextStyle(color: c.textSecondary)),
                        trailing: const Icon(Icons.check_circle, color: AppColors.success),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () {
              final villageId = ref.read(authProvider).currentUser?.villageId ?? '';
              ref.read(attendanceProvider.notifier).addRecord(
                    AttendanceRecord(
                      id: 'att_${DateTime.now().millisecondsSinceEpoch}',
                      meetingId: meetingId,
                      memberId: 'mem_rand_${DateTime.now().millisecondsSinceEpoch}',
                      memberName: 'Random Member',
                      villageId: villageId, // FIX: Problem 8
                      timestamp: DateTime.now(),
                      gpsLatitude: 19.7800,
                      gpsLongitude: 73.2200,
                      method: VerificationMethod.manual,
                      gpsVerified: true,
                      gender: 'female',
                      category: 'general',
                    ),
                  );
            },
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text('Manual Check-in', style: TextStyle(color: Colors.white, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.isDark ? AppColors.accentSaffron : AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuorumIndicator extends StatelessWidget {
  final String title;
  final int current;
  final int required;
  final bool isMet;

  const _QuorumIndicator({
    required this.title,
    required this.current,
    required this.required,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 14, color: c.textSecondary)),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: (current / required).clamp(0.0, 1.0),
                backgroundColor: c.isDark ? AppColors.forestDeep : Colors.grey[300],
                color: isMet ? AppColors.success : AppColors.error,
                strokeWidth: 8,
              ),
            ),
            Text(
              '$current/$required',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isMet ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
