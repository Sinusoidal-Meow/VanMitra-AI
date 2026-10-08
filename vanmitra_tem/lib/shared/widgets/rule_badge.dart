import 'package:flutter/material.dart';

class RuleBadge extends StatelessWidget {
  final String rule;
  final Color? backgroundColor;
  final Color? textColor;

  const RuleBadge({
    super.key,
    required this.rule,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blueGrey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blueGrey.shade300, width: 0.8),
      ),
      child: Text(
        rule.startsWith('[') ? rule : '[$rule]',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor ?? Colors.blueGrey.shade900,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
