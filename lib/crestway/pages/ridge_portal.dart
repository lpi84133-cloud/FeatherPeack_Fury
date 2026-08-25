import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';
import 'air_lost_page.dart';

// Portal WebView.  The single JS injection bundle (`_installShell`) is
// deliberately one file with one sentinel — a merged shape rather than
// the six-injection layout other portfolio shells use
// (`gray_part_mixing_review.mdc` §6b, option b).
class RidgePortal extends StatefulWidget {
  const RidgePortal({
    super.key,
    required this.url,
    required this.userAgent,
    this.coldStartPush = false,
  });

  final String url;
  final String userAgent;
  final bool coldStartPush;

  @override
  State<RidgePortal> createState() => _RidgePortalState();
}

class _RidgePortalState extends State<RidgePortal>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _viewportReady = false;
  int _redirectAttempts = 0;
  // Last successfully-loaded top-frame URL.  Retries after -1007 target
  // THIS URL rather than `widget.url`, because the redirect loop is on
  // the current chain link and going all the way back would restart from
  // the config URL and re-trigger the same chain.
  String? _lastTopUrl;
  DateTime? _lastReflow;
  StreamSubscription<List<ConnectivityResult>>? _netWatch;
  bool _leftForOffline = false;
  // The cold-start-push reload is one-shot: we do it exactly once, on the
  // first onPageFinished, then flip the flag so subsequent page loads
  // (partner redirect chain) do not keep reloading and eating clicks.
  bool _coldReloadPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // BootScreen locks portrait right before hand-off; re-enable landscape
    // for the WebView (`gray_flow_lessons.md` §10).
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final params = WebKitWebViewControllerCreationParams(
      allowsInlineMediaPlayback: true,
      mediaTypesRequiringUserAction: const {},
    );
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(widget.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(_delegate);

    // Enable WKWebView's native left-edge swipe to go back / right-edge
    // swipe to go forward.  Without this, the WebView eats the gesture
    // and the user has no way back through the redirect chain.
    final platform = _controller.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }

    // Watch for real connectivity loss AFTER the portal is open.
    // Short 300 ms debounce — enough to ignore the momentary flap on
    // background→foreground transitions, but small enough that the
    // no-wifi screen appears essentially instantly when the user really
    // pulls the plug (Wi-Fi + Cellular + VPN all off).
    _netWatch = Connectivity().onConnectivityChanged.listen((results) {
      final allGone = results.every((r) => r == ConnectivityResult.none);
      if (!allGone || _leftForOffline || !mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted || _leftForOffline) return;
        final fresh = await Connectivity().checkConnectivity();
        final stillGone = fresh.every((r) => r == ConnectivityResult.none);
        if (!stillGone || _leftForOffline || !mounted) return;
        _goOffline();
      });
    });

    _coldReloadPending = widget.coldStartPush;

    if (widget.coldStartPush) {
      _settleColdViewport();
    } else {
      _applyImmersive();
      _viewportReady = true;
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  void dispose() {
    _netWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _goOffline() {
    if (!mounted || _leftForOffline) return;
    _leftForOffline = true;
    final currentUrl = _lastTopUrl ?? widget.url;
    final ua = widget.userAgent;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AirLostPage(
          retryPageBuilder: (_) => RidgePortal(
            url: currentUrl,
            userAgent: ua,
          ),
        ),
      ),
    );
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {}); // pick up new viewPadding
    final now = DateTime.now();
    if (_lastReflow != null &&
        now.difference(_lastReflow!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastReflow = now;
    _pokeReflow();
  }

  Future<void> _settleColdViewport() async {
    _applyImmersive();
    await Future<void>.delayed(CrestConfig.coldViewportSettle);
    if (!mounted) return;
    setState(() => _viewportReady = true);
    await _controller.loadRequest(Uri.parse(widget.url));
  }

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  NavigationDelegate get _delegate => NavigationDelegate(
        onPageStarted: (_) async {
          // Race-guard: install the click fix-up as early as possible so
          // a fast user tap on a `target="_blank"` button does not get
          // silently dropped by WKWebView between page render and our
          // main injection in onPageFinished.  Idempotent.
          await _rewriteBlankTargets();
        },
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          switch (uri.scheme) {
            case 'http':
            case 'https':
            case 'about':
            case 'data':
            case 'blob':
              // Remember the last main-frame URL so a redirect-loop
              // retry lands on the current chain link, not on the
              // original config URL that would re-trigger the same loop.
              if (request.isMainFrame) _lastTopUrl = request.url;
              return NavigationDecision.navigate;
            case 'javascript':
              return NavigationDecision.prevent;
            case 'tel':
            case 'mailto':
            case 'sms':
            case 'facetime':
              await _launchExternal(uri);
              return NavigationDecision.prevent;
            default:
              // Any other app-scheme (whatsapp, tg, viber, …) — hand off
              // to the OS.  We deliberately do NOT gate on host — the
              // config endpoint may rotate the partner host after
              // release (`apple_moderation_hardening.mdc` §6).
              await _launchExternal(uri);
              return NavigationDecision.prevent;
          }
        },
        onPageFinished: (_) async {
          // Successful load — reset the redirect counter so the next
          // page navigation gets a fresh retry budget.  Do NOT reset in
          // onPageStarted: the retry itself fires onPageStarted, which
          // would zero the counter and turn `retryLimit` into an
          // infinite loop.
          _redirectAttempts = 0;
          await _installShell();
          // Second-pass install: some pages inject their button DOM
          // between our first-pass rewrite and the user's tap.  Idempotent
          // (sentinel-guarded) — this catches any late-added `_blank`
          // links that MutationObserver didn't fire for yet.
          await _rewriteBlankTargets();
          if (mounted) setState(() {});
          Future.delayed(CrestConfig.postFinishedResizeDelay, () async {
            if (!mounted) return;
            await _controller.runJavaScript(
              "window.dispatchEvent(new Event('resize'));",
            );
            if (_coldReloadPending) {
              // One-shot: reload only the first page finish after a
              // cold-start push, otherwise every hop in the partner
              // redirect chain would reload itself and swallow taps.
              _coldReloadPending = false;
              await _controller.reload();
            }
          });
        },
        onWebResourceError: (error) async {
          // WKWebView reports `null` for isForMainFrame on the main
          // navigation sometimes (`gray_flow_lessons.md` §1).
          final mainFrame = error.isForMainFrame ?? true;
          if (error.errorCode == -999) return; // cancelled
          if (!mainFrame) return;

          // Real network death — WKWebView surfaces this before
          // connectivity_plus does, especially when VPN drops.  Show
          // the no-wifi screen immediately; retry restores the exact
          // URL the user was on.
          //   -1009 NSURLErrorNotConnectedToInternet
          //   -1005 NSURLErrorNetworkConnectionLost
          //   -1001 NSURLErrorTimedOut  (only if it stays offline)
          if (error.errorCode == -1009 || error.errorCode == -1005) {
            crestLog(() => '[Crestway] WV net-dead ${error.errorCode}');
            _goOffline();
            return;
          }

          if (error.errorCode == -1007 &&
              _redirectAttempts < CrestConfig.redirectRetryLimit) {
            _redirectAttempts++;
            final target = _lastTopUrl ?? widget.url;
            crestLog(() =>
                '[Crestway] redirect retry $_redirectAttempts → $target');
            await _controller.loadRequest(Uri.parse(target));
            return;
          }
          crestLog(() =>
              '[Crestway] WV error code=${error.errorCode} desc=${error.description}');
        },
      );

  // Compact idempotent fix-up for WKWebView's `_blank`/`window.open` drop.
  // Runs both on onPageStarted (before user can tap) and again after
  // onPageFinished (once the DOM is stable) — the sentinel guards it.
  Future<void> _rewriteBlankTargets() async {
    if (!mounted) return;
    const snippet = r'''
(function(){
  try {
    var doc = document;
    if (!doc || !doc.documentElement) return;
    function fix(){
      var links = doc.querySelectorAll('a[target="_blank"], a[target="_new"]');
      for (var i=0;i<links.length;i++) links[i].setAttribute('target','_self');
      var forms = doc.querySelectorAll('form[target="_blank"], form[target="_new"]');
      for (var j=0;j<forms.length;j++) forms[j].setAttribute('target','_self');
    }
    fix();
    if (!window.__pFPOpen) {
      window.__pFPOpen = 1;
      try {
        window.open = function(u){
          if (u) { try { window.location.href = String(u); } catch(_){} }
          return null;
        };
      } catch(_){}
    }
    if (!window.__pFPMo && (doc.body || doc.documentElement)) {
      window.__pFPMo = 1;
      try {
        new MutationObserver(fix).observe(doc.body || doc.documentElement,
          {childList:true, subtree:true, attributes:true, attributeFilter:['target']});
      } catch(_){}
    }
  } catch(_){}
})();
''';
    try {
      await _controller.runJavaScript(snippet);
    } catch (_) {
      // Runs before DOM in some flows — safe to ignore, the next call
      // (from the other hook) will succeed.
    }
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      crestLog(() => '[Crestway] launch $uri failed: $error');
    }
  }

  Future<void> _pokeReflow() async {
    for (final delay in CrestConfig.reflowSchedule) {
      await Future<void>.delayed(Duration(milliseconds: delay));
      if (!mounted) return;
      try {
        await _controller.runJavaScript(
          "window.dispatchEvent(new Event('orientationchange'));"
          "window.dispatchEvent(new Event('resize'));",
        );
      } catch (_) {}
    }
  }

  // ── merged JS injection (single bundle, one sentinel) ────────────────
  Future<void> _installShell() async {
    // Everything the portal needs happens inside one self-contained IIFE.
    // If the site ships its own gestures, `passive:false` gives us the
    // last word on zoom + double-tap without touching the site's own
    // scrollables.
    const bundle = r'''
(function(){
  if (window.__pFP) return; window.__pFP = 1;
  var doc = document, root = doc.documentElement;
  function css(text){
    var el = doc.createElement('style');
    el.setAttribute('data-p','fp');
    el.textContent = text;
    (doc.head || root).appendChild(el);
  }
  css(
    ':root{'+
      '--safe-area-inset-top:0px!important;'+
      '--safe-area-inset-right:0px!important;'+
      '--safe-area-inset-bottom:0px!important;'+
      '--safe-area-inset-left:0px!important;'+
      '--sat:0px!important;--sar:0px!important;'+
      '--sab:0px!important;--sal:0px!important;'+
      '--safe-top:0px!important;--safe-bottom:0px!important;'+
      '--safe-left:0px!important;--safe-right:0px!important;'+
    '}'+
    '.gameview-mobile-header,.app-header,.js-safe-top{'+
      'padding-top:0!important;margin-top:0!important;'+
    '}'+
    'html,body{'+
      'overscroll-behavior:none!important;'+
      'overscroll-behavior-y:none!important;'+
      '-webkit-tap-highlight-color:transparent!important;'+
    '}'+
    'input,textarea,select{font-size:max(16px,1em)!important;}'
  );
  // Viewport lock (kills iOS pinch + double-tap without breaking site).
  var meta = doc.querySelector('meta[name=viewport]');
  if (!meta){
    meta = doc.createElement('meta');
    meta.setAttribute('name','viewport');
    (doc.head || root).appendChild(meta);
  }
  meta.setAttribute(
    'content',
    'width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover'
  );
  var block = function(e){ if(e && e.scale !== 1) e.preventDefault(); };
  doc.addEventListener('gesturestart',  block, {passive:false});
  doc.addEventListener('gesturechange', block, {passive:false});
  doc.addEventListener('gestureend',    block, {passive:false});

  // WKWebView drops target="_blank" and window.open() calls on the floor
  // (no UIDelegate wired up in the Flutter plugin), so buttons that open
  // links in a "new tab" silently do nothing.  Rewrite _blank targets and
  // reroute window.open through the same view.
  function unblankAll(){
    var links = doc.querySelectorAll('a[target="_blank"], a[target="_new"]');
    for (var i=0;i<links.length;i++) links[i].setAttribute('target','_self');
    var forms = doc.querySelectorAll('form[target="_blank"], form[target="_new"]');
    for (var j=0;j<forms.length;j++) forms[j].setAttribute('target','_self');
  }
  unblankAll();
  var linkMo = new MutationObserver(unblankAll);
  try { linkMo.observe(doc.body || root, {childList:true, subtree:true, attributes:true, attributeFilter:['target']}); } catch(_){}
  try {
    if (!window.open || !window.open.__wrapped) {
      window.open = function(u){
        if (u) { try { window.location.href = String(u); } catch(_){} }
        return null;
      };
      window.open.__wrapped = 1;
    }
  } catch(_){}
  // Focused inputs above keyboard: single guarded scroll on focusin.
  doc.addEventListener('focusin', function(e){
    var t = e.target;
    if (!t || !t.getBoundingClientRect) return;
    var tag = (t.tagName || '').toUpperCase();
    if (tag !== 'INPUT' && tag !== 'TEXTAREA' && tag !== 'SELECT') return;
    setTimeout(function(){
      try { t.scrollIntoView({block:'center', behavior:'auto'}); } catch(_){}
    }, 200);
  });
  // Autoplay inline media (kept as behaviour set in one bundle).
  function playAll(){
    var vids = doc.querySelectorAll('video');
    for (var i=0;i<vids.length;i++){
      try {
        vids[i].setAttribute('playsinline','');
        vids[i].setAttribute('webkit-playsinline','');
        vids[i].muted = vids[i].muted;
      } catch(_){}
    }
  }
  playAll();
  var mo = new MutationObserver(function(){ playAll(); });
  try { mo.observe(doc.body || root, {childList:true, subtree:true}); } catch(_){}
})();
''';
    try {
      await _controller.runJavaScript(bundle);
    } catch (error) {
      crestLog(() => '[Crestway] shell injection failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Per rule §14: back gesture walks WebView history one step; on the
    // first page it does NOTHING (must not drop the user out of the
    // portal).  Always block the pop and handle it manually.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: true,
          bottom: true,
          left: true,
          right: true,
          minimum: EdgeInsets.zero,
          child: _viewportReady
              ? WebViewWidget(controller: _controller)
              : const ColoredBox(color: Colors.black),
        ),
      ),
    );
  }
}
