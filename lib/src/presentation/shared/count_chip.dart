import 'package:flutter/material.dart';

class CountChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color? textColor;

  const CountChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text('$value', style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
