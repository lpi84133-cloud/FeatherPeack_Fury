import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_info.dart';
import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../shared/widgets/fp_screen.dart';

enum LegalPage {
  privacy(
    'Privacy Policy',
    AppInfo.privacyAsset,
    AppInfo.privacyPolicyUrl,
    'What the app stores and what it never collects',
  ),
  support(
    'Support',
    AppInfo.supportAsset,
    AppInfo.supportUrl,
    'Guides, common questions and how to reach us',
  ),
  faq(
    'How the calculations work',
    AppInfo.faqAsset,
    null,
    'Every formula the app uses, in full',
  );

  const LegalPage(this.title, this.asset, this.url, this.subtitle);

  final String title;
  final String asset;

  /// The published web address, when there is one. The FAQ lives only inside
  /// the app, so it has none.
  final String? url;
  final String subtitle;
}

/// Legal and help pages. The content shipped inside the app is the source that
/// is displayed, so these pages open instantly and read identically with no
/// connection. Text is locked to black on white for legibility.
class LegalScreen extends StatefulWidget {
  const LegalScreen({required this.page, super.key});

  final LegalPage page;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // The support page uses a small script for its contact form, so scripts
      // are allowed. All content is bundled and loaded from memory.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(FpColors.legalSurface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          // Let the page itself render (about:blank / data loads) but refuse any
          // attempt to leave for an external http(s) address. Returning prevent
          // for everything — as before — also blocked the initial paint and left
          // a blank white screen.
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    try {
      final html = await rootBundle.loadString(widget.page.asset);
      if (!mounted) return;
      await _controller.loadHtmlString(html, baseUrl: 'about:blank');
      // loadHtmlString renders from memory instantly; clear the spinner even if
      // onPageFinished is slow to fire on some devices.
      if (mounted) setState(() => _loading = false);
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _copyUrl() async {
    final url = widget.page.url;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    FpFeedback.instance.success(FpSound.successfulAction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Web address copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FpScreen(
      title: widget.page.title,
      subtitle: widget.page.subtitle,
      padding: EdgeInsets.zero,
      actions: [
        if (widget.page.url != null)
          FpRoundButton(
            icon: Icons.link_rounded,
            tooltip: 'Copy web address',
            onPressed: _copyUrl,
          ),
      ],
      child: Container(
        color: FpColors.legalSurface,
        child: Stack(
          children: [
            if (_failed)
              Padding(
                padding: const EdgeInsets.all(FpSpace.lg),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 40,
                        color: FpColors.graphiteSoft,
                      ),
                      const SizedBox(height: FpSpace.sm),
                      Text(
                        widget.page.url == null
                            ? 'This page could not be rendered on this device.'
                            : 'This page could not be rendered on this device. '
                                  'The full text is published at '
                                  '${widget.page.url}.',
                        style: FpTypography.body.copyWith(
                          color: FpColors.legalText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (widget.page.url != null) ...[
                        const SizedBox(height: FpSpace.md),
                        OutlinedButton.icon(
                          onPressed: _copyUrl,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy web address'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              WebViewWidget(controller: _controller),
            if (_loading && !_failed)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: FpColors.forest,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
