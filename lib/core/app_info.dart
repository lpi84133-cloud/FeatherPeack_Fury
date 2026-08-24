/// Static facts about the published app. Nothing here is fetched at runtime:
/// the app has no server, no remote configuration and no analytics endpoint.
abstract final class AppInfo {
  static const name = 'Featherpeak Fury';
  static const tagline = 'Offline trip preparation';

  /// Kept in step with the `version` field in pubspec.yaml.
  static const version = '1.0.2';

  static const appStoreId = '6802345538';
  static const appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';

  static const privacyPolicyUrl =
      'https://featherpeakfury.com/privacy-policy.html';
  static const supportUrl = 'https://featherpeakfury.com/support.html';
  static const supportEmail = 'support@featherpeakfury.com';

  /// Bundled copies of the legal pages. They are the default source shown in
  /// the app so the pages open instantly and work with no connection.
  static const privacyAsset = 'assets/legal/privacy-policy.html';
  static const supportAsset = 'assets/legal/support.html';
  static const faqAsset = 'assets/legal/faq.html';
}
