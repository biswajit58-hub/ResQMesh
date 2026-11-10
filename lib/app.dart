import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/permission_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/shell/app_shell.dart';
import 'services/app_state.dart';

class ResQMeshApp extends StatelessWidget {
  const ResQMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.select<AppState, String>(
      (state) => state.settings.language.code,
    );
    return MaterialApp(
      title: 'ResQMesh',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: Locale(language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (!state.ready && !state.initializing) {
        state.initialize();
      } else if (state.initializing && !state.ready) {
        // AppState is constructed in the initializing state; kick it off.
        state.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.initError != null) {
      return SplashScreen(error: state.initError, onRetry: state.initialize);
    }
    if (!state.ready) {
      return const SplashScreen();
    }
    if (!state.settings.onboardingDone) {
      return const OnboardingScreen();
    }
    if (!state.settings.permissionsDone) {
      return const PermissionScreen();
    }
    return const AppShell();
  }
}
