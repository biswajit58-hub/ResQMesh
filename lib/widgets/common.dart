import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';

class GlowSurface extends StatelessWidget {
  const GlowSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
    this.radius = 18,
    this.background,
    this.borderColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final double radius;
  final Color? background;
  final Color? borderColor;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: background ?? AppColors.surface,
          border: Border.all(color: borderColor ?? AppColors.border),
          gradient: background == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: accent == null
                      ? [AppColors.surface, AppColors.backgroundAlt]
                      : [
                          Color.alphaBlend(
                              accent!.withValues(alpha: 0.08), AppColors.surface),
                          AppColors.surface,
                        ],
                )
              : null,
          boxShadow: accent == null
              ? null
              : [
                  BoxShadow(
                    color: accent!.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
    this.filled = false,
    this.onTap,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.18)
            : color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 9.5 : 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'DEMO'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.amber,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.cyan,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 20 : 36,
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.textDim, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (body != null) ...[
            const SizedBox(height: 5),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.09),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: AppColors.amber, size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              compact ? context.tr('demo_data') : context.tr('demo_banner'),
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.cyan,
    this.footer,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlowSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const Spacer(),
              if (footer != null)
                Text(
                  footer!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
