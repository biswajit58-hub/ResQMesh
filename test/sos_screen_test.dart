import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:resqmesh/core/localization/app_localizations.dart';
import 'package:resqmesh/core/location/location_service.dart';
import 'package:resqmesh/core/security/secret_store.dart';
import 'package:resqmesh/core/theme/app_theme.dart';
import 'package:resqmesh/models/app_settings.dart';
import 'package:resqmesh/models/geo_fix.dart';
import 'package:resqmesh/services/app_state.dart';
import 'package:resqmesh/features/sos/sos_screen.dart';
import 'package:resqmesh/widgets/common.dart';

class _FakeSosState extends AppState {
  _FakeSosState() : super(secretStore: InMemorySecretStore(), enableRadio: false) {
    settings = AppSettings.defaults().copyWith(demoMode: true);
  }

  @override
  GeoFix? get currentLocation => null;

  @override
  bool get isDemo => true;

  @override
  Future<LocationAttempt> acquireLocation({
    bool requestPermission = true,
    bool announce = true,
  }) async =>
      const LocationAttempt(
        fix: null,
        message: 'No GPS in widget test',
        permissionDenied: false,
        serviceDisabled: true,
        usedFallback: false,
      );
}

void main() {
  testWidgets('SOS form renders in demo/offline fallback state', (tester) async {
    final state = _FakeSosState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SosScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.byType(DemoBanner), findsOneWidget);
    expect(find.text('SEND SOS'), findsOneWidget);
    expect(find.text('Flood'), findsWidgets);
    // The fallback path must expose manual coordinate entry when GPS is absent.
    await tester.tap(find.text('Enter coordinates').first);
    await tester.pump();
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
  });
}
