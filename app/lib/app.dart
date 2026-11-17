import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'features/auth/welcome_screen.dart';
import 'features/studio/reactions_screen.dart';
import 'features/studio/room_screen.dart';
import 'features/studio/settings_screen.dart';
import 'features/studio/studio_home_screen.dart';
import 'features/studio/studio_shell.dart';
import 'features/studio/upload_screen.dart';
import 'features/visitor/artwork_screen.dart';
import 'features/visitor/gallery_screen.dart';
import 'l10n/app_localizations.dart';
import 'state/providers.dart';
import 'theme.dart';

/// Re-runs the router's redirect whenever someone signs in or out.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Stream<String?> changes) {
    _sub = changes.listen((_) => notifyListeners());
  }

  late final StreamSubscription<String?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(repositoryProvider);
  final auth = _AuthListenable(repo.userChanges);
  ref.onDispose(auth.dispose);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final signedIn = repo.currentUserId != null;
      final path = state.matchedLocation;
      if (path == '/') return signedIn ? '/studio' : '/welcome';
      if (path.startsWith('/studio') && !signedIn) return '/welcome';
      if (path == '/welcome' && signedIn) return '/studio';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      ShellRoute(
        builder: (context, state, child) => StudioShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/studio', builder: (_, _) => const StudioHomeScreen()),
          GoRoute(
            path: '/studio/rooms/:roomId',
            builder: (_, s) => RoomScreen(roomId: s.pathParameters['roomId']!),
          ),
          GoRoute(path: '/studio/upload', builder: (_, _) => const UploadScreen()),
          GoRoute(path: '/studio/reactions', builder: (_, _) => const ReactionsScreen()),
          GoRoute(path: '/studio/settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: '/g/:handle',
        builder: (_, s) => GalleryScreen(handle: s.pathParameters['handle']!),
        routes: [
          GoRoute(
            path: 'a/:artworkId',
            builder: (_, s) =>
                ArtworkScreen(handle: s.pathParameters['handle']!, artworkId: s.pathParameters['artworkId']!),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class SmallGalleryApp extends ConsumerWidget {
  const SmallGalleryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Small Gallery',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
