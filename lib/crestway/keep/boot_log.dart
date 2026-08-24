import 'package:flutter/foundation.dart';

// Assert-wrapped logger.  The closure is invoked only in debug builds so
// both the arguments and the format strings are stripped from release
// binaries — see `apple_moderation_hardening.mdc` §9.9.
//
// Kept as a single-line `assert(() { debugPrint(...); return true; }());`
// so the §9.9 grep filter can strip this file too.
void crestLog(String Function() build) {
  assert(() { debugPrint(build()); return true; }());
}
