// Parsed response from the config endpoint.  Only three shapes are
// recognised:
//   {"ok": true,  "url": "…", "expires": 1712345678}   → open portal
//   {"ok": false, "message": "organic"}                 → play native game
//   HTTP failure / malformed JSON                       → indeterminate
class CrestReply {
  const CrestReply({
    required this.granted,
    this.destination,
    this.expiresAt,
    this.rawMessage,
  });

  final bool granted;
  final String? destination;
  final DateTime? expiresAt;
  final String? rawMessage;

  bool get hasDestination =>
      granted && destination != null && destination!.isNotEmpty;

  bool get expired {
    final ts = expiresAt;
    if (ts == null) return false;
    return DateTime.now().isAfter(ts);
  }

  factory CrestReply.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true;
    final url = (json['url'] ?? '').toString();
    final expiresRaw = json['expires'];
    DateTime? expires;
    if (expiresRaw is int && expiresRaw > 0) {
      expires = DateTime.fromMillisecondsSinceEpoch(expiresRaw * 1000);
    } else if (expiresRaw is String) {
      final asInt = int.tryParse(expiresRaw);
      if (asInt != null && asInt > 0) {
        expires = DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      }
    }
    return CrestReply(
      granted: ok && url.isNotEmpty,
      destination: url.isEmpty ? null : url,
      expiresAt: expires,
      rawMessage: (json['message'] ?? '').toString(),
    );
  }

  static const CrestReply indeterminate = CrestReply(granted: false);
}
