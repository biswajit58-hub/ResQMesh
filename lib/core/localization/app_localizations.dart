import 'package:flutter/material.dart';

import 'strings_en.dart';
import 'strings_hi.dart';
import 'strings_or.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;
  static const supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('or'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return value ?? const AppLocalizations(Locale('en'));
  }

  Map<String, String> get _strings {
    switch (locale.languageCode) {
      case 'hi':
        return stringsHi;
      case 'or':
        return stringsOr;
      default:
        return stringsEn;
    }
  }

  String t(String key, [Map<String, Object?> args = const {}]) {
    var value = _strings[key] ?? stringsEn[key] ?? key;
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'hi', 'or'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key, [Map<String, Object?> args = const {}]) =>
      l10n.t(key, args);
}
