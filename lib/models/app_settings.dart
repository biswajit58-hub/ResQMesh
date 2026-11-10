import 'enums.dart';

class AppSettings {
  const AppSettings({
    required this.language,
    required this.deviceName,
    required this.onboardingDone,
    required this.permissionsDone,
    required this.autoConnect,
    required this.demoMode,
    required this.demoScenario,
    required this.responderPinConfigured,
    required this.meshAutoStart,
    required this.lastKnownPeerName,
  });

  final AppLanguage language;
  final String deviceName;
  final bool onboardingDone;
  final bool permissionsDone;
  final bool autoConnect;
  final bool demoMode;
  final DemoScenario demoScenario;
  final bool responderPinConfigured;
  final bool meshAutoStart;
  final String? lastKnownPeerName;

  factory AppSettings.defaults() => const AppSettings(
        language: AppLanguage.english,
        deviceName: '',
        onboardingDone: false,
        permissionsDone: false,
        autoConnect: true,
        demoMode: false,
        demoScenario: DemoScenario.none,
        responderPinConfigured: false,
        meshAutoStart: true,
        lastKnownPeerName: null,
      );

  AppSettings copyWith({
    AppLanguage? language,
    String? deviceName,
    bool? onboardingDone,
    bool? permissionsDone,
    bool? autoConnect,
    bool? demoMode,
    DemoScenario? demoScenario,
    bool? responderPinConfigured,
    bool? meshAutoStart,
    String? lastKnownPeerName,
  }) =>
      AppSettings(
        language: language ?? this.language,
        deviceName: deviceName ?? this.deviceName,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        permissionsDone: permissionsDone ?? this.permissionsDone,
        autoConnect: autoConnect ?? this.autoConnect,
        demoMode: demoMode ?? this.demoMode,
        demoScenario: demoScenario ?? this.demoScenario,
        responderPinConfigured:
            responderPinConfigured ?? this.responderPinConfigured,
        meshAutoStart: meshAutoStart ?? this.meshAutoStart,
        lastKnownPeerName: lastKnownPeerName ?? this.lastKnownPeerName,
      );

  Map<String, Object?> toJson() => {
        'language': language.code,
        'deviceName': deviceName,
        'onboardingDone': onboardingDone,
        'permissionsDone': permissionsDone,
        'autoConnect': autoConnect,
        'demoMode': demoMode,
        'demoScenario': demoScenario.wire,
        'responderPinConfigured': responderPinConfigured,
        'meshAutoStart': meshAutoStart,
        'lastKnownPeerName': lastKnownPeerName,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        language: AppLanguage.fromCode(json['language'] as String?),
        deviceName: json['deviceName'] as String? ?? '',
        onboardingDone: json['onboardingDone'] as bool? ?? false,
        permissionsDone: json['permissionsDone'] as bool? ?? false,
        autoConnect: json['autoConnect'] as bool? ?? true,
        demoMode: json['demoMode'] as bool? ?? false,
        demoScenario: DemoScenario.fromWire(json['demoScenario'] as String?),
        responderPinConfigured:
            json['responderPinConfigured'] as bool? ?? false,
        meshAutoStart: json['meshAutoStart'] as bool? ?? true,
        lastKnownPeerName: json['lastKnownPeerName'] as String?,
      );
}
