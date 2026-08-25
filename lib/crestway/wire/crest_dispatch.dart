import 'dart:convert';
import 'dart:io';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';
import '../models/crest_reply.dart';

// POSTs the flat conversion payload to the config endpoint and turns the
// JSON response into a `CrestReply`.  Uses `HttpClient` directly (not
// `package:http`) so we can pin the User-Agent on the request and be sure
// no `Dart/…` / `Flutter/…` token leaks.
class CrestDispatch {
  const CrestDispatch({required this.userAgent});

  final String userAgent;

  Future<CrestReply> post(Map<String, dynamic> body) async {
    // Two attempts with a short backoff between them.  The first attempt
    // is often the one that lands right after "no-wifi → wifi restored"
    // when the TLS stack is still warming up — the second attempt
    // succeeds much more reliably.  We only retry on TRANSPORT failure
    // (indeterminate reply) — a server 2xx / 4xx answer is respected
    // immediately.
    for (var attempt = 0; attempt < 2; attempt++) {
      final reply = await _postOnce(body);
      if (reply.serverAnswered) return reply;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      }
    }
    return CrestReply.indeterminate;
  }

  Future<CrestReply> _postOnce(Map<String, dynamic> body) async {
    final client = HttpClient()
      ..connectionTimeout = CrestConfig.configPostTimeout
      ..userAgent = userAgent;
    try {
      final uri = Uri.parse(CrestConfig.configEndpoint);
      final req = await client
          .postUrl(uri)
          .timeout(CrestConfig.configPostTimeout);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.userAgentHeader, userAgent);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // Partner identity as request headers (belt-and-suspenders with the
      // UA suffix — the same convention Joker-Lantern uses successfully).
      req.headers.set('X-Partner-App-Id', CrestConfig.bundleId);
      req.headers.set('X-Partner-App-Name', 'Featherpeak Fury');
      req.write(jsonEncode(body));
      final response =
          await req.close().timeout(CrestConfig.configPostTimeout);
      final raw = await response.transform(utf8.decoder).join();
      crestLog(() =>
          '[Crestway] POST ${response.statusCode} ${raw.substring(0, raw.length.clamp(0, 200))}');
      // Partner backends sometimes respond with 4xx while STILL returning a
      // valid `{"ok":false, ...}` body (Featherpeak's backend does this for
      // pending attribution).  Parse the JSON first and honour the server
      // decision — falling through to "transport failure" would trigger a
      // pointless retry AND fail to commit the native route persistently.
      Map<String, dynamic>? decodedMap;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) decodedMap = decoded;
      } catch (_) {}
      if (decodedMap != null) {
        return CrestReply.fromJson(decodedMap);
      }
      // 5xx / malformed body → transport-level failure worth a retry.
      if (response.statusCode >= 500 || response.statusCode == 408 ||
          response.statusCode == 429) {
        return CrestReply.indeterminate;
      }
      // 2xx / 4xx without a JSON body — treat as a definitive "no URL"
      // answer so we do not hammer the endpoint on every launch.
      return const CrestReply(granted: false, serverAnswered: true);
    } on Object catch (error) {
      crestLog(() => '[Crestway] POST failed: $error');
      return CrestReply.indeterminate;
    } finally {
      client.close(force: true);
    }
  }
}
