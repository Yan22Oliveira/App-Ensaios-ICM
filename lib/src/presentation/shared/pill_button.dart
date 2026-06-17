import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PillButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color? foregroundWhenActive;
  final VoidCallback onTap;

  const PillButton({
    super.key,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.foregroundWhenActive,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? activeColor : AppTheme.neutralLight;
    final tx = active ? (foregroundWhenActive ?? Colors.white) : Colors.black54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44, height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: tx)),
            if (active)
              Positioned(
                right: 6, bottom: 4,
                child: Text('X', style: TextStyle(fontSize: 10, color: tx, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
