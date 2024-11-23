import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart'
    as desktop_webview;
import 'package:webview_flutter/webview_flutter.dart';

class OAuthWebview extends StatefulWidget {
  final String authUrl;
  final String redirectUrl;
  final String title;
  final bool clearSession;

  const OAuthWebview({
    super.key,
    required this.authUrl,
    required this.redirectUrl,
    required this.title,
    required this.clearSession,
  });

  @override
  State<OAuthWebview> createState() => _WebviewDialogState();

  static Future<String> fireOAuth(
      BuildContext context, String title, String authUrl, String redirectUrl,
      [bool clearSession = false]) async {
    final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    final mobile = Platform.isAndroid || Platform.isIOS;

    if (desktop) {
      if (clearSession) {
        await desktop_webview.WebviewWindow.clearAll();
      }
      final config = desktop_webview.CreateConfiguration(
        title: title,
        titleBarHeight: 0,
      );
      final webview = await desktop_webview.WebviewWindow.create(
        configuration: config,
      );
      final completer = Completer<String>();
      webview.addOnUrlRequestCallback((url) {
        if (url.startsWith(redirectUrl)) completer.complete(url);
      });
      webview.onClose.then((_) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Webview closed'));
        }
      });
      webview.launch(authUrl);
      final result = await completer.future;
      webview.close();
      return result;
    } else if (mobile) {
      final String? url = await showDialog(
        context: context,
        builder: (_) => Dialog.fullscreen(
          child: OAuthWebview(
            clearSession: clearSession,
            title: title,
            authUrl: authUrl,
            redirectUrl: redirectUrl,
          ),
        ),
      );

      if (url == null) throw Exception('Cancelled');
      return url;
    }

    throw UnimplementedError();
  }
}

class _WebviewDialogState extends State<OAuthWebview> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
          NavigationDelegate(onNavigationRequest: (request) {
        if (request.url.startsWith(widget.redirectUrl)) {
          Navigator.of(context).pop(request.url);
          return NavigationDecision.prevent;
        }

        return NavigationDecision.navigate;
      }));
    if (widget.clearSession) {
      WebViewCookieManager().clearCookies().then((_) async {
        await controller.clearCache();
        controller.loadRequest(Uri.parse(widget.authUrl));
      });
    } else {
      controller.loadRequest(Uri.parse(widget.authUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: controller),
    );
  }
}
