import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../theme/app_theme.dart';

Color categoryColor(EmergencyCategory category) => switch (category) {
      EmergencyCategory.flood => const Color(0xFF38BDF8),
      EmergencyCategory.earthquake => const Color(0xFFF59E0B),
      EmergencyCategory.landslide => const Color(0xFFD97706),
      EmergencyCategory.fire => const Color(0xFFFF6B35),
      EmergencyCategory.collapsedBuilding => const Color(0xFFF97316),
      EmergencyCategory.blockedRoad => const Color(0xFFA78BFA),
      EmergencyCategory.medical => const Color(0xFFFB7185),
      EmergencyCategory.infrastructure => const Color(0xFF94A3B8),
      EmergencyCategory.cyclone => const Color(0xFF38BDF8),
      EmergencyCategory.other => AppColors.textMuted,
    };

IconData categoryIcon(EmergencyCategory category) => switch (category) {
      EmergencyCategory.flood => Icons.water_rounded,
      EmergencyCategory.earthquake => Icons.vibration_rounded,
      EmergencyCategory.landslide => Icons.landscape_rounded,
      EmergencyCategory.fire => Icons.local_fire_department_rounded,
      EmergencyCategory.collapsedBuilding => Icons.domain_disabled_rounded,
      EmergencyCategory.blockedRoad => Icons.block_rounded,
      EmergencyCategory.medical => Icons.medical_services_rounded,
      EmergencyCategory.infrastructure => Icons.engineering_rounded,
      EmergencyCategory.cyclone => Icons.cyclone_rounded,
      EmergencyCategory.other => Icons.report_problem_rounded,
    };

Color severityColor(Severity severity) => switch (severity) {
      Severity.low => AppColors.green,
      Severity.moderate => AppColors.amber,
      Severity.high => const Color(0xFFFF8A4C),
      Severity.critical => AppColors.red,
    };

Color verificationColor(VerificationState state) => switch (state) {
      VerificationState.unverified => AppColors.amber,
      VerificationState.communityCorroborated => AppColors.cyan,
      VerificationState.responderVerified => AppColors.green,
      VerificationState.disputed => AppColors.red,
      VerificationState.expired => AppColors.textDim,
    };

IconData verificationIcon(VerificationState state) => switch (state) {
      VerificationState.unverified => Icons.help_outline_rounded,
      VerificationState.communityCorroborated => Icons.groups_rounded,
      VerificationState.responderVerified => Icons.verified_rounded,
      VerificationState.disputed => Icons.gavel_rounded,
      VerificationState.expired => Icons.timer_off_rounded,
    };

Color priorityColor(PriorityBand band) => switch (band) {
      PriorityBand.critical => AppColors.red,
      PriorityBand.urgent => const Color(0xFFFF8A4C),
      PriorityBand.elevated => AppColors.amber,
      PriorityBand.routine => AppColors.cyan,
    };

Color riskColor(RiskLevel level) => switch (level) {
      RiskLevel.low => AppColors.green,
      RiskLevel.moderate => AppColors.amber,
      RiskLevel.high => const Color(0xFFFF8A4C),
      RiskLevel.severe => AppColors.red,
    };

Color shelterColor(ShelterStatus status) => switch (status) {
      ShelterStatus.open => AppColors.green,
      ShelterStatus.full => AppColors.amber,
      ShelterStatus.closed => AppColors.red,
      ShelterStatus.unknown => AppColors.textDim,
    };
