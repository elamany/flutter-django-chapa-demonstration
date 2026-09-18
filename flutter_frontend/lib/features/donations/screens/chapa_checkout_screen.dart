import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:frontend_flutter/features/donations/widgets/loading_animation_in_webview.dart';

import '../../../core/api/dio_client.dart';


class ChapaCheckoutScreen extends StatefulWidget {
  const ChapaCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.txRef,
  });

  final String checkoutUrl;
  final String txRef;

  @override
  State<ChapaCheckoutScreen> createState() => _ChapaCheckoutScreenState();
}

class _ChapaCheckoutScreenState extends State<ChapaCheckoutScreen> {
  bool _resultSent = false;
  double _progress = 0;

  Timer? _fallbackPollTimer;
  Timer? _fastPollTimer;
  int _fallbackAttempts = 0;
  int _fastPollAttempts = 0;

  static const _returnMarker = '/payments/return/';

  // Slow safety net — 30s intervals, 12 attempts = 6 minutes total. (in case the return URL never fires at all).
  static const _fallbackInterval = Duration(seconds: 30);
  static const _maxFallbackAttempts = 12; // 2 minutes

  // Fast poll — starts only after the return URL fires.
  static const _fastInterval = Duration(seconds: 1);
  static const _maxFastAttempts = 15; // 15 seconds max

  @override
  void initState() {
    super.initState();
    CookieManager.instance().deleteAllCookies();
  }

  @override
  void dispose() {
    _fallbackPollTimer?.cancel();
    _fastPollTimer?.cancel();
    CookieManager.instance().deleteAllCookies();
    super.dispose();
  }

  void _onProgress(int progress) {
    final value = progress / 100.0;
    if (value == _progress) return;
    setState(() => _progress = value);
  }

  /// Detect the return URL — this is the signal that Chapa has finished
  /// and the browser is now navigating to our Django endpoint.
  ///
  /// Do NOT pop immediately: Django is still processing the verification
  /// in the same moment. Start a fast poll instead.
  void _checkUrl(String url) {
    if (_resultSent) return;
    if (!url.contains(_returnMarker)) return;

    debugPrint('CHAPA: return URL detected — starting fast poll');
    _startFastPolling();
  }

  /// Fast poll — 1s interval, up to 15 attempts. Only runs after we see
  /// the return URL. Backend verify typically completes in 1–3 seconds.
  void _startFastPolling() {
    if (_fastPollTimer != null) return;

    _fastPollTimer = Timer.periodic(_fastInterval, (_) async {
      if (_resultSent) {
        _fastPollTimer?.cancel();
        return;
      }

      _fastPollAttempts++;

      // Timeout — take whatever the backend has and stop.
      if (_fastPollAttempts > _maxFastAttempts) {
        debugPrint('CHAPA: fast poll gave up after '
            '$_maxFastAttempts attempts');
        _fastPollTimer?.cancel();
        _finish('PENDING');
        return;
      }

      try {
        final res = await DioClient.instance.get(
          'payments/verify/${widget.txRef}/',
        );
        final body = res.data as Map<String, dynamic>;
        final status = (body['data']?['status'] ?? '') as String;

        debugPrint('CHAPA_FAST: attempt=$_fastPollAttempts status=$status');

        if (status == 'SUCCESS' || status == 'FAILED') {
          _finish(status);
        }
      } catch (e) {
        debugPrint('CHAPA_FAST: error $e');
      }
    });
  }

  /// Slow safety net — only useful if the return URL never fires.
  void _startFallbackPolling() {
    if (_fallbackPollTimer != null) return;
    if (_fastPollTimer != null) return;

    _fallbackPollTimer = Timer.periodic(_fallbackInterval, (_) async {
      if (_resultSent) {
        _fallbackPollTimer?.cancel();
        return;
      }

      _fallbackAttempts++;

      // Timeout — do one last verify before giving up.
      if (_fallbackAttempts > _maxFallbackAttempts) {
        _fallbackPollTimer?.cancel();
        await _onTimeout();
        return;
      }

      try {
        final res = await DioClient.instance.get(
          'payments/status/${widget.txRef}/',
        );
        final body = res.data as Map<String, dynamic>;
        final status = (body['data']?['status'] ?? '') as String;

        debugPrint('CHAPA_FALLBACK: attempt=$_fallbackAttempts status=$status');

        if (status == 'SUCCESS' || status == 'FAILED') {
          _finish(status);
        }
      } catch (e) {
        debugPrint('CHAPA_FALLBACK: error $e');
      }
    });
  }

  /// Called when the 6-minute fallback window expires.
  ///
  /// We do NOT blindly mark the donation as failed — the user might have
  /// paid and Chapa just hasn't told us yet. Instead we ask Chapa once
  /// more and let it decide.
  Future<void> _onTimeout() async {
    debugPrint('CHAPA: 6-minute timeout — final verify');

    try {
      final res = await DioClient.instance.get(
        'payments/verify/${widget.txRef}/',
      );
      final body = res.data as Map<String, dynamic>;
      final status = (body['data']?['status'] ?? '') as String;

      debugPrint('CHAPA_TIMEOUT_VERIFY: status=$status');

      if (status == 'SUCCESS') {
        _finish('SUCCESS');
        return;
      }
      if (status == 'FAILED') {
        _finish('FAILED');
        return;
      }
    } catch (e) {
      debugPrint('CHAPA_TIMEOUT_VERIFY: error $e');
    }

    // Chapa still says PENDING — we don't know. Close with a special
    // status so the parent screen shows the right message.
    _finish('paymentTimeout');
  }

  void _finish(String status) {
    if (_resultSent) return;
    _resultSent = true;
    _fallbackPollTimer?.cancel();
    _fastPollTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop(status);
  }

  bool get _isLoading => _progress < 0.95;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => _finish('paymentCancelled'),
        ),
        title: const Text('Checkout'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 3,
            child: _isLoading ? const WebviewLoaderAnimation() : null,
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri(widget.checkoutUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                cacheEnabled: false,
                clearCache: true,
                useShouldOverrideUrlLoading: true,
              ),
              onProgressChanged: (controller, progress) {
                _onProgress(progress);
              },
              onLoadStart: (controller, url) {
                setState(() => _progress = 0);
                if (url != null) _checkUrl(url.toString());
              },
              onLoadStop: (controller, url) {
                if (url != null) _checkUrl(url.toString());
                _startFallbackPolling();
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url =
                    navigationAction.request.url?.toString() ?? '';
                _checkUrl(url);
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
        ],
      ),
    );
  }
}