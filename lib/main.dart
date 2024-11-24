import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frb_base/src/oauth.dart';
import 'package:frb_base/src/rust/api/simple.dart';
import 'package:frb_base/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(MyApp(preferences: prefs));
}

class MyApp extends StatefulWidget {
  final SharedPreferences preferences;

  const MyApp({super.key, required this.preferences});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final TextEditingController accessToken;
  late final TextEditingController trackId;
  LibrespotPlayer? player;
  bool isInitializing = false;

  @override
  void initState() {
    super.initState();
    accessToken = TextEditingController();
    trackId = TextEditingController();
  }

  @override
  void dispose() {
    accessToken.dispose();
    trackId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: SingleChildScrollView(
            child: PlayerControls(preferences: widget.preferences)),
      ),
    );
  }
}

class PlayerControls extends StatefulWidget {
  final SharedPreferences preferences;

  const PlayerControls({super.key, required this.preferences});

  @override
  State<PlayerControls> createState() => _PlayerControlsState();
}

const kPrefsToken = "token";
const kPrefsLogin5 = "token_l5";

class _PlayerControlsState extends State<PlayerControls> {
  late final String? storedToken;
  late PkceOAuthSession oauth;
  late Future<String?> accessToken;
  late final TextEditingController trackId;
  late final TextEditingController login5Id;
  late final TextEditingController login5Password;
  bool clearSession = false;
  LibrespotPlayer? player;
  bool isInitializing = false;

  @override
  void initState() {
    super.initState();
    storedToken = widget.preferences.getString(kPrefsToken);
    oauth = getSession(storedToken);
    accessToken = oauth.accessToken();
    trackId = TextEditingController();
    login5Id = TextEditingController();
    login5Password = TextEditingController();
  }

  @override
  void dispose() {
    player?.dispose();
    trackId.dispose();
    login5Id.dispose();
    login5Password.dispose();
    super.dispose();
  }

  static PkceOAuthSession getSession(String? token) {
    if (token != null) {
      try {
        return PkceOAuthSession.fromTokenJson(token: token);
      } catch (err, stackTrace) {
        debugPrint("Could not instantiate oauth session from token");
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return PkceOAuthSession();
  }

  @override
  Widget build(BuildContext context) {
    final controls = Wrap(
      children: [
        ElevatedButton(
          onPressed: () {
            final newSession = getSession(null);
            setState(() {
              oauth = newSession;
              accessToken = oauth.accessToken();
            });
          },
          child: const Text("New session"),
        ),
        const SizedBox(width: 8),
        FutureBuilder(
          future: accessToken,
          builder: (context, snapshot) {
            final done = snapshot.connectionState == ConnectionState.done;
            if (!done) {
              return const ElevatedButton(
                onPressed: null,
                child: Text('Loading'),
              );
            }

            final isLoggedIn = snapshot.data != null;
            return ElevatedButton(
              onPressed: isLoggedIn
                  ? () async {
                      setState(() {
                        accessToken = oauth.refreshToken();
                      });
                    }
                  : () async {
                      final authUrls = oauth.authUrl();
                      final callbackUrl = await OAuthWebview.fireOAuth(
                        context,
                        "Login to spotify",
                        authUrls.authUrl,
                        authUrls.redirectUrl,
                        clearSession,
                      );
                      final parseUrl = Uri.parse(callbackUrl);
                      final code = parseUrl.queryParameters['code'];
                      if (code != null) {
                        await oauth.callback(code: code);
                        setState(() {
                          accessToken = oauth.accessToken().then((token) async {
                            if (token != null) {
                              final tokenJson = await oauth.tokenJson();
                              if (tokenJson != null) {
                                await widget.preferences
                                    .setString(kPrefsToken, tokenJson);
                              }
                            }
                            return token;
                          });
                        });
                      }
                    },
              child: isLoggedIn ? const Text('Refresh') : const Text('Login'),
            );
          },
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          controls,
          const SizedBox(height: 8.0),
          CheckboxListTile(
            value: clearSession,
            onChanged: (value) {
              setState(() {
                clearSession = value ?? false;
              });
            },
            title: const Text("Clear webview session"),
          ),
          const SizedBox(height: 8),
          FutureBuilder(
            future: accessToken,
            builder: (context, snapshot) {
              final accessTokenValue =
                  snapshot.connectionState != ConnectionState.done
                      ? 'loading'
                      : snapshot.hasError
                          ? 'error: ${snapshot.error}'
                          : snapshot.data;

              return Column(
                children: [
                  TextFormField(
                    key:
                        accessTokenValue != null ? Key(accessTokenValue) : null,
                    decoration:
                        const InputDecoration(labelText: 'Access token'),
                    initialValue: accessTokenValue,
                    readOnly: true,
                  ),
                  if (Platform.isAndroid || Platform.isIOS) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: login5Id,
                      decoration: const InputDecoration(labelText: 'Login5 ID'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: login5Password,
                      decoration:
                          const InputDecoration(labelText: 'Login5 Password'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: trackId,
                    decoration: const InputDecoration(labelText: 'Track ID'),
                  ),
                  const SizedBox(height: 8),
                  if (player == null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        Builder(builder: (context) {
                          return ElevatedButton(
                            onPressed: isInitializing ||
                                    accessTokenValue == null
                                ? null
                                : () async {
                                    try {
                                      setState(() => isInitializing = true);
                                      final player =
                                          await LibrespotPlayer.newInstance(
                                        accessToken: accessTokenValue,
                                        trackId: trackId.text,
                                      );

                                      setState(() => this.player = player);
                                    } catch (error, stack) {
                                      if (!context.mounted) rethrow;

                                      await showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: const Text('Error'),
                                            content: SingleChildScrollView(
                                              child: SelectableText(
                                                "Error: $error\n\nStack: $stack",
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    } finally {
                                      setState(() => isInitializing = false);
                                    }
                                  },
                            child: const Text('Create'),
                          );
                        }),
                        ListenableBuilder(
                            listenable: Listenable.merge([
                              login5Id,
                              login5Password,
                            ]),
                            builder: (context, _) {
                              return ElevatedButton(
                                onPressed: isInitializing ||
                                        login5Id.text == "" ||
                                        login5Password.text == ""
                                    ? null
                                    : () async {
                                        try {
                                          setState(() => isInitializing = true);
                                          final player = await LibrespotPlayer
                                              .newWithLogin5(
                                            id: login5Id.text,
                                            password: login5Password.text,
                                            trackId: trackId.text,
                                          );

                                          setState(() => this.player = player);
                                        } catch (error, stack) {
                                          if (!context.mounted) rethrow;

                                          await showDialog(
                                            context: context,
                                            builder: (context) {
                                              return AlertDialog(
                                                title: const Text('Error'),
                                                content: SingleChildScrollView(
                                                  child: SelectableText(
                                                    "Error: $error\n\nStack: $stack",
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        } finally {
                                          setState(
                                              () => isInitializing = false);
                                        }
                                      },
                                child: const Text('Create with Login5'),
                              );
                            }),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        player!.play();
                      },
                      child: const Text('Play'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        player!.pause();
                      },
                      child: const Text('Pause'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
