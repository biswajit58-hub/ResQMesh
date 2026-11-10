import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/localization/app_localizations.dart';
import 'package:resqmesh/core/theme/app_theme.dart';
import 'package:resqmesh/widgets/brand.dart';
import 'package:resqmesh/widgets/common.dart';
import 'package:resqmesh/widgets/sos_button.dart';

void main() {
  testWidgets('SOS button is tap-accessible and invokes its callback',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SosButton(
            onPressed: () async {
              tapped = true;
            },
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('SOS'), findsOneWidget);
    await tester.tap(find.byType(SosButton));
    await tester.pump();
    expect(tapped, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('brand, status pill and empty state render', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Column(
          children: [
            MeshLogo(size: 40),
            StatusPill(
              label: 'OFFLINE',
              color: Colors.amber,
              icon: Icons.wifi_off_rounded,
            ),
            EmptyState(
              icon: Icons.inbox_rounded,
              title: 'Empty',
              body: 'Nothing here',
            ),
            GradientButton(label: 'Continue', onPressed: null),
          ],
        ),
      ),
    ));
    expect(find.text('OFFLINE'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
