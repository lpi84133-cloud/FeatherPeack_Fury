import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for the on-device tour. Screenshots land in `screenshots/` so the
/// whole app can be reviewed without tapping through it by hand.
Future<void> main() async {
  final directory = Directory('screenshots');
  if (!directory.existsSync()) directory.createSync(recursive: true);

  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('${directory.path}/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
