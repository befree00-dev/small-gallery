import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/supabase_repository.dart';
import 'state/providers.dart';

/// Pass these at build time:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Where OAuth sign-in returns to. Registered per platform (see README).
const oauthRedirect = 'app.smallgallery://login-callback';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(
        SupabaseGalleryRepository(Supabase.instance.client, prefs, oauthRedirect: oauthRedirect),
      ),
    ],
    child: const SmallGalleryApp(),
  ));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'SUPABASE_URL and SUPABASE_ANON_KEY are not set.\n'
                'Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
