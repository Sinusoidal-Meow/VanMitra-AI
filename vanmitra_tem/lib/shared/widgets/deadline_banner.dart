import 'package:flutter/material.dart';

class DeadlineBanner extends StatelessWidget {
  final String remarks;
  final int daysLeft;
  final String? returnedByName;
  final String? returnedByRole;

  const DeadlineBanner({
    super.key,
    required this.remarks,
    required this.daysLeft,
    this.returnedByName,
    this.returnedByRole,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = daysLeft <= 15;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent ? Colors.red.shade300 : Colors.amber.shade400,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: isUrgent ? Colors.red.shade700 : Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'दावा त्रुटींसाठी परत केला / Claim Returned for Corrections',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUrgent ? Colors.red.shade900 : Colors.amber.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUrgent ? Colors.red.shade700 : Colors.amber.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysLeft दिवस शिल्लक ($daysLeft days left)',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (returnedByName != null || returnedByRole != null)
            Text(
              'Returned by: ${returnedByName ?? ''} (${returnedByRole ?? ''})',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          Text(
            'Remarks / शेरा: $remarks',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          const Text(
            'Under Rule 12A(7), you have 60 days to fix and resubmit.',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
