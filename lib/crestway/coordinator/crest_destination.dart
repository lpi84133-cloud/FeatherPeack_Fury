// Outcome of the routing pipeline.  The gate widget renders exactly one
// of the four cases.
sealed class CrestDestination {
  const CrestDestination();
}

class OpenPortal extends CrestDestination {
  const OpenPortal(this.url, {this.fromColdStartPush = false});
  final String url;
  final bool fromColdStartPush;
}

class OpenNative extends CrestDestination {
  const OpenNative();
}

class InviteThenPortal extends CrestDestination {
  const InviteThenPortal(this.url);
  final String url;
}

class Unreachable extends CrestDestination {
  const Unreachable();
}
