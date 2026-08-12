import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// How the parent left the Stripe Checkout flow.
///
/// The server-side webhook is the real source of truth for activation, so even
/// on [success] the caller should re-fetch `/subscriptions/my` before claiming
/// the plan is live. [returned] means we detected the page leave Stripe but
/// couldn't tell success from cancel — refresh and decide from the result.
enum CheckoutResult { success, canceled, returned, closed }

/// In-app Stripe Checkout. Loads the hosted checkout URL and watches for the
/// redirect back to Stripe's success/cancel URLs to close itself with a result.
class CheckoutWebView extends StatefulWidget {
  final String url;
  final String planName;

  const CheckoutWebView({super.key, required this.url, required this.planName});

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false; // guards against popping twice
  bool _loadFailed = false; // main-frame load error → show fallback

  /// Stripe Checkout serves a blank/degraded page to WebView user-agents it
  /// doesn't recognise, which is why the hosted URL renders in a real browser
  /// but not inside a bare WebView. Presenting a normal mobile Safari UA makes
  /// Stripe treat us like any other browser.
  static const _browserUa =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
      'Mobile/15E148 Safari/604.1';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_browserUa)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (_) {},
          onPageStarted: (url) {
            _maybeFinish(url);
            if (mounted && !_finished) {
              setState(() {
                _loading = true;
                _loadFailed = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Only the main document failing is fatal; sub-resource errors
            // (an image, a beacon) are noise and must not blank the flow.
            if (error.isForMainFrame != true) return;
            debugPrint(
              '❌ Checkout WebView error [${error.errorCode}] '
              '${error.description}',
            );
            if (mounted && !_finished) {
              setState(() {
                _loading = false;
                _loadFailed = true;
              });
            }
          },
          onNavigationRequest: (request) {
            // Sub-frames are never the parent leaving checkout. Stripe
            // Checkout boots several frames on hosts that are not
            // `stripe.com` — `m.stripe.network` (Radar's fraud signals),
            // `link.com` (Link), the wallet buttons — and on iOS the
            // navigation delegate is called for those too (Android filters
            // them out, which is why this only ever bit one platform).
            // Reading one as "left Stripe" is what closed checkout by itself
            // a second after it opened, before any card details were typed.
            if (!request.isMainFrame) return NavigationDecision.navigate;
            final result = _classify(request.url);
            if (result != null) {
              _finish(result, url: request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Escape hatch: hand the exact checkout URL to the system browser, which
  /// always renders Stripe correctly. We close with [returned] so the caller
  /// re-reads `/subscriptions/my` (the webhook is the real source of truth)
  /// once the parent comes back.
  Future<void> _openExternally() async {
    debugPrint('🌐 Checkout: opening EXTERNAL browser → ${widget.url}');
    final uri = Uri.parse(widget.url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    debugPrint('🌐 Checkout: external browser launched → $launched');
    if (launched) _finish(CheckoutResult.returned);
  }

  /// Hosts that belong to the checkout flow itself, so landing on one never
  /// means the parent left it. Stripe's own pages are only part of the list:
  /// Checkout also hands off to Link, Google Pay and Apple Pay, and its fraud
  /// signals load from `stripe.network` — a domain the old `stripe.com` test
  /// missed entirely.
  static const _checkoutHosts = <String>[
    'stripe.com',
    'stripe.network',
    'link.com',
    'pay.google.com',
    'apple.com',
  ];

  static bool _isCheckoutHost(String host) =>
      _checkoutHosts.any((h) => host == h || host.endsWith('.$h'));

  /// Maps a URL to a checkout outcome, or null if it's a normal in-flow page.
  ///
  /// Stripe's own pages live on `checkout.stripe.com`; the success/cancel
  /// redirects point back at our own return URLs. We key off the standard
  /// `success` / `cancel` markers the backend puts in those URLs, and treat any
  /// other departure from the flow as an ambiguous [returned].
  CheckoutResult? _classify(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Only a real page load can be a return URL. `about:blank` (Stripe opens
    // one for its wallet popups), `data:`, `intent:` and bank app-scheme
    // links are all part of paying, not the end of it.
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return null;

    final host = uri.host.toLowerCase();
    if (_isCheckoutHost(host)) return null; // still inside the checkout flow

    final lower = url.toLowerCase();
    // Success is tested first: a success return URL routinely carries the
    // cancel URL along as a query parameter, and matching 'cancel' there
    // would report a completed payment as abandoned.
    if (lower.contains('success') ||
        lower.contains('paid') ||
        lower.contains('complete')) {
      return CheckoutResult.success;
    }
    if (lower.contains('cancel')) return CheckoutResult.canceled;
    // Left the flow for somewhere we didn't tag — let the caller reconcile.
    return CheckoutResult.returned;
  }

  void _maybeFinish(String url) {
    final result = _classify(url);
    if (result != null) _finish(result, url: url);
  }

  void _finish(CheckoutResult result, {String? url}) {
    if (_finished || !mounted) return;
    _finished = true;
    debugPrint(
      '🧾 Checkout: finishing as $result${url == null ? '' : ' ← $url'}',
    );
    Navigator.of(context).pop(result);
  }

  Future<void> _confirmClose() async {
    if (_finished) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'Your payment is not complete. Do you want to leave checkout?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted && !_finished) {
      _finished = true;
      Navigator.of(context).pop(CheckoutResult.closed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            onPressed: _confirmClose,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure Checkout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 11,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Powered by Stripe',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Always-available escape hatch to the system browser.
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: _openExternally,
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loadFailed)
              _CheckoutErrorFallback(onOpenBrowser: _openExternally)
            else if (_loading)
              const ColoredBox(
                color: AppColors.surface,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the hosted checkout page fails to render inside the WebView,
/// pointing the parent at the system browser where it always works.
class _CheckoutErrorFallback extends StatelessWidget {
  final VoidCallback onOpenBrowser;

  const _CheckoutErrorFallback({required this.onOpenBrowser});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.public_off_rounded,
                size: 52,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Couldn\'t load checkout',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open the secure Stripe page in your browser to finish paying.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onOpenBrowser,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Open in browser',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
