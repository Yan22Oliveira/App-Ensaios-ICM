import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Design tokens simples (segue seu padrão)
class AppRadius {
  static const large = 20.0;
  static const medium = 14.0;
  static const pill = 999.0;
}

class AppSpace {
  static const card = EdgeInsets.all(16);
  static const section = EdgeInsets.symmetric(horizontal: 24, vertical: 24);
}

/// Sombra padrão já usada no app (reexporta para centralizar)
const kSoftShadow = BoxShadow(blurRadius: 16, color: AppTheme.cardShadow);

/// Card branco com sombra e cantos grandes.
/// Se [onTap] estiver presente, já aplica InkWell com ripple.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = AppSpace.card,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: const [kSoftShadow],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.large),
      onTap: onTap,
      child: card,
    );
  }
}

/// Chip “pill” no padrão do app
class PillChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final EdgeInsets padding;

  const PillChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho “hero” com avatar (foto ou iniciais), título/subtítulo e tags.
class HeroHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? photoUrl;
  final String initials;
  final List<Widget> tags;
  final Color accent;

  const HeroHeaderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initials,
    this.photoUrl,
    required this.tags,
    this.accent = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accent.withOpacity(.12),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            alignment: Alignment.center,
            child: (photoUrl != null && photoUrl!.isNotEmpty)
                ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.medium - 2),
              child: Image.network(photoUrl!, width: 56, height: 56, fit: BoxFit.cover),
            )
                : Text(
              initials,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: tags),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KPI compacto (igual ao “Resumo rápido” da Home), mas reutilizável.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Barra de ações fixa que desliza de baixo (edições).
class StickyActionsBar extends StatelessWidget {
  final Widget leading;
  final Widget primary;

  const StickyActionsBar({super.key, required this.leading, required this.primary});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [kSoftShadow],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadius.large),
            topRight: Radius.circular(AppRadius.large),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: leading),
            const SizedBox(width: 12),
            Expanded(child: primary),
          ],
        ),
      ),
    );
  }
}
