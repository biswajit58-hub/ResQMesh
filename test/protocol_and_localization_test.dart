import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/localization/app_localizations.dart';
import 'package:resqmesh/models/app_settings.dart';
import 'package:resqmesh/models/enums.dart';
import 'package:resqmesh/services/protocol_simulation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('protocol simulation exercises real crypto and rejects adversarial input',
      () async {
    final report = await ProtocolSimulationService().run();
    expect(report.isSimulation, isTrue);
    expect(report.deliveredToC, isTrue);
    expect(report.hopCount, 1);
    expect(report.duplicateDropped, isTrue);
    expect(report.tamperedRejected, isTrue);
    expect(report.expiredRejected, isTrue);
    expect(report.steps.length, greaterThanOrEqualTo(9));
    expect(
      report.steps.map((step) => step.label).join(' '),
      contains('Duplicate replay rejected'),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('settings JSON round-trips all locales', () {
    for (final language in AppLanguage.values) {
      final settings = AppSettings.defaults().copyWith(
        language: language,
        deviceName: 'ResQ-TEST',
        demoMode: true,
        demoScenario: DemoScenario.flood,
      );
      final decoded =
          AppSettings.fromJson(settings.toJson().cast<String, dynamic>());
      expect(decoded.language, language);
      expect(decoded.deviceName, 'ResQ-TEST');
      expect(decoded.demoMode, isTrue);
      expect(decoded.demoScenario, DemoScenario.flood);
    }
  });

  test('English, Hindi and Odia translations are present', () {
    const en = AppLocalizations(Locale('en'));
    const hi = AppLocalizations(Locale('hi'));
    const or = AppLocalizations(Locale('or'));
    expect(en.t('app_tagline'), contains('peer-to-peer'));
    expect(hi.t('offline'), 'ऑफ़लाइन');
    expect(or.t('offline'), 'ଅଫଲାଇନ୍');
    expect(en.t('sos_send'), 'SEND SOS');
    expect(hi.t('sos_send'), 'SOS भेजें');
    expect(or.t('sos_send'), 'SOS ପଠାନ୍ତୁ');
    expect(en.t('peers_connected', {'count': 3}), contains('3'));
  });
}
