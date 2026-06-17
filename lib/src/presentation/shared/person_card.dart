import 'package:flutter/material.dart';

import '../../domain/entities.dart';
import '../../core/theme/app_theme.dart';
import 'pill_button.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final AttendanceStatus status;
  final bool showWarn;
  final VoidCallback onMarkP;
  final VoidCallback onMarkF;
  final VoidCallback onMarkJ;

  const PersonCard({
    super.key,
    required this.person,
    required this.status,
    required this.showWarn,
    required this.onMarkP,
    required this.onMarkF,
    required this.onMarkJ,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(blurRadius: 10, color: AppTheme.cardShadow)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(children: [
                CircleAvatar(child: Text(_initials(person.fullName))),
                const SizedBox(width: 12),
                Flexible(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          person.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (showWarn) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            PillButton(
              label: 'P',
              active: status == AttendanceStatus.present,
              activeColor: AppTheme.success,
              onTap: onMarkP,
            ),
            const SizedBox(width: 8),
            PillButton(
              label: 'F',
              active: status == AttendanceStatus.unjustifiedAbsence,
              activeColor: AppTheme.error,
              onTap: onMarkF,
            ),
            const SizedBox(width: 8),
            PillButton(
              label: 'J',
              active: status == AttendanceStatus.justifiedAbsence,
              activeColor: AppTheme.warning,
              foregroundWhenActive: Colors.black87,
              onTap: onMarkJ,
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((e) => e[0])
      .join()
      .toUpperCase();
}
