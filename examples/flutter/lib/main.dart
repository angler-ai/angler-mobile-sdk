import 'dart:async';

import 'package:angler_analytics/angler_analytics.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

// Dev workspace credentials. Use your own; never commit a real token.
const workspaceId = 'example-workspace';
const token = 'replace-me';

Future<void> main() async {
  // The method channel needs the binding before Angler.configure.
  WidgetsFlutterBinding.ensureInitialized();
  await Angler.configure(const AnglerConfiguration(
    workspaceId: workspaceId,
    token: token,
    domain: 'dev-data.getangler.ai',
    debugLogging: true,
  ));

  // Flutter has no built-in deep-link API: forward the launch link and later links.
  final appLinks = AppLinks();
  final initial = await appLinks.getInitialLink();
  if (initial != null) await Angler.handleDeepLink(initial.toString());
  appLinks.uriLinkStream.listen((uri) => Angler.handleDeepLink(uri.toString()));

  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'Ready';

  void _run(String label, Future<void> Function() action) {
    action();
    setState(() => _status = label);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Angler Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Angler Example')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => _run(
                  'Tracked product_viewed',
                  () => Angler.track(
                    AnglerEvent.productViewed,
                    data: const AnglerData(
                      productVariant: AnglerProductVariant(
                        id: 'variant-1',
                        title: 'Example',
                        price: AnglerMoney(amount: 29, currencyCode: 'USD'),
                      ),
                    ),
                  ),
                ),
                child: const Text('Track product_viewed'),
              ),
              ElevatedButton(
                onPressed: () => _run('Tracked level_up', () => Angler.track(const AnglerEvent.custom('level_up'), properties: {'level': '2'})),
                child: const Text('Track custom (level_up)'),
              ),
              ElevatedButton(
                onPressed: () => _run(
                  'Captured gclid',
                  () => Angler.handleDeepLink('anglerexample://product/1?gclid=example-gclid'),
                ),
                child: const Text('Open deep link (gclid)'),
              ),
              ElevatedButton(onPressed: () => _run('Flushing', Angler.flush), child: const Text('Flush')),
              ElevatedButton(onPressed: () => _run('Reset', Angler.reset), child: const Text('Reset')),
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
