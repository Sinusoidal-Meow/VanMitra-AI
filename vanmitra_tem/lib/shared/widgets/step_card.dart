import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum StepStatus {
  completed,
  inProgress,
  pending,
  actionRequired,
}

class StepCard extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String subtitle;
  final StepStatus status;
  final VoidCallback? onTap;

  const StepCard({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case StepStatus.completed:
        statusColor = Colors.green;
        statusLabel = 'पूर्ण / Completed';
        statusIcon = Icons.check_circle;
        break;
      case StepStatus.inProgress:
        statusColor = AppColors.primary;
        statusLabel = 'चालू / In Progress';
        statusIcon = Icons.play_circle_outline;
        break;
      case StepStatus.actionRequired:
        statusColor = Colors.amber.shade800;
        statusLabel = 'कृती आवश्यक / Action Required';
        statusIcon = Icons.error_outline;
        break;
      case StepStatus.pending:
        statusColor = Colors.grey;
        statusLabel = 'प्रलंबित / Pending';
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: status == StepStatus.inProgress ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status == StepStatus.inProgress ? AppColors.primary : Colors.grey.shade200,
          width: status == StepStatus.inProgress ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: status == StepStatus.completed
                    ? Colors.green.shade100
                    : (status == StepStatus.inProgress ? AppColors.primary.withOpacity(0.12) : Colors.grey.shade100),
                child: Text(
                  '$stepNumber',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: status == StepStatus.completed
                        ? Colors.green.shade800
                        : (status == StepStatus.inProgress ? AppColors.primary : Colors.grey.shade700),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
