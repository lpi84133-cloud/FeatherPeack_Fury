import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/crest_config.dart';
import '../keep/boot_log.dart';

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
  DateTime? _lastReflow;

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
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
        onNavigationRequest: (request) async {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          switch (uri.scheme) {
            case 'http':
            case 'https':
            case 'about':
            case 'data':
            case 'blob':
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
        onPageStarted: (_) {
          _redirectAttempts = 0;
        },
        onPageFinished: (_) async {
          await _installShell();
          if (mounted) setState(() {});
          // Post-load resize kick + one reload for the cold-start branch
          // (`cold_start_push_viewport.mdc` §Layer 4).
          Future.delayed(CrestConfig.postFinishedResizeDelay, () async {
            if (!mounted) return;
            await _controller.runJavaScript(
              "window.dispatchEvent(new Event('resize'));",
            );
            if (widget.coldStartPush) {
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
          if (error.errorCode == -1007 &&
              _redirectAttempts < CrestConfig.redirectRetryLimit) {
            _redirectAttempts++;
            crestLog(() => '[Crestway] redirect retry $_redirectAttempts');
            await _controller.loadRequest(Uri.parse(widget.url));
            return;
          }
          crestLog(() =>
              '[Crestway] WV error code=${error.errorCode} desc=${error.description}');
        },
      );

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
  var lastTap = 0;
  doc.addEventListener('touchend', function(e){
    var now = Date.now();
    if (now - lastTap < 300) e.preventDefault();
    lastTap = now;
  }, {passive:false});
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
