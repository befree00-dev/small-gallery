import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/providers.dart';
import '../../ui/common.dart';
import '../onboarding/onboarding_screen.dart';

/// The artist's side of the app. Sends a new account to onboarding first.
class StudioShell extends ConsumerWidget {
  const StudioShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const tabs = ['/studio', '/studio/upload', '/studio/reactions', '/studio/settings'];

  int get _index {
    for (var i = tabs.length - 1; i > 0; i--) {
      if (location.startsWith(tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(myGalleryProvider);
    return gallery.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      // A saved session can outlive the account or hit a server problem;
      // always leave a way out besides retrying.
      error: (e, _) => Scaffold(
        body: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AsyncBody(value: gallery, builder: (_) => const SizedBox(), onRetry: () => ref.invalidate(myGalleryProvider)),
          TextButton(
            onPressed: () async {
              await ref.read(repositoryProvider).signOut();
              ref.invalidate(myGalleryProvider);
            },
            child: Text(context.l10n.signOut),
          ),
        ]),
      ),
      data: (g) => g == null ? const OnboardingScreen() : _scaffold(context, ref),
    );
  }

  Widget _scaffold(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final unread = ref.watch(notificationsProvider).value?.where((n) => n.isUnread).length ?? 0;
    final items = [
      (Icons.grid_view_outlined, Icons.grid_view, l10n.tabGallery),
      (Icons.add_photo_alternate_outlined, Icons.add_photo_alternate, l10n.tabUpload),
      (Icons.notifications_none, Icons.notifications, l10n.tabReactions),
      (Icons.person_outline, Icons.person, l10n.tabSettings),
    ];
    Widget icon(int i, bool selected) {
      final base = Icon(selected ? items[i].$2 : items[i].$1);
      return i == 2 && unread > 0 ? Badge.count(count: unread, child: base) : base;
    }

    void go(int i) => context.go(tabs[i]);

    if (isWide(context)) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (var i = 0; i < items.length; i++)
                NavigationRailDestination(icon: icon(i, false), selectedIcon: icon(i, true), label: Text(items[i].$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: go,
        destinations: [
          for (var i = 0; i < items.length; i++)
            NavigationDestination(icon: icon(i, false), selectedIcon: icon(i, true), label: items[i].$3),
        ],
      ),
    );
  }
}
