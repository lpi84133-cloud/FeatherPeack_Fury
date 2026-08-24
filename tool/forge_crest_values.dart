import 'dart:io';

import 'package:featherpeakfurygame/crestway/keep/plume_cipher.dart';

// Regenerates the encoded byte arrays pasted into `crest_config.dart`.
// Run:  dart run tool/forge_crest_values.dart
// Every entry is round-tripped and the tool aborts on any mismatch, so a
// mistake in the cipher can never ship a corrupt endpoint or dev key.

void main() {
  final plain = <String, String>{
    'configEndpoint': 'https://featherpeakfury.com/config.php',
    'appsFlyerDevKey': 'pm2vb9YkvU9sNLRVWVnKED',
    'firebaseProjectNumber': '951687956128',
    'oneLinkHost': 'featherpeakfury.onelink.me',
    'gcdBase': 'https://gcdsdk.appsflyer.com',
    'bundleId': 'com.featherpeakfury.featherpeakfurygame',
    'appName': 'FeatherpeakFury',
    'uaProduct': 'Mozilla/5.0',
    'uaPlatformPrefix': '(iPhone; CPU iPhone OS',
    'uaPlatformSuffix': 'like Mac OS X)',
    'uaEngine': 'AppleWebKit/605.1.15 (KHTML, like Gecko)',
    'uaMobileToken': 'Mobile/15E148',
    'safariVersion': '18.2',
    'safariTail': '604.1',
    'uaAppIdToken': 'appid/',
    'uaAppNameToken': 'appname/',
  };

  stdout.writeln('// Paste the block below into crest_config.dart.');
  stdout.writeln('// VERIFY comments must match the plaintext byte-for-byte.');
  stdout.writeln('');

  for (final entry in plain.entries) {
    final encoded = furl(entry.value);
    final decoded = unfurl(encoded);
    if (decoded != entry.value) {
      stderr.writeln('ROUND-TRIP MISMATCH for ${entry.key}');
      exit(1);
    }
    stdout.writeln('  // VERIFY: ${entry.key} = "${entry.value}"');
    stdout.writeln(
      '  static const List<int> ${entry.key} = <int>[${encoded.join(', ')}];',
    );
  }
}
