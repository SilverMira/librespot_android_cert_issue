import 'package:flutter/material.dart';
import 'package:frb_base/src/rust/api/simple.dart';
import 'package:frb_base/src/rust/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

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
        body: Center(
          child: Column(children: [
            TextField(
              controller: accessToken,
              decoration: const InputDecoration(labelText: 'Access token'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: trackId,
              decoration: const InputDecoration(labelText: 'Track ID'),
            ),
            if (player == null) ...[
              const SizedBox(height: 8),
              Builder(builder: (context) {
                return ElevatedButton(
                  onPressed: isInitializing
                      ? null
                      : () async {
                          try {
                            setState(() => isInitializing = true);
                            final player = await LibrespotPlayer.newInstance(
                              accessToken: accessToken.text,
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
          ]),
        ),
      ),
    );
  }
}
