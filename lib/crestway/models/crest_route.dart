// A single install commits to one of these routes.  `undecided` is the
// starting value used until the pipeline has enough information; `portal`
// is the WebView path, `native` is the white game.
enum CrestRoute { undecided, portal, native }

extension CrestRouteStorage on CrestRoute {
  String get token {
    switch (this) {
      case CrestRoute.undecided:
        return 'undecided';
      case CrestRoute.portal:
        return 'portal';
      case CrestRoute.native:
        return 'native';
    }
  }

  static CrestRoute fromToken(String? raw) {
    switch (raw) {
      case 'portal':
        return CrestRoute.portal;
      case 'native':
        return CrestRoute.native;
      default:
        return CrestRoute.undecided;
    }
  }
}
