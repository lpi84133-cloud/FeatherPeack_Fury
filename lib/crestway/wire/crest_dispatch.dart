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
      if (response.statusCode >= 400) {
        return CrestReply.indeterminate;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CrestReply.fromJson(decoded);
      }
      return CrestReply.indeterminate;
    } on Object catch (error) {
      crestLog(() => '[Crestway] POST failed: $error');
      return CrestReply.indeterminate;
    } finally {
      client.close(force: true);
    }
  }
}
