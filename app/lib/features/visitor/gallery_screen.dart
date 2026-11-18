import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';
import 'comments_section.dart';
import 'gallery_layouts.dart';

/// A gallery as visitors see it: cover, rooms, works, guestbook.
class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key, required this.handle});

  final String handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(galleryByHandleProvider(handle));
    return gallery.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: AsyncBody(
          value: gallery,
          builder: (_) => const SizedBox(),
          onRetry: () => ref.invalidate(galleryByHandleProvider(handle)),
        ),
      ),
      data: (g) => g == null
          ? Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.l10n.galleryNotFound)),
            )
          : _GalleryView(gallery: g),
    );
  }
}

class _GalleryView extends ConsumerStatefulWidget {
  const _GalleryView({required this.gallery});

  final Gallery gallery;

  @override
  ConsumerState<_GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends ConsumerState<_GalleryView> {
  String? _roomId;

  @override
  void initState() {
    super.initState();
    ref.read(repositoryProvider).recordView(widget.gallery.id).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.lang;
    final g = widget.gallery;
    final colors = galleryColors(g.theme);
    final rooms = ref.watch(roomsProvider(g.id)).value ?? const <Room>[];
    final room = rooms.where((r) => r.id == _roomId).firstOrNull ?? rooms.firstOrNull;
    final works = room == null ? null : ref.watch(artworksProvider(room.id));
    final cardColor = switch (g.theme) {
      GalleryTheme.dark => Palette.darkSurface,
      GalleryTheme.salon => const Color(0xFF26362E),
      GalleryTheme.editorial => const Color(0xFFFBF8F2),
      _ => Palette.surface,
    };

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
        title: Text('$siteHost/@${g.handle}', style: TextStyle(fontSize: 13, color: colors.muted)),
        actions: [
          TextButton(
            onPressed: () => ref.read(localeProvider.notifier).set(Locale(lang == 'ko' ? 'en' : 'ko')),
            child: Text(lang == 'ko' ? 'EN' : 'KO', style: TextStyle(color: colors.ink)),
          ),
          IconButton(
            tooltip: l10n.shareGallery,
            icon: Icon(Icons.ios_share, color: colors.ink),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: publicGalleryUrl(g.handle)));
              if (context.mounted) context.toast(l10n.linkCopied);
            },
          ),
        ],
      ),
      body: _laidOut.contains(g.theme)
          ? _themedBody(context, g, colors.ink, colors.muted, cardColor)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      sliver: SliverList.list(
                        children: [
                          Text(
                            g.ownerName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.ink),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            localized(g.title, g.titleEn, lang),
                            style: serifTitle.copyWith(fontSize: 28, color: colors.ink),
                          ),
                          if (localized(g.bio, g.bioEn, lang).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(localized(g.bio, g.bioEn, lang), style: TextStyle(height: 1.6, color: colors.ink)),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            l10n.galleryStats(rooms.fold(0, (s, r) => s + r.artworkCount), rooms.length),
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final r in rooms)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text('${localized(r.title, r.titleEn, lang)} · ${r.artworkCount}'),
                                      selected: r.id == room?.id,
                                      onSelected: (_) => setState(() => _roomId = r.id),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (room != null && localized(room.statement, room.statementEn, lang).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                localized(room.statement, room.statementEn, lang),
                                style: TextStyle(fontSize: 13, height: 1.6, color: colors.muted),
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    if (works != null)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: AsyncBody(
                            value: works,
                            builder: (list) => _Masonry(
                              artworks: list,
                              columns: MediaQuery.sizeOf(context).width >= 900 ? 3 : 2,
                              ink: colors.ink,
                              muted: colors.muted,
                              onTap: (a) => context.push('/g/${g.handle}/a/${a.id}'),
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                      sliver: SliverToBoxAdapter(
                        child: CommentsSection(gallery: g, ink: colors.ink, muted: colors.muted, card: cardColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static const _laidOut = {GalleryTheme.feed, GalleryTheme.salon, GalleryTheme.editorial};

  /// Feed, salon and editorial show every room at once, laid out like the web gallery.
  Widget _themedBody(BuildContext context, Gallery g, Color ink, Color muted, Color card) {
    final seq = ref.watch(gallerySequenceProvider(g.id));
    final rooms = ref.watch(roomsProvider(g.id)).value ?? const <Room>[];
    void open(Artwork a) => context.push('/g/${g.handle}/a/${a.id}');
    final scroll = CustomScrollView(
      slivers: [
        ...switch (seq) {
          AsyncData(:final value) => [
            switch (g.theme) {
              GalleryTheme.feed => FeedLayout(
                gallery: g,
                groups: groupWorks(rooms, value.works, value.roomOf),
                onTap: open,
              ),
              GalleryTheme.salon => SalonLayout(
                gallery: g,
                groups: groupWorks(rooms, value.works, value.roomOf),
                onTap: open,
              ),
              _ => EditorialLayout(gallery: g, groups: groupWorks(rooms, value.works, value.roomOf), onTap: open),
            },
          ],
          AsyncError() => [
            SliverToBoxAdapter(
              child: AsyncBody(
                value: seq,
                builder: (_) => const SizedBox(),
                onRetry: () => ref.invalidate(gallerySequenceProvider(g.id)),
              ),
            ),
          ],
          _ => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        },
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                child: CommentsSection(gallery: g, ink: ink, muted: muted, card: card),
              ),
            ),
          ),
        ),
      ],
    );
    if (g.theme != GalleryTheme.salon) return scroll;
    // A soft pool of light at the top of the green wall.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.2),
          radius: 1.2,
          colors: [Color(0xFF2C3D34), SalonColors.wall],
        ),
      ),
      child: scroll,
    );
  }
}

/// Columns filled shortest-first, so tall and wide works pack without gaps.
class _Masonry extends StatelessWidget {
  const _Masonry({
    required this.artworks,
    required this.columns,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  final List<Artwork> artworks;
  final int columns;
  final Color ink;
  final Color muted;
  final ValueChanged<Artwork> onTap;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final cols = List.generate(columns, (_) => <Artwork>[]);
    final heights = List.filled(columns, 0.0);
    for (final a in artworks) {
      var shortest = 0;
      for (var i = 1; i < columns; i++) {
        if (heights[i] < heights[shortest]) shortest = i;
      }
      cols[shortest].add(a);
      heights[shortest] += 1 / a.aspectRatio + 0.2;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (final a in cols[c])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => onTap(a),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: AspectRatio(
                              aspectRatio: a.aspectRatio,
                              child: ArtworkImage(
                                path: a.thumbPath,
                                semanticLabel: localized(a.title, a.titleEn, lang),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localized(a.title, a.titleEn, lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: ink),
                                ),
                              ),
                              Text('♡ ${a.likeCount}', style: TextStyle(fontSize: 13, color: muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
