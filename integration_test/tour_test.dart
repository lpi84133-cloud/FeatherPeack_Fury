import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:featherpeakfurygame/main.dart' as app;
import 'package:featherpeakfurygame/shared/widgets/fp_avatar.dart';

/// Walks the whole app on a real device: boot, onboarding, creating a trip,
/// every stage of the workspace, then profile, settings, the offline legal pages
/// and the archive. Screenshots are written by the driver so the result can be
/// reviewed as a set.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder byHint(String hint) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );

  Finder bySuffix(String suffix) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.suffixText == suffix,
  );

  testWidgets('tour every screen', (tester) async {
    Future<void> settle([int milliseconds = 350]) async {
      await tester.pump(Duration(milliseconds: milliseconds));
      await tester.pump(const Duration(milliseconds: 120));
    }

    Future<void> waitFor(Finder finder, {required String label}) async {
      for (var attempt = 0; attempt < 120; attempt++) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 200));
      }
      fail('Timed out waiting for $label');
    }

    Future<void> shoot(String name) async {
      await settle(500);
      await binding.takeScreenshot(name);
    }

    Future<void> tapText(String text, {int index = 0}) async {
      final finder = find.text(text);
      await waitFor(finder, label: 'text "$text"');
      await tester.tap(index == 0 ? finder.first : finder.at(index));
      await settle();
    }

    app.main();
    await tester.pump(const Duration(milliseconds: 700));
    await shoot('01-boot-progress');

    // Onboarding: four cards explaining Peak, Feather, Egg and Coin.
    await waitFor(find.text('Next'), label: 'onboarding');
    await shoot('02-onboarding-peak');
    await tapText('Next');
    await tapText('Next');
    await shoot('03-onboarding-egg');
    await tapText('Next');
    await tapText('Start planning');

    // Basecamp with nothing planned yet.
    await waitFor(find.text('BASECAMP'), label: 'home');
    await shoot('04-home-empty');

    // Create a trip through the real form.
    await tapText('Plan a new trip');
    await waitFor(find.text('New trip'), label: 'create trip');
    await tester.enterText(byHint('Pine Ridge Loop'), 'Pine Ridge Loop');
    await settle();
    await tester.enterText(bySuffix('km'), '12.5');
    await settle();
    await tester.enterText(bySuffix('m').first, '850');
    await settle();
    await tester.enterText(bySuffix('h'), '5');
    await settle();
    await tester.enterText(bySuffix('m').last, '30');
    await settle();
    await tapText('Rocky & technical');
    await shoot('05-create-trip');

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await settle();
    await tester.enterText(bySuffix('L'), '2');
    await settle();
    await tester.enterText(bySuffix('kg'), '7.5');
    await settle();
    await tapText('Create trip');

    // Route Analyzer is the first stage of the trail.
    await waitFor(find.text('Route Analyzer'), label: 'workspace');
    await shoot('06-route-analyzer');

    await tapText('Peak');
    await shoot('07-peak-profile');

    // Feather Load, with a gear item added through the sheet.
    await tapText('Load');
    await tester.tap(find.byType(FloatingActionButton).first);
    await settle(450);
    await tester.enterText(byHint('Rain shell, stove, headlamp…'), 'Rain shell');
    await settle();
    await tester.enterText(bySuffix('kg'), '0.42');
    await settle();
    await tapText('Add to pack');
    await waitFor(find.text('Rain shell'), label: 'saved gear item');
    await shoot('08-feather-load');

    await tapText('Food');
    await shoot('09-egg-pack');

    // CoinBudget, with an expense added through the sheet.
    await tapText('Budget');
    await tester.tap(find.byType(FloatingActionButton).first);
    await settle(450);
    await tester.enterText(bySuffix(r'$'), '48');
    await settle();
    await tapText('Add to budget');
    await settle(1200);
    await shoot('10-coin-budget');

    await tapText('Zones');
    await shoot('11-fury-zones');

    await tapText('Card');
    await shoot('12-trip-card');

    // Back to Basecamp, now with a trip in progress.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await waitFor(find.text('BASECAMP'), label: 'home again');
    await shoot('13-home-with-trip');

    // Profile, including the load reference that drives the calculations.
    await tester.tap(find.byType(FpAvatar).first);
    await waitFor(find.text('Hiker profile'), label: 'profile');
    await shoot('14-profile');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await waitFor(find.text('BASECAMP'), label: 'home after profile');
    await settle(700);

    // Settings and the bundled legal pages.
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await waitFor(find.text('Settings'), label: 'settings');
    await shoot('15-settings');
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await settle();
    await shoot('16-settings-data');
    await tapText('Privacy Policy');
    await waitFor(find.text('Privacy Policy'), label: 'privacy page');
    await shoot('17-privacy-offline');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await settle(600);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await waitFor(find.text('BASECAMP'), label: 'home after settings');

    // Archive.
    await tapText('See all');
    await waitFor(find.text('Trip archive'), label: 'archive');
    await shoot('18-archive');
  });
}
