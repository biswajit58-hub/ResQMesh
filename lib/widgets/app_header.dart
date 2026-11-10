import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'brand.dart';
import 'common.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showBack = false,
    this.trailing,
    this.showLogo = true,
  });

  final String? title;
  final String? subtitle;
  final bool showBack;
  final Widget? trailing;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBack)
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          )
        else if (showLogo)
          const MeshLogo(size: 36),
        if (showLogo || showBack) const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? 'ResQMesh',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.text,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDim,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class NetworkPill extends StatelessWidget {
  const NetworkPill({
    super.key,
    required this.online,
    required this.meshConnected,
  });

  final bool online;
  final int meshConnected;

  @override
  Widget build(BuildContext context) {
    final color = online
        ? AppColors.green
        : meshConnected > 0
            ? AppColors.cyan
            : AppColors.amber;
    final label = online
        ? context.tr('online')
        : meshConnected > 0
            ? context.tr('mesh_active')
            : context.tr('offline');
    return StatusPill(
      label: label,
      color: color,
      icon: online
          ? Icons.public_rounded
          : meshConnected > 0
              ? Icons.hub_rounded
              : Icons.wifi_off_rounded,
      dense: true,
    );
  }
}


