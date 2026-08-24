import Flutter
import UIKit

// Cold-start push tap capture.  The URL is written to standard user
// defaults under the key `flutter.crestway.fp.beacon_url` so the Dart
// side reads it via `LaunchBeacon.consume()` on first frame.
class SceneDelegate: FlutterSceneDelegate {

  private static let beaconKey = "flutter.crestway.fp.beacon_url"

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Deep-link / URL context launched via a scheme.
    if let urlContext = connectionOptions.urlContexts.first {
      storeBeacon(urlContext.url.absoluteString)
    }
    // Notification tap — the push response is in the connection options
    // when the app was terminated.
    if let response = connectionOptions.notificationResponse {
      if let url = SceneDelegate.extractUrl(from: response.notification.request.content.userInfo) {
        storeBeacon(url)
      }
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if let ctx = URLContexts.first { storeBeacon(ctx.url.absoluteString) }
    super.scene(scene, openURLContexts: URLContexts)
  }

  private func storeBeacon(_ url: String) {
    guard !url.isEmpty else { return }
    UserDefaults.standard.set(url, forKey: SceneDelegate.beaconKey)
  }

  static func extractUrl(from userInfo: [AnyHashable: Any]) -> String? {
    let candidateKeys = ["url", "link", "target", "deeplink", "deep_link"]
    for key in candidateKeys {
      if let v = userInfo[key] as? String, !v.isEmpty { return v }
    }
    if let data = userInfo["data"] as? [AnyHashable: Any] {
      if let nested = extractUrl(from: data) { return nested }
    }
    if let payload = userInfo["payload"] as? [AnyHashable: Any] {
      if let nested = extractUrl(from: payload) { return nested }
    }
    return nil
  }
}
