import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/supabase_repository.dart';
import 'state/providers.dart';
import 'ui/common.dart' show siteUrl;

/// Pass these at build time:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Where OAuth sign-in returns to. Registered per platform (see README).
const oauthRedirect = 'app.smallgallery://login-callback';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final problem = configProblem(url: supabaseUrl, key: supabaseAnonKey, site: siteUrl);
  if (problem != null) {
    runApp(_MissingConfigApp(problem));
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

/// What is wrong with the build-time settings, or null when they look usable.
/// Catches leftovers from pasting into the example command (e.g. "여sb_…").
String? configProblem({required String url, required String key, required String site}) {
  if (url.isEmpty || key.isEmpty) {
    return 'SUPABASE_URL and SUPABASE_ANON_KEY are not set.\n'
        'Run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...';
  }
  final parsed = Uri.tryParse(url);
  if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
    return 'SUPABASE_URL is not a valid https address: "$url"';
  }
  if (!RegExp(r'^[A-Za-z0-9._\-]+$').hasMatch(key)) {
    return 'SUPABASE_ANON_KEY contains characters a key cannot have: "$key"\n'
        'It should start with sb_publishable_ (or eyJ for older keys), with nothing before it.';
  }
  final siteUri = Uri.tryParse(site);
  final host = siteUri?.host ?? '';
  final realHost = host == 'localhost' || RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(host);
  if (siteUri == null || !siteUri.hasScheme || !realHost) {
    return 'SITE_URL is not a valid address: "$site"';
  }
  return null;
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp(this.problem);

  final String problem;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(problem, textAlign: TextAlign.center),
            ),
          ),
        ),
      );
}
