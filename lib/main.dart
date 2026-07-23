import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // `publishableKey`, not `anonKey`: sb_publishable_* keys are a distinct
    // parameter and `anonKey` is deprecated in supabase_flutter 2.16.
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: TrueAnchorApp()));
}

class TrueAnchorApp extends ConsumerWidget {
  const TrueAnchorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'TrueAnchor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
